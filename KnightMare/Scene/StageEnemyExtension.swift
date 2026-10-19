import SpriteKit

/// Marco 5: Enemy Waves (`1...16`), Movement Patterns, Active Aiming, Parting Shots,
/// Multi-Hit Enemies (Knight, Skeleton, Cloud/Tornado), and Last Unit Wave Bonus.
extension StageScene {
    // MARK: - Wave Queue & Enemy Spawning (`ObjectSystem::spawnObject` & `ActionQueueSystem`)

    func processSpawnQueue() {
        let count = spawnQueue.count
        for i in 0..<count {
            let item = spawnQueue[i]
            guard item.execCount > 0, clockMs >= item.nextExecMs else { continue }
            spawnEnemyObject(
                id: item.objId,
                x: item.x,
                y: item.y,
                objCfg: item.objCfg,
                waveGroupId: item.waveGroupId,
                enqueueRemaining: false
            )
            item.execCount -= 1
            item.nextExecMs = clockMs + item.delayMs
        }
        spawnQueue.removeAll { $0.execCount <= 0 }
    }

    func spawnEnemyWaveFromMap(id: Int, x: CGFloat, y: CGFloat, extraCount: Int) {
        nextWaveGroupId += 1
        let groupId = nextWaveGroupId
        let totalUnits = max(1, 1 + extraCount)
        waveTrackers[groupId] = EnemyWaveTracker(waveGroupId: groupId, objId: id, totalUnits: totalUnits)
        spawnEnemyObject(
            id: id,
            x: x,
            y: y,
            objCfg: extraCount,
            waveGroupId: groupId,
            enqueueRemaining: true
        )
    }

    @discardableResult
    func spawnEnemyObject(
        id: Int,
        x: CGFloat,
        y: CGFloat,
        objCfg: Int = 0,
        waveGroupId: Int = 0,
        enqueueRemaining: Bool = true
    ) -> EnemyObject? {
        let visualId = (id == 8) ? 5 : id
        guard let tile = MSXObjectTiles.objTiles[visualId] else { return nil }
        let data = MSXObjectTiles.objData[id] ?? MSXObjectTiles.ObjDataEntry(
            speedX: 0, speedY: 0, gpr1: 1, gpr2: 0, gpr3: 0
        )

        let node = SKSpriteNode(
            texture: shotTextureCache[visualId],
            size: CGSize(width: tile.w, height: tile.h)
        )
        node.zPosition = (id == 34 || id == 28) ? 22 : 16
        enemiesLayerNode.addChild(node)

        let needsShadow = (id != 1 && id != 4 && id != 7 && id != 10 && id < 23)
        var shadow: SKSpriteNode?
        if needsShadow {
            let sNode = SKSpriteNode(texture: shadowTexture, size: CGSize(width: 16, height: 6))
            sNode.zPosition = 8
            shadowsLayerNode.addChild(sNode)
            shadow = sNode
        }

        var spawnX = x
        var spawnY = y
        var gpr1 = data.gpr1
        var gpr2 = data.gpr2
        var gpr3 = data.gpr3
        var spawnSpeedMs = 0

        switch id {
        case 2: // Bat
            spawnSpeedMs = 500
            if spawnX > Self.msxWidth / 2.0 { gpr2 *= -1.0 }
        case 3: // Bat wave
            spawnSpeedMs = 200
            gpr3 = (spawnX > Self.msxWidth / 2.0) ? -1.0 : 1.0
        case 4: // Knight
            spawnSpeedMs = 500
            gpr3 = 90.0 * ((spawnX > Self.msxWidth / 2.0) ? -1.0 : 1.0)
        case 5: // Cloud: enters from the nearest side edge at `y = 32`, `gpr3` = horizontal direction
            gpr3 = (spawnX < Self.msxWidth / 2.0) ? -1.0 : 1.0
            spawnX = (gpr3 < 0) ? 0 : Self.msxWidth - Self.tileSizeX2
            spawnY = Self.tileSizeX4
        case 6: // Blue demon (`gpr2` = horizontal direction, chosen once Popolon is close)
            spawnSpeedMs = 400
        case 7: // Skeleton (`objCfg` 1/2 = the two split pieces, flagged with `gpr2` = 2/3)
            if objCfg == 1 {
                gpr2 = 2
            } else if objCfg == 2 {
                gpr2 = 3
            } else if spawnX < Self.msxWidth / 2.0 {
                spawnX = Self.tileSizeX4
                gpr2 = 1
            } else {
                spawnX = Self.msxWidth - Self.tileSizeF * 6.0
                gpr2 = -1
            }
        case 8, 12: // Black Demon disguised as Cloud & Yellow thing: drift sideways toward Popolon
            let aimDeg = min(20.0, atan2(abs(spawnX - playerX), abs(spawnY - playerY)) * 180.0 / .pi)
            gpr2 = data.speedX * ((spawnX > playerX) ? -1.0 : 1.0) * sin(aimDeg * .pi / 180.0)
        case 9: // Death ghost
            spawnSpeedMs = 300
        case 10: // Zombie
            if objCfg > 0 {
                gpr1 = 0
                gpr2 = (objCfg == 1) ? -60.0 : 60.0
                gpr3 = (objCfg == 1) ? -1.0 : 1.0
            } else {
                gpr2 *= (spawnX > Self.msxWidth / 2.0) ? -1.0 : 1.0
            }
        case 11: // Ghost
            spawnSpeedMs = 400
            gpr2 = (spawnX > Self.msxWidth / 2.0) ? -1.0 : 1.0
            gpr3 = spawnX
        case 13: // Red diving thing: enters from its side edge at `y = 16`, `gpr3` = horizontal direction
            spawnSpeedMs = 300
            spawnX = (spawnX < Self.msxWidth / 2.0) ? 0 : Self.msxWidth - Self.tileSizeX2
            spawnY = Self.tileSizeX2
            gpr3 = (spawnX == 0) ? 1.0 : -1.0
        case 14: // Reverse Bat: rises from near the bottom, sweeping in from its side (`gpr3`)
            spawnSpeedMs = 1000
            spawnY = Self.msxHeight - Self.tileSizeX4
            if spawnX < Self.msxWidth / 2.0 {
                gpr2 += 180
                gpr3 = -1
            } else {
                gpr3 = 1
            }
        case 16: // Red Death ghost
            gpr2 = (spawnX > Self.msxWidth / 2.0) ? -135.0 : 135.0
        default:
            break
        }

        let enemy = EnemyObject(
            id: id,
            node: node,
            shadowNode: shadow,
            x: spawnX,
            y: spawnY,
            waveGroupId: waveGroupId
        )
        enemy.gpr1 = gpr1
        enemy.gpr2 = gpr2
        enemy.gpr3 = gpr3
        applyEnemyFrameTexture(enemy)
        if id == 7 && (objCfg == 1 || objCfg == 2) {
            applyEnemyFrameOffset(enemy, offsetX: objCfg == 1 ? 32 : 48, baseTileId: 7)
        }
        enemies.append(enemy)

        if enqueueRemaining && objCfg > 0 && spawnSpeedMs > 0 {
            // Queue the rest of the wave at the map position; each spawn re-applies its own placement rules
            let queued = QueuedSpawnAction(
                execCount: objCfg,
                objId: id,
                x: x,
                y: y,
                objCfg: 0,
                delayMs: spawnSpeedMs,
                nextExecMs: clockMs + spawnSpeedMs,
                waveGroupId: waveGroupId
            )
            spawnQueue.append(queued)
        }

        return enemy
    }

