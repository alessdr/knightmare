import SpriteKit

// MARK: - Marco 6: Stage Bosses (Medusa / Scythe Reaper), Death Sequence & Portal Clear (`BossSystem.cpp`)

extension StageScene {

    // MARK: - Map Scroll Triggers (`MapSystem::checkBossTriggers`)

    func checkBossMapTriggers(row: Int) {
        if row < 0 {
            activateBoss()
            return
        }
        if row == 8 {
            RetroAudioSynthesizer.shared.playBossMusic(definition.bossMusic)
            for eShot in enemyShots where !eShot.isFree {
                eShot.isFree = true
            }
            killAllActiveEnemies(playSfx: false)
        } else if row == 7 {
            spawnBoss()
        }
    }

    // MARK: - Boss Spawning & Activation (`BossSystem::spawnBoss` & `activateBoss`)

    func spawnBoss() {
        boss.reset()

        let baseLife = Double(definition.bossBaseLife) * (gameState?.difficulty.bossLifeMultiplier ?? 1.0)
        boss.maxHp = max(1, Int(round(baseLife)))
        boss.hp = boss.maxHp
        boss.status = .waiting
        boss.x = Self.msxWidth / 2.0 - Self.tileSizeF * 2.5 // 108
        boss.stepTick = 0
        boss.targetX = Self.msxWidth / 2.0 - Self.tileSizeX2 // 112

        switch definition.bossKind {
        case .medusa:
            boss.y = (currentRow == 0) ? (Self.tileSizeF * 6.0) : (-Self.tileSizeF * 3.0) // 48 or -24
        case .scytheReaper:
            boss.y = (currentRow == 0) ? (Self.tileSizeF * 5.0) : (-Self.tileSizeF * 4.0) // 40 or -32
            // Wide boss shadow (`t[37]`) six tiles below the body (`spawnShadow(body, 0, TILE_SIZE * 6, false, 37)`)
            let shadow = SKSpriteNode(texture: shotTextureCache[37], size: CGSize(width: 40, height: 6))
            shadow.zPosition = 8
            shadowsLayerNode.addChild(shadow)
            boss.shadowNode = shadow
        }

        let tex = bossFrameTexture(frameIndex: bossBaseFrameIndex)
        let node = SKSpriteNode(texture: tex, size: CGSize(width: 40, height: 40))
        node.zPosition = 9.5
        enemiesLayerNode.addChild(node)
        boss.node = node
    }

    func activateBoss() {
        guard boss.status == .waiting else { return }
        boss.status = .active
        // The shadow stops following the body's vertical bob (`shadow->gpr3 = 1 // fixed height`)
        boss.shadowFixedY = boss.y + Self.tileSizeF * 6.0

        switch definition.bossKind {
        case .medusa:
            if boss.y < 32 {
                boss.y = Self.tileSizeF * 6.0 // 48
            }
            // Enqueue 3 spinning ball/cloud minions (`id == 5`) at 3.0s, 6.5s, and 9.5s (`BossSystem.cpp` lines 25-27)
            enqueueBossMinion(delayMs: 3000)
            enqueueBossMinion(delayMs: 6500)
            enqueueBossMinion(delayMs: 9500)
        case .scytheReaper:
            break
        }
        syncHudState()
    }

    func enqueueBossMinion(delayMs: Int) {
        spawnQueue.append(
            QueuedSpawnAction(
                execCount: 1,
                objId: 5,
                x: 0,
                y: 0,
                objCfg: 0,
                delayMs: delayMs,
                nextExecMs: clockMs + delayMs,
                waveGroupId: 0
            )
        )
    }

    func scheduleBossMinionReplacement() {
        guard boss.status == .active else { return }
        let randomDelay = Int.random(in: 2000...8000)
        enqueueBossMinion(delayMs: randomDelay)
    }

    func scrollBoss() {
        guard boss.status != .notSpawned, boss.status != .dying else { return }
        boss.y += 1
    }

