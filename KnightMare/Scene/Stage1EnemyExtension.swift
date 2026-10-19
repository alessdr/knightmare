import SpriteKit

/// Marco 5: Enemy Waves (`1...16`), Movement Patterns, Active Aiming, Parting Shots,
/// Multi-Hit Enemies (Knight, Skeleton, Cloud/Tornado), and Last Unit Wave Bonus.
extension Stage1Scene {
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
        let spawnY = y
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
        case 5: // Cloud / Tornado
            if objCfg == 1 {
                gpr2 = atan2(playerX - spawnX, spawnY - playerY) * 180.0 / .pi
                gpr3 = 250.0
                RetroAudioSynthesizer.shared.playSfx(.bossHit)
            }
        case 6: // Blue demon
            spawnSpeedMs = 400
            gpr2 = (spawnX > Self.msxWidth / 2.0) ? -120.0 : 120.0
        case 7: // Skeleton
            if objCfg > 0 {
                // Split bone half: store remaining HP in `aux1` and mark `gpr1 = 0` while split
                gpr1 = 0
                gpr2 = (objCfg == 1) ? -90.0 : 90.0
                gpr3 = (objCfg == 1) ? -1.0 : 1.0
            }
        case 8: // Black Demon disguised as Cloud
            break
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
        case 12: // Yellow bouncy thing
            spawnX = min(Self.msxWidth - Self.tileSizeF * 6.0, max(Self.tileSizeX4, playerX))
            gpr2 = (spawnX > Self.msxWidth / 2.0) ? -25.0 : 25.0
            gpr3 = 2
        case 13: // Red diving thing
            spawnSpeedMs = 300
            gpr2 = (spawnX > Self.msxWidth / 2.0) ? -90.0 : 90.0
        case 14: // Reverse Bat
            spawnSpeedMs = 1000
            if spawnX > Self.msxWidth / 2.0 { gpr2 *= -1.0 }
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
        enemies.append(enemy)