    // MARK: - Enemy Movement (`ObjectSystem::moveObjects`)

    func moveEnemies() {
        let dt = CGFloat(Self.tickInterval)
        let activeCount = enemies.count

        for idx in 0..<activeCount {
            let o = enemies[idx]
            guard !o.isFree else { continue }
            o.updatePrev()

            guard let data = MSXObjectTiles.objData[o.id] else { continue }
            var speedX = data.speedX
            var speedY = data.speedY

            switch o.id {
            case 1: // Blob / Slime (`o.gpr1` is HP = 1; use `o.aux1` for movement timer)
                if o.y < 16 { speedY = 20 }
                if o.aux1 <= 0 {
                    o.aux1 = 24
                    o.gpr2 = floor(CGFloat.random(in: 0..<5)) - 2.0
                    o.gpr3 = floor(CGFloat.random(in: 0..<5)) - 2.0
                }
                o.aux1 -= 1
                if o.aux1 <= 12 {
                    speedX = 16.0 * o.gpr2
                    speedY = max(speedY, 16.0 * o.gpr3)
                }
                let nextX = o.x + speedX * dt
                let nextY = o.y + speedY * dt
                if mapCollideForEnemy(px: nextX, py: nextY) {
                    o.gpr2 *= -1
                    o.gpr3 *= -1
                    speedX = 0
                    speedY = 0
                }

            case 2: // Bat
                speedX *= sin(o.gpr2 * .pi / 180.0)
                if o.y > 40 {
                    o.gpr2 += 40.0 * dt * (o.gpr2 > 0 ? 1.0 : -1.0)
                }

            case 14: // Reverse Bat: wide cosine sweep anchored on its side while climbing
                let reach = Self.msxWidth / 2.0 + Self.tileSizeF * 6.0
                o.x = (o.gpr3 > 0 ? Self.msxWidth : 0) + reach * cos(o.gpr2 * .pi / 180.0)
                o.gpr2 += data.speedX * dt
                o.renderOffsetY = (animTick % 6 < 3) ? CGFloat(MSXObjectTiles.objTiles[14]?.h ?? 11) / 2.0 : 0
                speedX = 0

            case 3: // Bat wave
                speedX *= sin(o.gpr2 * .pi / 180.0) * o.gpr3
                o.gpr2 += 120.0 * dt

            case 4: // Knight
                speedX *= sin(o.gpr2 * .pi / 180.0)
                speedY *= cos(o.gpr2 * .pi / 180.0)
                let nextX = o.x + speedX * dt
                let nextY = o.y + speedY * dt
                if o.y > 24 && mapCollideForEnemy(px: nextX, py: nextY) {
                    o.gpr2 = (o.gpr2 != 0) ? 0 : o.gpr3
                } else if o.y > 60 && o.gpr2 == 0 && Bool.random() {
                    if !mapCollideForEnemy(px: o.x + o.gpr3 * 0.25, py: o.y) {
                        o.gpr2 = o.gpr3
                    } else {
                        o.gpr3 *= -1
                    }
                }

            case 5: // Cloud: bobs and zig-zags across the top half; once deflected by a shot (`gpr1 = 1`) it flies off
                if o.gpr1 == 1 {
                    speedX = o.gpr2
                    speedY = o.gpr3
                } else {
                    if o.y > Self.msxHeight / 2.0 + Self.tileSizeX2 {
                        if o.x <= 0 || o.x >= Self.msxWidth - Self.tileSizeX2 {
                            recordEnemyEscaped(o)
                            o.isFree = true
                            scheduleBossMinionReplacement()
                            continue
                        }
                    } else if o.gpr3 < 0 && o.x <= Self.tileSizeX2 {
                        o.gpr3 = 1
                    } else if o.gpr3 > 0 && o.x >= Self.msxWidth - Self.tileSizeX4 {
                        o.gpr3 = -1
                    }
                    speedX = data.speedX * o.gpr3
                    speedY = 0
                    if o.gpr2 < 0 {
                        o.gpr2 += 10.0 * dt
                        speedY = 10.0
                    } else {
                        // Vertical bob: swap the previous sine offset for the next one
                        o.y -= Self.tileSizeF / 2.0 * sin(o.gpr2 * .pi / 180.0)
                        o.gpr2 += 1
                        o.y += Self.tileSizeF / 2.0 * sin(o.gpr2 * .pi / 180.0)
                        if o.gpr2.truncatingRemainder(dividingBy: data.speedY) == 0 {
                            o.gpr2 = -Self.tileSizeF - Self.tileSizeF / 2.0
                        }
                    }
                }

            case 8: // Black Demon: falls disguised as a cloud, reveals itself near Popolon, fires a spread, then retreats
                o.renderOffsetY = 0
                if o.gpr3 == 0 && playerY - o.y < 60 {
                    o.gpr3 = 1
                    applyEnemyBaseTile(o, tileId: 8)
                }
                if o.gpr3 <= 0 {
                    speedX = o.gpr2
                    speedY = data.speedY * (o.gpr3 < 0 ? -1.0 : 1.0)
                } else {
                    speedX = 0
                    speedY = 0
                    o.renderOffsetY = Self.tileSizeF / 2.0
                    o.gpr3 += dt
                    if o.gpr3 > 2 {
                        o.gpr3 = -1
                        fireEnemyProjectile(from: o)
                        applyEnemyBaseTile(o, tileId: 5)
                        o.flipX = false
                    }
                }

            case 6: // Blue demon: falls straight, then commits to a horizontal direction once Popolon is close
                if o.gpr2 == 0 && playerY - o.y < 55 {
                    o.gpr2 = (o.x > playerX) ? -1.0 : 1.0
                }
                speedX *= o.gpr2

            case 7: // Skeleton (`gpr2` = ±1 walking direction, 2/3 = split pieces; `gpr3` = split timer)
                if o.gpr2 > 1 {
                    // Split piece: flies apart, then snaps back together before vanishing
                    o.gpr3 += dt
                    var offsetY = -Self.tileSizeF
                    let spread: CGFloat
                    if o.gpr3 > 3.2 {
                        o.isFree = true
                        continue
                    } else if o.gpr3 > 3.0 {
                        spread = Self.tileSizeF
                    } else if o.gpr3 > 2.8 {
                        spread = Self.tileSizeX2
                    } else if o.gpr3 > 2.6 {
                        if o.gpr1 == 10 {
                            RetroAudioSynthesizer.shared.playSfx(.skeletonRestored)
                            o.gpr1 = 11
                        }
                        spread = Self.tileSizeF * 3.0
                    } else if o.gpr3 > 0.6 {
                        spread = Self.tileSizeX4
                        offsetY = 0
                    } else if o.gpr3 > 0.4 {
                        spread = Self.tileSizeF * 3.0
                    } else if o.gpr3 > 0.2 {
                        spread = Self.tileSizeX2
                    } else {
                        spread = Self.tileSizeF
                        if o.gpr1 != 10 { o.gpr1 = 10 }
                    }
                    o.renderOffsetX = spread * (o.gpr2 == 2 ? -1.0 : 1.0)
                    o.renderOffsetY = offsetY
                    speedX = 0
                    speedY = 0
                } else if o.gpr3 == 0 {
                    // Walking: zig-zags between the edges, faster as it loses life
                    speedX = (data.speedX + data.speedX / 3.0 * (data.gpr1 - o.gpr1 + 1)) * o.gpr2
                    if o.x < Self.tileSizeX4 {
                        o.gpr2 = 1
                    } else if o.x > Self.msxWidth - Self.tileSizeF * 6.0 {
                        o.gpr2 = -1
                    }
                } else {
                    // Broken: stays hidden while its pieces play out, then resumes walking
                    speedX = 0
                    speedY = 0
                    o.gpr3 += dt
                    if o.gpr3 > 4.2 {
                        o.gpr3 = 0
                        o.node.isHidden = false
                    }
                }

            case 9: // Death ghost
                speedX *= sin(o.gpr2 * .pi / 180.0)
                if o.gpr2 == 0 && (playerY - o.y < 100) {
                    o.gpr2 = (playerX > o.x) ? 90.0 : -90.0
                    fireEnemyProjectile(from: o)
                }

            case 10: // Zombie
                speedX = o.gpr2
                if o.gpr3 != 0 && abs(o.gpr2) > 0 {
                    speedY = 0
                    o.gpr2 = max(0, abs(o.gpr2) - 35.0 * dt) * o.gpr3
                    if o.gpr2 == 0 {
                        if o.gpr3 < 0 {
                            o.gpr1 = 1
                            o.gpr2 = 60.0 * ((o.x > Self.msxWidth / 2.0) ? -1.0 : 1.0)
                            o.gpr3 = 0
                            applyEnemyBaseTile(o, tileId: 10)
                            RetroAudioSynthesizer.shared.playSfx(.skeletonRestored)
                        } else {
                            o.isFree = true
                        }
                    }
                } else if o.x < 16 || o.x > Self.msxWidth - 32 {
                    o.gpr2 *= -1
                }

            case 11: // Ghost
                let a = (o.y + o.gpr3) * 1.5
                speedX *= sin(a * .pi / 180.0) * o.gpr2
                o.flipX = (speedX > 0)

            case 12: // Yellow thing: fast dive with the sideways drift picked at spawn
                speedX = o.gpr2

            case 13: // Red thing: crosses toward the far side, loops around a 270° ellipse, then leaves upward
                // `gpr2`: 0 = approaching, 999 = leaving, otherwise the ellipse angle; `gpr3`: direction, then ellipse center Y
                if o.gpr2 == 0 {
                    if o.gpr3 > 0 && o.x - Self.tileSizeF > Self.msxWidth / 2.0 + Self.tileSizeX4 {
                        o.gpr2 = 315
                        o.gpr3 = o.y + Self.tileSizeX4 + Self.tileSizeF / 2.0
                        speedX = 0
                        speedY = 0
                    } else if o.gpr3 < 0 && o.x + Self.tileSizeF < Self.msxWidth / 2.0 - Self.tileSizeF * 6.0 {
                        o.gpr2 = -135
                        o.gpr3 = o.y + Self.tileSizeX4 + Self.tileSizeF / 2.0
                        speedX = 0
                        speedY = 0
                    } else {
                        speedX *= o.gpr3
                    }
                } else if o.gpr2 == 999 {
                    speedX *= o.gpr3
                    speedY *= -1
                } else {
                    let radians = o.gpr2 * .pi / 180.0
                    o.x = Self.msxWidth / 2.0 - Self.tileSizeF + Self.tileSizeF * 9.0 * cos(radians)
                    o.y = o.gpr3 + Self.tileSizeF * 6.0 * sin(radians)
                    o.gpr2 += (o.gpr2 < 0) ? -0.9 : 0.9
                    if o.gpr2 < -405 || o.gpr2 >= 585 {
                        o.gpr3 = (o.gpr2 > 0) ? 1.0 : -1.0
                        o.gpr2 = 999
                    }
                    speedX = 0
                    speedY = 0
                }

            case 15: // Sorcerer
                if o.y > 24 && o.gpr2 == 0 {
                    o.gpr2 = 100
                    applyEnemyFrameOffset(o, offsetX: 0, baseTileId: 15)
                } else if o.gpr2 > 1 {
                    o.gpr2 -= 60.0 * dt
                    if o.gpr2 >= 40 && o.gpr2 <= 60 {
                        if o.gpr3 == 0 {
                            o.gpr3 = 1
                            fireEnemyProjectile(from: o)
                        }
                        applyEnemyFrameOffset(o, offsetX: 16, baseTileId: 15)
                    } else {
                        applyEnemyFrameOffset(o, offsetX: 0, baseTileId: 15)
                    }
                    if o.gpr2 <= 1 { o.gpr2 = 1 }
                    speedY = 0
                } else if o.gpr2 == 1 {
                    speedY *= -1
                }

            case 16: // Red Death ghost
                speedX *= sin(o.gpr2 * .pi / 180.0)
                speedY *= -cos(o.gpr2 * .pi / 180.0)
                if o.y > 120 && abs(o.gpr2) > 45 {
                    o.gpr2 += (o.gpr2 > 0 ? -90.0 : 90.0) * dt
                } else if abs(o.gpr2) <= 45 {
                    speedY *= 4.0
                }

            default:
                break
            }

            o.x += speedX * dt
            o.y += speedY * dt

            // Parting Shot ("Tiro de Despedida") when crossing the bottom border (`y >= 164`)
            let isSkeletonPiece = o.id == 7 && o.gpr2 > 1
            if !o.didPartingShot && o.y >= 164 && o.y <= Self.msxHeight && o.id < 20 && o.id != 1 && o.id != 5 && o.id != 8 && o.id != 12 && !isSkeletonPiece {
                o.didPartingShot = true
                if CGFloat.random(in: 0...1) < 0.45 {
                    firePartingShot(from: o)
                }
            }

            // Out-of-bounds cleanup (`ObjectSystem::moveObjects`)
            let maxY = (o.id == 14) ? (Self.msxHeight + 64) : (Self.msxHeight + Self.tileSizeF)
            if o.y < 0 || o.y > maxY || o.x < -Self.tileSizeX2 || o.x > Self.msxWidth + Self.tileSizeF {
                recordEnemyEscaped(o)
                o.isFree = true
                if o.id == 5 {
                    scheduleBossMinionReplacement()
                }
            }
        }
    }