    // MARK: - Boss Movement, Animation & Firing (`moveBoss`, `animateBoss`, `bossFire`)

    func moveBoss() {
        if boss.status == .dying {
            updateBossDeathSequence()
            return
        }
        if boss.portalStartMs > 0 && !boss.isPortalActive && clockMs >= boss.portalStartMs {
            boss.portalStartMs = 0
            startPortalExitSequence()
            return
        }

        guard boss.status == .active else { return }
        guard freezeTimer < 0 else { return }

        let dt = CGFloat(Self.tickInterval)

        switch definition.bossKind {
        case .medusa:
            let edgeLeft = Self.tileSizeX4 // 32
            let rightEdge = (Self.msxWidth - Self.tileSizeX4) - (Self.tileSizeF * 5.0) // 224 - 40 = 184

            boss.stepTick += 1
            if abs(boss.x - boss.targetX) <= 0.75 {
                boss.x = boss.targetX
                if boss.stepTick % 150 == 0 {
                    boss.targetX = min(max(playerX - Self.tileSizeX2, edgeLeft), rightEdge)
                }
            } else {
                let dir: CGFloat = (boss.x > boss.targetX) ? -1.0 : 1.0
                boss.x += dir * 60.0 * dt // BOSS_SPEED = 60
            }

        case .scytheReaper:
            // Lissajous drift: slow wide sweep across the screen with a quick, shallow vertical bob
            let center = (Self.msxWidth - Self.tileSizeF * 6.0) / 2.0 // 104
            boss.phaseX += 60.0 * dt * 1.2
            boss.phaseY += 60.0 * dt * 9.0
            boss.x = center + (center - Self.tileSizeX4) * sin(boss.phaseX * .pi / 180.0)
            boss.y = Self.tileSizeF * 5.0 + 6.0 * cos(boss.phaseY * .pi / 180.0)
        }
    }

    /// Column (40 px frames) of the boss's first frame inside `bosses.png`.
    var bossBaseFrameIndex: Int {
        switch definition.bossKind {
        case .medusa: return 0
        case .scytheReaper: return 2 // `showBossBody` stage 2: `tx = 80`
        }
    }

    func animateBoss() {
        guard boss.status != .notSpawned, let node = boss.node else { return }
        switch definition.bossKind {
        case .medusa:
            let frameIndex = (animTick % 8 > 3 && boss.status != .dying) ? 1 : 0
            node.texture = bossFrameTexture(frameIndex: frameIndex)
        case .scytheReaper:
            // No idle animation: the frame only changes with the damage skin (`+40` / `+80` px)
            node.texture = bossFrameTexture(frameIndex: bossBaseFrameIndex + boss.skinOffsetX / 40)
        }
    }

    func bossFireTick() {
        guard boss.status == .active, freezeTimer < 0, playerState == .playing else { return }

        switch definition.bossKind {
        case .medusa:
            guard tickCount % 70 == 0 else { return }
            fireMedusaRay()
        case .scytheReaper:
            guard tickCount % 120 == 0 else { return }
            fireScythe()
        }
    }

    /// Stage 2 boss (`calcId == 52`): a scythe (`33`) that orbits a point 64 px below the boss,
    /// alternating clockwise / counter-clockwise on every throw.
    private func fireScythe() {
        guard let shot = spawnEnemyShot(
            weaponId: 33,
            x: boss.x + Self.tileSizeF,
            y: boss.y + Self.tileSizeF,
            speedX: 0,
            speedY: 0,
            angleDeg: 0
        ) else { return }
        boss.stepTick += 1
        shot.orbitCenter = CGPoint(x: boss.x, y: boss.y + Self.tileSizeF * 8.0)
        shot.orbitStep = (boss.stepTick % 2 != 0) ? 1 : -1
    }