        if enqueueRemaining && objCfg > 0 && spawnSpeedMs > 0 {
            let queued = QueuedSpawnAction(
                execCount: objCfg,
                objId: id,
                x: spawnX,
                y: spawnY,
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

            case 2, 14: // Bat & Reverse Bat
                speedX *= sin(o.gpr2 * .pi / 180.0)
                if o.y > 40 {
                    o.gpr2 += 40.0 * dt * (o.gpr2 > 0 ? 1.0 : -1.0)
                }

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

            case 5, 8: // Cloud / Tornado (`5`) & Disguised Black Demon (`8`)
                if o.id == 5 && o.gpr3 > 0 {
                    speedX = o.gpr3 * sin(o.gpr2 * .pi / 180.0)
                    speedY = -o.gpr3 * cos(o.gpr2 * .pi / 180.0)
                } else {
                    o.renderOffsetX = floor(-16.0 * sin(o.gpr2 * .pi / 180.0))
                    o.renderOffsetY = floor(-16.0 * cos(o.gpr2 * .pi / 180.0))
                    o.gpr2 += speedY * dt
                    speedY = speedX
                    speedX = 0

                    if o.id == 8 && (playerY - o.y < 60) {
                        if o.gpr3 == 0 {
                            o.gpr3 = 200
                            applyEnemyBaseTile(o, tileId: 8)
                            fireEnemyProjectile(from: o)
                        }
                        if o.gpr3 > 1 {
                            o.gpr3 -= 60.0 * dt
                            if o.gpr3 <= 1 {
                                o.gpr3 = 1
                                applyEnemyBaseTile(o, tileId: 5)
                            }
                        }
                    }
                }

            case 6: // Blue demon
                speedX *= sin(o.gpr2 * .pi / 180.0)
                speedY *= -cos(o.gpr2 * .pi / 180.0)
                let minY = (o.gpr3 == 0) ? 160.0 : 80.0
                if o.y > minY && abs(o.gpr2) > 45.0 {
                    o.gpr2 += (o.gpr2 > 0 ? -90.0 : 90.0) * dt
                    o.gpr3 = 1
                } else if o.y < 70 && abs(o.gpr2) < 135.0 {
                    o.gpr2 += (o.gpr2 > 0 ? 90.0 : -90.0) * dt
                }

            case 7: // Skeleton
                speedX *= sin(o.gpr2 * .pi / 180.0)
                speedY *= -cos(o.gpr2 * .pi / 180.0)
                if o.gpr3 != 0 && abs(o.gpr2) > 0 {
                    o.gpr2 = max(0, abs(o.gpr2) - 40.0 * dt) * o.gpr3
                    if o.gpr2 == 0 {
                        if o.gpr3 < 0 {
                            o.gpr1 = max(1, CGFloat(o.aux1))
                            o.gpr3 = 0
                            applyEnemyBaseTile(o, tileId: 7)
                            RetroAudioSynthesizer.shared.playSfx(.skeletonRestored)
                        } else {
                            o.isFree = true
                        }
                    }
                } else {
                    let nextX = o.x + speedX * dt
                    let nextY = o.y + speedY * dt
                    if mapCollideForEnemy(px: nextX, py: nextY) {
                        o.gpr2 = (o.gpr2 != 0) ? 0 : 90.0 * ((o.x > Self.msxWidth / 2.0) ? -1.0 : 1.0)
                    } else if abs(o.x - playerX) > 8.0 {
                        let candidateAngle: CGFloat = (playerX > o.x) ? 90.0 : -90.0
                        let stepX = sin(candidateAngle * .pi / 180.0) * speedX * dt
                        if !mapCollideForEnemy(px: o.x + stepX, py: o.y) {
                            o.gpr2 = candidateAngle
                        }
                    } else {
                        o.gpr2 = 0
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

            case 12: // Yellow thing
                speedX *= sin(o.gpr2 * .pi / 180.0)
                speedY *= cos(o.gpr2 * .pi / 180.0)
                if o.gpr3 > 0 {
                    let bounceX = (o.x <= 8 && o.gpr2 < 0) || (o.x >= Self.msxWidth - 24 && o.gpr2 > 0)
                    let bounceY = (o.y <= 8 && abs(o.gpr2) > 90) || (o.y >= Self.msxHeight - 8 && abs(o.gpr2) < 90)
                    if bounceX {
                        o.gpr2 *= -1
                        o.gpr3 -= 1
                    } else if bounceY {
                        o.gpr2 = 180.0 - o.gpr2
                        o.gpr3 -= 1
                    }
                }

            case 13: // Red thing
                speedX *= cos(o.gpr2 * .pi / 180.0)
                if o.y > 40 && abs(o.gpr2) > 0 {
                    o.gpr2 += (o.gpr2 > 0 ? -40.0 : 40.0) * dt
                } else {
                    speedY *= -1
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
            if !o.didPartingShot && o.y >= 164 && o.y <= Self.msxHeight && o.id < 20 && o.id != 1 && o.id != 5 && o.id != 8 && o.id != 12 {
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
            }
        }
    }

    // MARK: - Enemy Animation (`ObjectSystem::animateObjects`)

    func animateEnemies() {
        let twoFrames = (animTick % 2 == 0) ? 16 : 0
        for o in enemies where !o.isFree {
            // While screen is frozen (`freezeTimer >= 0`), living enemies stay frozen on their frame,
            // while fire explosions (`o.id == 34`) and hit flashes (`o.id == 28`) complete normally!
            if o.id < 20 && freezeTimer >= 0 {
                continue
            }
            switch o.id {
            case 1, 2, 3, 6, 9, 10, 14, 16:
                if o.id == 10 && o.gpr3 != 0 {
                    applyEnemyFrameOffset(o, offsetX: 32 + twoFrames, baseTileId: 10)
                } else {
                    applyEnemyFrameOffset(o, offsetX: twoFrames, baseTileId: o.id)
                }
            case 4: // Knight
                let offset = (o.gpr1 == 3) ? twoFrames : (16 * (5 - Int(o.gpr1)))
                applyEnemyFrameOffset(o, offsetX: offset, baseTileId: 4)
            case 5, 8: // Cloud / Tornado / Black Demon
                if o.id == 5 || o.gpr3 <= 1 {
                    let offset = ((animTick % 3) * 16) + (o.id == 5 && o.gpr3 > 0 ? 48 : 0)
                    applyEnemyFrameOffset(o, offsetX: offset, baseTileId: 5)
                }
            case 7: // Skeleton
                let offset: Int
                if o.gpr1 == 3 {
                    offset = twoFrames
                } else if o.gpr1 == 2 {
                    offset = 32
                } else {
                    offset = 48
                }
                applyEnemyFrameOffset(o, offsetX: offset, baseTileId: 7)
                if o.gpr1 < 3 {
                    o.flipX = (animTick % 2 == 0)
                } else {
                    o.flipX = false
                }
            case 11: // Ghost
                break
            case 12, 13:
                o.flipX = (animTick % 2 == 0)
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
            if CGFloat.random(in: 0...1) < 0.5 {
                fireEnemyProjectile(from: o)
            }
        }
    }

    func fireEnemyProjectile(from o: EnemyObject) {
        let speed: CGFloat = 120.0
        var shotsCount = 0
        var weaponId = 23
        var angle: CGFloat = 0

        switch o.id {
        case 2, 3, 6, 11, 14:
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
        case 7: // Skeleton spinning bone (`25`)
            guard o.gpr1 == 3 else { return }
            weaponId = 25
            angle = o.velocityAngleDeg()
            if angle == 0 { angle = 180 }
        case 8: // Black Demon 4-way spread (`24`)
            weaponId = 24
            shotsCount = 3
            angle = 240.0
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
                angle -= 35.0
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

    func spawnEnemyShot(
        weaponId: Int,
        x: CGFloat,
        y: CGFloat,
        speedX: CGFloat,
        speedY: CGFloat,
        angleDeg: CGFloat
    ) {
        guard let rect = MSXObjectTiles.objTiles[weaponId] else { return }
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
    }

    func moveEnemyShots() {
        let dt = CGFloat(Self.tickInterval)
        for shot in enemyShots where !shot.isFree {
            shot.x += shot.speedX * dt
            shot.y += shot.speedY * dt
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
            } else if shot.weaponId == 32 || shot.weaponId == 33 {
                shot.rotQuarterTurns = shot.gpr1 % 4
                shot.node.zRotation = -CGFloat(shot.rotQuarterTurns) * (.pi / 2.0)
                shot.gpr1 += 1
            }
        }
    }

    // MARK: - Enemy Collisions, Splitting & Destruction (`CollisionSystem::hitObject`)

    func hitEnemyObject(_ o: EnemyObject, instantKill: Bool) -> Bool {
        if o.id == 7 || o.id == 10 {
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

    func killEnemyObject(_ o: EnemyObject, playSfx: Bool = true) {
        let originalId = o.id
        let points = MSXObjectTiles.objPoints[originalId] ?? 100
        gameState?.incrementScore(points)
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
        let visualId = (o.id == 8 && o.gpr3 <= 1) ? 5 : o.id
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
        let visualId = (o.id == 8 && o.gpr3 <= 1) ? 5 : o.id
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