    // MARK: - Enemy Animation (`ObjectSystem::animateObjects`)

    func animateEnemies() {
        let twoFrames = (animTick % 2 == 0) ? 16 : 0
        // Reference cadence (`animateObjects` default): alternate frames every 3 animation ticks
        let slowFrames = (animTick % 6 > 2) ? 16 : 0
        for o in enemies where !o.isFree {
            // While screen is frozen (`freezeTimer >= 0`), living enemies stay frozen on their frame,
            // while fire explosions (`o.id == 34`) and hit flashes (`o.id == 28`) complete normally!
            if o.id < 20 && freezeTimer >= 0 {
                continue
            }
            switch o.id {
            case 6, 14:
                applyEnemyFrameOffset(o, offsetX: slowFrames, baseTileId: o.id)
            case 1, 2, 3, 9, 10, 16:
                if o.id == 10 && o.gpr3 != 0 {
                    applyEnemyFrameOffset(o, offsetX: 32 + twoFrames, baseTileId: 10)
                } else {
                    applyEnemyFrameOffset(o, offsetX: twoFrames, baseTileId: o.id)
                }
            case 4: // Knight
                let offset = (o.gpr1 == 3) ? twoFrames : (16 * (5 - Int(o.gpr1)))
                applyEnemyFrameOffset(o, offsetX: offset, baseTileId: 4)
            case 5, 8: // Cloud, and the Black Demon while disguised; the revealed demon just flips
                if o.id == 5 || o.gpr3 <= 0 {
                    applyEnemyFrameOffset(o, offsetX: slowFrames, baseTileId: 5)
                } else {
                    o.flipX = (animTick % 6 > 2)
                }
            case 7: // Skeleton (split pieces keep the sprite chosen at spawn)
                if o.gpr2 <= 1 {
                    applyEnemyFrameOffset(o, offsetX: slowFrames, baseTileId: 7)
                }
            case 11: // Ghost
                break
            case 12: // Yellow thing: static sprite
                break
            case 13:
                applyEnemyFrameOffset(o, offsetX: slowFrames, baseTileId: 13)
            case 15: // Sorcerer
                if o.gpr2 == 0 || o.gpr2 == 1 {
                    applyEnemyFrameOffset(o, offsetX: twoFrames, baseTileId: 15, sheetYOverride: 136)
                }
            case 28: // White explosion
                if o.gpr1 > 1 {
                    o.isFree = true
                } else {
                    applyEnemyFrameOffset(o, offsetX: Int(o.gpr1) * 16, baseTileId: 28)
                    o.gpr1 += 1
                }
            case 34: // Fire explosion (`FIRE_ANIM`)
                let idx = Int(o.gpr1)
                if idx >= MSXObjectTiles.fireAnim.count {
                    o.isFree = true
                } else {
                    let frame = MSXObjectTiles.fireAnim[idx]
                    applyEnemyFrameOffset(o, offsetX: frame * 16, baseTileId: 34)
                    o.gpr1 += 1
                }
            default:
                break
            }
        }
    }