    private func fireMedusaRay() {

        // Stage 1 Boss (`calcId == 51`) fires energy ray (`weaponId = 24`, speed = 120)
        let startX = boss.x + 15.0
        let startY = boss.y + 28.0
        let dx = playerX - startX
        let dy = max(24.0, playerY - startY)
        let dist = hypot(dx, dy)
        let speed: CGFloat = 120.0
        // Aim within a downward cone toward Popolon
        let vx = max(-65.0, min(65.0, (dx / dist) * speed))
        let vy = sqrt(max(3600.0, speed * speed - vx * vx))

        spawnEnemyShot(
            weaponId: 24,
            x: startX,
            y: startY,
            speedX: vx,
            speedY: vy,
            angleDeg: 180
        )
    }

    // MARK: - Boss Collisions & Damage (`hitBoss`, `killBoss`, `destroyBoss`)

    func bossHitBoxRect() -> CGRect {
        // Central vulnerable hitbox on Medusa's head/face (`BossSystem::createBossHitBox`)
        CGRect(x: boss.x + 8.0, y: max(-7.0, boss.y + 8.0), width: 24.0, height: 24.0)
    }

    func bossBodyRect() -> CGRect {
        CGRect(x: boss.x + 4.0, y: boss.y + 4.0, width: 32.0, height: 32.0)
    }

    func hitBoss() -> Bool {
        guard boss.status == .active else { return false }

        let damage = playerWeapon.isSuperWeapon ? 2 : 1
        boss.hp = max(0, boss.hp - damage)
        syncHudState()

        if definition.bossKind == .scytheReaper {
            // Swap to a more battered skin at each third of the base life (`BossSystem::hitBoss` action 90)
            let third = definition.bossBaseLife / 3
            if third > 0 && boss.hp % third == 0 {
                boss.skinOffsetX = (boss.hp / third <= 1) ? 80 : 40
                animateBoss()
            }
        }

        if boss.hp <= 0 {
            killBoss()
        } else {
            RetroAudioSynthesizer.shared.playSfx(.bossHit)
            if let node = boss.node {
                node.removeAction(forKey: "bossHitFlash")
                node.run(
                    .sequence([
                        .fadeAlpha(to: 0.45, duration: 0.04),
                        .fadeAlpha(to: 1.0, duration: 0.05)
                    ]),
                    withKey: "bossHitFlash"
                )
            }
        }
        return true
    }

    func killBoss() {
        boss.status = .dying
        boss.hp = 0
        gameState?.incrementScore(10_000) // +10,000 pts Boss Clear Bonus (`BossSystem.cpp` line 104)
        spawnQueue.removeAll()

        for eShot in enemyShots where !eShot.isFree {
            eShot.isFree = true
        }
        killAllActiveEnemies(playSfx: false)
        animateBoss()

        RetroAudioSynthesizer.shared.stopMusic()
        RetroAudioSynthesizer.shared.playSfx(.bossKill)

        // Enqueue 30 screen blinks at 40ms intervals (`ActionQueueSystem` actionId 100)
        boss.deathBlinksRemaining = 30
        boss.nextBlinkTimeMs = clockMs + 40
        syncHudState()
    }

    private func updateBossDeathSequence() {
        guard boss.deathBlinksRemaining > 0, clockMs >= boss.nextBlinkTimeMs else { return }

        let isOdd = (boss.deathBlinksRemaining % 2 != 0)
        flashOverlayNode.removeAllActions()
        flashOverlayNode.alpha = isOdd ? 0.55 : 0.0

        if boss.deathBlinksRemaining == 1 {
            destroyBoss()
        }

        boss.deathBlinksRemaining -= 1
        boss.nextBlinkTimeMs = clockMs + 40
        if boss.deathBlinksRemaining <= 0 {
            flashOverlayNode.alpha = 0.0
        }
    }