    // MARK: - Active Aiming, Periodic Firing & Parting Shot (`ObjectSystem::enemiesFire`)

    func enemiesFire() {
        let maxShootY = Self.msxHeight * 0.62 // ~109 px
        for o in enemies where !o.isFree {
            guard o.id < 20 && o.id != 8 else { continue }
            guard o.y >= 16 && o.y <= maxShootY else { continue }
            if Double.random(in: 0...1) < definition.shootChance(for: gameState?.difficulty ?? .normal) {
                fireEnemyProjectile(from: o)
            }
        }
    }

    func fireEnemyProjectile(from o: EnemyObject) {
        var speed: CGFloat = 120.0
        var shotsCount = 0
        var weaponId = 23
        var angle: CGFloat = 0

        switch o.id {
        case 6, 12, 13, 14: // Dot bullet aimed at Popolon (`enemyFire` default, speed 70)
            // From Stage 3 on, 12/13 hold fire during the first half of the map (`s.stage > 2 && s.row > MAP_ROWS / 2`)
            if (o.id == 12 || o.id == 13) && definition.number > 2 && currentRow > StageMapData.mapRows / 2 {
                return
            }
            weaponId = 23
            speed = 70
            angle = compassAngleTowardPopolon(fromX: o.x, fromY: o.y)
        case 2, 3, 11:
            weaponId = 23 // Dot bullet
            angle = o.velocityAngleDeg()
            if angle == 0 {
                angle = compassAngleTowardPopolon(fromX: o.x, fromY: o.y)
            }
        case 4: // Knight directional arrow (`29`, `30`, `31`)
            angle = round(o.velocityAngleDeg() / 45.0) * 45.0
            if angle == 0 || angle >= 360 { angle = 180 }
            let mod90 = Int(abs(angle)) % 90 == 0
            let mod180 = Int(abs(angle)) % 180 == 0
            weaponId = mod90 ? (mod180 ? 29 : 30) : 31
        case 7: // Skeleton spinning bone (`25`), only while walking intact
            guard o.gpr3 == 0 && o.gpr2 <= 1 else { return }
            weaponId = 25
            speed = 70
            angle = compassAngleTowardPopolon(fromX: o.x, fromY: o.y)
        case 8: // Black Demon 4-way spread (`24`) at ±10° / ±30° around Popolon
            weaponId = 24
            speed = 91
            shotsCount = 3
            angle = compassAngleTowardPopolon(fromX: o.x, fromY: o.y) + 30.0
        case 9, 16: // Death ghost energy ray (`24`)
            weaponId = 24
            angle = o.velocityAngleDeg()
            if angle == 0 {
                angle = compassAngleTowardPopolon(fromX: o.x, fromY: o.y)
            }
        case 15: // Sorcerer 8-way burst (`23`)
            weaponId = 23
            shotsCount = 7
            angle = 0
        default:
            return
        }

        for _ in 0...shotsCount {
            let sx = speed * sin(angle * .pi / 180.0)
            let sy = -speed * cos(angle * .pi / 180.0)
            guard sx != 0 || sy != 0 else { continue }

            spawnEnemyShot(
                weaponId: weaponId,
                x: o.x + 8.0,
                y: o.y - 4.0,
                speedX: sx,
                speedY: sy,
                angleDeg: angle
            )

            if o.id == 8 {
                angle -= 20.0
            } else if o.id == 15 {
                angle += 45.0
            }
        }
    }

    /// Fires a single aimed Parting Shot ("Tiro de Despedida") toward Popolon as the enemy exits the bottom border.
    func firePartingShot(from o: EnemyObject) {
        let speed: CGFloat = 115.0
        let angle = compassAngleTowardPopolon(fromX: o.x, fromY: o.y)
        let sx = speed * sin(angle * .pi / 180.0)
        let sy = -speed * cos(angle * .pi / 180.0)
        let weaponId = (o.id == 9 || o.id == 16) ? 24 : 23
        spawnEnemyShot(
            weaponId: weaponId,
            x: o.x + 8.0,
            y: o.y - 6.0,
            speedX: sx,
            speedY: sy,
            angleDeg: angle
        )
    }

    func compassAngleTowardPopolon(fromX: CGFloat, fromY: CGFloat) -> CGFloat {
        let dx = playerX - fromX
        let dy = playerY - fromY
        var a = atan2(dx, -dy) * 180.0 / .pi
        if a < 0 { a += 360.0 }
        return a
    }

    @discardableResult
    func spawnEnemyShot(
        weaponId: Int,
        x: CGFloat,
        y: CGFloat,
        speedX: CGFloat,
        speedY: CGFloat,
        angleDeg: CGFloat
    ) -> EnemyShot? {
        guard let rect = MSXObjectTiles.objTiles[weaponId] else { return nil }
        let node = SKSpriteNode(
            texture: shotTextureCache[weaponId],
            size: CGSize(width: rect.w, height: rect.h)
        )
        node.zPosition = 19
        shotsLayerNode.addChild(node)

        let shot = EnemyShot(
            weaponId: weaponId,
            node: node,
            x: x,
            y: y,
            speedX: speedX,
            speedY: speedY
        )

        if weaponId >= 29 && weaponId <= 31 {
            let a = ((angleDeg.truncatingRemainder(dividingBy: 360.0)) + 360.0).truncatingRemainder(dividingBy: 360.0)
            if a == 225 || a == 270 {
                shot.rotQuarterTurns = 2
            } else if a == 0 || a == 315 {
                shot.rotQuarterTurns = 3
            } else if a == 45 {
                shot.rotQuarterTurns = 1
            } else {
                shot.rotQuarterTurns = 0
            }
            node.zRotation = -CGFloat(shot.rotQuarterTurns) * (.pi / 2.0)
        }

        enemyShots.append(shot)
        return shot
    }