    private func destroyBoss() {
        let bx = boss.x
        let by = boss.y

        boss.node?.removeFromParent()
        boss.node = nil
        boss.shadowNode?.removeFromParent()
        boss.shadowNode = nil
        boss.status = .notSpawned
        flashOverlayNode.alpha = 0.0

        // Spawn 5 fire explosions (`id == 34`) across Medusa's 40x40 body (`BossSystem::destroyBoss`)
        let offsets: [(CGFloat, CGFloat)] = [
            (Self.tileSizeX2, Self.tileSizeF),
            (0, Self.tileSizeX2),
            (Self.tileSizeX4, Self.tileSizeF * 3.0),
            (Self.tileSizeF * 5.0, Self.tileSizeX4),
            (Self.tileSizeF, Self.tileSizeF * 5.0)
        ]
        for (ox, oy) in offsets {
            if let exp = spawnEnemyObject(id: 34, x: bx + ox, y: by + oy, objCfg: 1, waveGroupId: 0, enqueueRemaining: false) {
                exp.gpr1 = 0
                applyEnemyBaseTile(exp, tileId: 34)
            }
        }
        RetroAudioSynthesizer.shared.playSfx(.enemyKill)

        // Schedule `movePlayerToPortal` in 1500ms (`ActionQueueSystem` actionId 101)
        boss.portalStartMs = clockMs + 1500
        syncHudState()
    }

    // MARK: - Portal & Stage 1 Clear Sequence (`movePlayerToPortal`, `autoMovePlayerToPortal`, `fadeMap`)

    private func startPortalExitSequence() {
        boss.isPortalActive = true
        powerUpState = .none
        powerUpTimer = -1
        shieldHits = 0
        updateShieldAppearance()

        RetroAudioSynthesizer.shared.playStageStartFanfare()
        playerState = .movingToPortal
        syncHudState()
    }

    func autoMovePlayerToPortal() {
        let dt = CGFloat(Self.tickInterval)
        let targetX = Self.msxWidth / 2.0 - Self.tileSizeF // 120
        let targetY = Self.tileSizeF // 8
        let speed: CGFloat = 55.0

        if abs(playerX - targetX) > 1.0 {
            playerX += (playerX < targetX ? 1.0 : -1.0) * speed * dt
        } else {
            playerX = targetX
            if playerY > targetY {
                playerY -= speed * dt
            }
        }
        playerIsMoving = true

        if Int(playerY) <= Int(targetY) {
            playerSpriteNode.isHidden = true
            shieldSpriteNode.isHidden = true
            boss.wipeStep = 0
            playerState = .stageClearWipe
        }
    }

    func updateStageClearWipe() {
        boss.wipeStep += 1
        let progress = min(1.0, CGFloat(boss.wipeStep) / 22.0)
        flashOverlayNode.color = .black
        flashOverlayNode.alpha = progress

        if boss.wipeStep >= 24 {
            playerState = .stageCleared
            gameState?.triggerStageClear(weapon: playerWeapon, speedLevel: playerSpeedLevel)
        }
    }

    // MARK: - Texture Helper & Interactive Boss Jump

    func bossFrameTexture(frameIndex: Int) -> SKTexture? {
        if let cached = bossFrameTextureCache[frameIndex] {
            return cached
        }
        let tex = SpriteSheetManager.shared.texture(
            from: .bosses,
            x: frameIndex * 40,
            y: 0,
            width: 40,
            height: 40
        )
        bossFrameTextureCache[frameIndex] = tex
        return tex
    }

    /// Interactive helper for the HUD "BOSS" button to jump straight to the Stage 1 Boss encounter (`currentRow = 8`).
    func jumpToBossEncounter() {
        guard playerState == .playing else { return }
        clearDynamicEntities()
        boss.reset()
        flashOverlayNode.color = .white
        flashOverlayNode.alpha = 0

        currentRow = 9
        tilePx = 7
        scrollOn = true
        freezeTimer = -1
        refreshMapTileTextures()
        syncHudState()
        syncAllNodePositions()
    }
}