    func moveEnemyShots() {
        let dt = CGFloat(Self.tickInterval)
        for shot in enemyShots where !shot.isFree {
            if let center = shot.orbitCenter {
                // Scythe (`33`): two full turns around a point below the boss, then it vanishes
                shot.orbitAngle += shot.orbitStep
                if abs(shot.orbitAngle) > 720 {
                    shot.isFree = true
                    continue
                }
                let radians = shot.orbitAngle * .pi / 180.0
                shot.x = center.x + Self.tileSizeF * 7.0 * sin(radians)
                shot.y = center.y + Self.tileSizeF * 7.0 * -cos(radians)
            } else {
                shot.x += shot.speedX * dt
                shot.y += shot.speedY * dt
            }
            if shot.y < 0 || shot.y > Self.msxHeight + Self.tileSizeX2 || shot.x < 0 || shot.x > Self.msxWidth {
                shot.isFree = true
            }
        }
    }

    func animateEnemyShots() {
        for shot in enemyShots where !shot.isFree {
            if shot.weaponId >= 25 && shot.weaponId <= 27 {
                // Spinning Skeleton Bone (`25..27`)
                let step = shot.gpr1 % 4
                let newId = (step == 3) ? 26 : (25 + step)
                let newRot = (step >= 2) ? 2 : 0
                shot.weaponId = newId
                shot.rotQuarterTurns = newRot
                if let rect = MSXObjectTiles.objTiles[newId] {
                    shot.node.texture = shotTextureCache[newId]
                    shot.node.size = CGSize(width: rect.w, height: rect.h)
                    shot.node.zRotation = -CGFloat(newRot) * (.pi / 2.0)
                }
                shot.gpr1 += 1
            } else if shot.weaponId == 33 {
                // Scythe spins through 4 frames laid out side by side in `objects.png`
                let frameX = 48 + 16 * (animTick % 4)
                shot.node.texture = SpriteSheetManager.shared.texture(from: .objects, x: frameX, y: 120, width: 16, height: 16)
            } else if shot.weaponId == 32 {
                shot.rotQuarterTurns = shot.gpr1 % 4
                shot.node.zRotation = -CGFloat(shot.rotQuarterTurns) * (.pi / 2.0)
                shot.gpr1 += 1
            }
        }
    }

    // MARK: - Enemy Collisions, Splitting & Destruction (`CollisionSystem::hitObject`)

    func hitEnemyObject(_ o: EnemyObject, instantKill: Bool) -> Bool {
        if o.id == 5 {
            if instantKill {
                // Burns away without awarding points (`startFireAnimation` + `destroyObject`)
                killEnemyObject(o, awardPoints: false)
            } else {
                // Shots can't destroy a cloud: they knock it away at attack speed along its heading
                let heading = o.velocityAngleDeg() * .pi / 180.0
                o.gpr1 = 1
                o.gpr2 = 250.0 * sin(heading) + 0.01
                o.gpr3 = 250.0 * -cos(heading)
            }
            return true
        }

        if o.id == 7 {
            // Already broken or a flying piece: shots pass through, even while invincible
            if o.gpr3 > 0 || o.gpr2 > 1 {
                return false
            }
            if o.gpr1 > 1 && !instantKill {
                // Breaks into two pieces that fly apart and reassemble; the body hides meanwhile
                o.gpr1 -= 1
                o.gpr3 = 1
                o.node.isHidden = true
                spawnEnemyObject(id: 7, x: o.x, y: o.y, objCfg: 1, waveGroupId: 0, enqueueRemaining: false)
                spawnEnemyObject(id: 7, x: o.x, y: o.y, objCfg: 2, waveGroupId: 0, enqueueRemaining: false)
                RetroAudioSynthesizer.shared.playSfx(.split)
                return true
            }
            killEnemyObject(o)
            return true
        }

        if o.id == 10 {
            if instantKill {
                killEnemyObject(o)
                return true
            }
            // Ignore hits while the two halves are actively separating/reassembling (`o.gpr3 != 0`)
            if o.gpr3 != 0 {
                return false
            }
            if o.gpr1 > 1 {
                let nextHp = max(1, Int(o.gpr1) - 1)
                let leftHalf = spawnEnemyObject(id: o.id, x: o.x, y: o.y, objCfg: 1, waveGroupId: o.waveGroupId, enqueueRemaining: false)
                leftHalf?.aux1 = nextHp
                let rightHalf = spawnEnemyObject(id: o.id, x: o.x, y: o.y, objCfg: 2, waveGroupId: o.waveGroupId, enqueueRemaining: false)
                rightHalf?.aux1 = nextHp
                o.isFree = true
                RetroAudioSynthesizer.shared.playSfx(.split)
                return true
            }
            killEnemyObject(o)
            return true
        }

        o.gpr1 -= instantKill ? 10 : 1
        if o.gpr1 <= 0 {
            killEnemyObject(o)
        } else {
            RetroAudioSynthesizer.shared.playSfx(.helmet)
        }
        return true
    }

    func killEnemyObject(_ o: EnemyObject, playSfx: Bool = true, awardPoints: Bool = true) {
        let originalId = o.id
        let isSkeletonPiece = originalId == 7 && o.gpr2 > 1
        if awardPoints && !isSkeletonPiece {
            gameState?.incrementScore(MSXObjectTiles.objPoints[originalId] ?? 100)
        }
        recordEnemyKilled(o)
        if originalId == 5 && boss.status == .active {
            scheduleBossMinionReplacement()
        }

        // Transform into fire explosion (`objId == 34`, `FIRE_ANIM`)
        o.id = 34
        o.gpr1 = 0
        o.gpr2 = 0
        o.gpr3 = 0
        o.renderOffsetX = 0
        o.renderOffsetY = 0
        o.flipX = false
        o.flipY = false
        o.node.isHidden = false // a broken skeleton may be hidden while its pieces fly
        o.shadowNode?.removeFromParent()
        applyEnemyBaseTile(o, tileId: 34)
        if playSfx {
            RetroAudioSynthesizer.shared.playSfx(.enemyKill)
        }
    }

    func recordEnemyKilled(_ o: EnemyObject) {
        guard o.waveGroupId > 0, let tracker = waveTrackers[o.waveGroupId], !tracker.bonusAwarded else { return }
        tracker.killedUnits += 1
        if tracker.killedUnits >= tracker.totalUnits && tracker.escapedUnits == 0 {
            tracker.bonusAwarded = true
            // Last Unit Rule ("Regra da Última Unidade"): Wave Clear Bonus +500 pts!
            gameState?.incrementScore(500)
            gameState?.wavesClearedCount += 1
            RetroAudioSynthesizer.shared.playSfx(.points, volume: 0.7)
        }
    }

    func recordEnemyEscaped(_ o: EnemyObject) {
        guard o.waveGroupId > 0, let tracker = waveTrackers[o.waveGroupId] else { return }
        tracker.escapedUnits += 1
    }

    // MARK: - Sprite Helpers

    func applyEnemyBaseTile(_ o: EnemyObject, tileId: Int) {
        guard let rect = MSXObjectTiles.objTiles[tileId] else { return }
        o.node.texture = shotTextureCache[tileId]
        o.node.size = CGSize(width: rect.w, height: rect.h)
    }

    func applyEnemyFrameTexture(_ o: EnemyObject) {
        let visualId = (o.id == 8 && o.gpr3 <= 0) ? 5 : o.id
        applyEnemyBaseTile(o, tileId: visualId)
    }

    func applyEnemyFrameOffset(_ o: EnemyObject, offsetX: Int, baseTileId: Int, sheetYOverride: Int? = nil) {
        guard let rect = MSXObjectTiles.objTiles[baseTileId] else { return }
        let sy = sheetYOverride ?? rect.y
        if let tex = SpriteSheetManager.shared.texture(
            from: .objects,
            x: rect.x + offsetX,
            y: sy,
            width: rect.w,
            height: rect.h
        ) {
            o.node.texture = tex
            o.node.size = CGSize(width: rect.w, height: rect.h)
        }
    }

    func enemyBox(_ o: EnemyObject) -> CGRect {
        let visualId = (o.id == 8 && o.gpr3 <= 0) ? 5 : o.id
        let rect = MSXObjectTiles.objTiles[visualId] ?? MSXObjectTiles.TileRect(x: 0, y: 0, w: 16, h: 16)
        let drawX = o.x + o.renderOffsetX
        let drawY = o.y + o.renderOffsetY
        return CGRect(x: drawX, y: drawY, width: CGFloat(rect.w), height: CGFloat(rect.h))
    }

    func enemyShotBox(_ shot: EnemyShot) -> CGRect {
        let rect = MSXObjectTiles.objTiles[shot.weaponId] ?? MSXObjectTiles.TileRect(x: 0, y: 0, w: 6, h: 6)
        return CGRect(x: shot.x, y: shot.y, width: CGFloat(rect.w), height: CGFloat(rect.h))
    }
}
