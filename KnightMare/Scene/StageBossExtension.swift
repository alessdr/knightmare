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
            // Wide boss shadow six tiles below the body (`spawnShadow(body, 0, TILE_SIZE * 6, false, 37)`)
            spawnBossShadow(tileId: 37, offset: CGPoint(x: 0, y: Self.tileSizeF * 6.0))
        case .wingedDemon:
            boss.y = (currentRow == 0) ? (Self.tileSizeF * 6.0) : (-Self.tileSizeF * 3.0) // 48 or -24
            boss.phaseX = 45 // `body->gpr2 = 45`
            // Regular shadow under the feet (`spawnShadow(body, TILE_SIZE * 1.5, TILE_SIZE * 7, false, 0)`)
            spawnBossShadow(tileId: 39, offset: CGPoint(x: Self.tileSizeF * 1.5, y: Self.tileSizeF * 7.0))
        case .cyclops:
            boss.y = (currentRow == 0) ? (Self.tileSizeF * 5.0) : (-Self.tileSizeF * 4.0) // 40 or -32
            boss.phaseX = 45 // `body->gpr2 = 45`
            // Wide shadow under its taller 40×48 body (`spawnShadow(body, 0, TILE_SIZE * 8, false, 37)`)
            spawnBossShadow(tileId: 37, offset: CGPoint(x: 0, y: Self.tileSizeF * 8.0))
        }

        let tex = bossSheetTexture(x: bossBaseFrame.x, y: bossBaseFrame.y)
        let node = SKSpriteNode(texture: tex, size: bossFrameSize)
        node.zPosition = 9.5
        enemiesLayerNode.addChild(node)
        boss.node = node
    }

    private func spawnBossShadow(tileId: Int, offset: CGPoint) {
        guard let rect = MSXObjectTiles.objTiles[tileId] else { return }
        let shadow = SKSpriteNode(texture: shotTextureCache[tileId], size: CGSize(width: rect.w, height: rect.h))
        shadow.zPosition = 8
        shadowsLayerNode.addChild(shadow)
        boss.shadowNode = shadow
        boss.shadowOffset = offset
    }

    func activateBoss() {
        guard boss.status == .waiting else { return }
        boss.status = .active
        // The shadow stops following the body's vertical bob (`shadow->gpr3 = 1 // fixed height`)
        boss.shadowFixedY = boss.y + boss.shadowOffset.y

        switch definition.bossKind {
        case .medusa:
            if boss.y < 32 {
                boss.y = Self.tileSizeF * 6.0 // 48
            }
            // Enqueue 3 spinning ball/cloud minions (`id == 5`) at 3.0s, 6.5s, and 9.5s (`BossSystem.cpp` lines 25-27)
            enqueueBossMinion(delayMs: 3000)
            enqueueBossMinion(delayMs: 6500)
            enqueueBossMinion(delayMs: 9500)
        case .scytheReaper, .cyclops:
            break
        case .wingedDemon:
            // Starts with its wings folded: only the shield is up (`activateHitBox(2, false)`)
            boss.phase = 2
            boss.isShielded = true
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
            // Slow wide sweep across the screen with a quick, shallow vertical bob
            moveBossLissajous(speedX: 1.2, speedY: 9.0, height: 6.0, baseY: Self.tileSizeF * 5.0, dt: dt)
        case .wingedDemon, .cyclops:
            // Faster sweep with a slower, deeper bob
            moveBossLissajous(speedX: 1.8, speedY: 3.6, height: 12.0, baseY: Self.tileSizeF * 6.0, dt: dt)
        }
    }

    /// Size of one boss frame in `bosses.png` (`showBossBody`: the Stage 4 boss is a tile taller).
    var bossFrameSize: CGSize {
        switch definition.bossKind {
        case .medusa, .scytheReaper, .wingedDemon: return CGSize(width: 40, height: 40)
        case .cyclops: return CGSize(width: 40, height: 48)
        }
    }

    /// Lissajous drift shared by the Stage 2/3/4 bosses (`BossSystem::moveBoss` cases 2-4).
    private func moveBossLissajous(speedX: CGFloat, speedY: CGFloat, height: CGFloat, baseY: CGFloat, dt: CGFloat) {
        let center = (Self.msxWidth - Self.tileSizeF * 6.0) / 2.0 // 104
        boss.phaseX += 60.0 * dt * speedX
        boss.phaseY += 60.0 * dt * speedY
        boss.x = center + (center - Self.tileSizeX4) * sin(boss.phaseX * .pi / 180.0)
        boss.y = baseY + height * cos(boss.phaseY * .pi / 180.0)
    }

    /// Top-left of the boss's first frame inside `bosses.png` (`BossSystem::showBossBody`).
    var bossBaseFrame: (x: Int, y: Int) {
        switch definition.bossKind {
        case .medusa: return (0, 0)
        case .scytheReaper: return (80, 0)
        case .wingedDemon: return (200, 0)
        case .cyclops: return (0, 80)
        }
    }

    func animateBoss() {
        guard boss.status != .notSpawned, let node = boss.node else { return }
        switch definition.bossKind {
        case .medusa:
            let frameIndex = (animTick % 8 > 3 && boss.status != .dying) ? 1 : 0
            node.texture = bossSheetTexture(x: frameIndex * 40, y: 0)
        case .scytheReaper, .cyclops:
            // No idle animation: the frame only changes with the damage skin (`+40` / `+80` px)
            node.texture = bossSheetTexture(x: bossBaseFrame.x + boss.skinOffsetX, y: bossBaseFrame.y)
        case .wingedDemon:
            animateWingedDemon(node)
        }
    }

    /// Stage 3 boss cycle (`BossSystem::animateBoss` case 3), 48 animation ticks long: wings folded and shielded for
    /// the first half; then wings open (vulnerable), flapping between two frames, with a 7-way fan fired at tick 34.
    /// Eye colour follows the damage phase: white (2) → yellow (3) → third colour (4).
    private func animateWingedDemon(_ node: SKSpriteNode) {
        let tick = animTick % 48
        var x = (boss.phase == 3) ? 80 : 200
        let y = (boss.phase == 2) ? 0 : 40

        if tick > 23 {
            if tick == 24 {
                boss.isShielded = false
            } else if tick == 34 && boss.status == .active && freezeTimer < 0 && playerState == .playing {
                fireDemonFan()
            }
            x += (animTick % 4 < 2 || boss.status == .dying) ? 40 : 80
        } else if tick == 0 {
            boss.isShielded = true
        }
        node.texture = bossSheetTexture(x: x, y: y)
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
        case .wingedDemon:
            break // only fires from its wing cycle (`animateWingedDemon`)
        case .cyclops:
            guard tickCount % 120 == 0 else { return }
            fireCyclopsFireball()
        }
    }

    /// Stage 4 boss (`calcId == 54`, stage 4 variant): a red fireball (`28`, sprite `+16` px) thrown downward
    /// toward Popolon that lands at the height he stood when it was fired and burns there for a moment.
    private func fireCyclopsFireball() {
        let originX = boss.x + Self.tileSizeX2
        let originY = boss.y + Self.tileSizeF * 4.0
        let aim = min(210.0, max(150.0, compassAngleTowardPopolon(fromX: originX, fromY: originY)))
        let radians = aim * .pi / 180.0
        let speed: CGFloat = 110
        guard let shot = spawnEnemyShot(
            weaponId: 28,
            x: originX,
            y: originY,
            speedX: speed * sin(radians),
            speedY: -speed * cos(radians),
            angleDeg: aim
        ) else { return }
        shot.stopAtY = playerY
        shot.node.texture = SpriteSheetManager.shared.texture(from: .objects, x: 99 + 16, y: 35, width: 9, height: 9)
    }

    /// Stage 3 boss (`calcId == 53`): 7 fireballs (`28`) fanned ±60° in 20° steps around a downward aim at Popolon.
    private func fireDemonFan() {
        let originX = boss.x + Self.tileSizeX2
        let originY = boss.y + Self.tileSizeF * 3.0
        let aim = min(200.0, max(160.0, compassAngleTowardPopolon(fromX: originX, fromY: originY)))
        let speed: CGFloat = 110
        for spread in stride(from: -60.0, through: 60.0, by: 20.0) {
            let radians = (aim - spread) * .pi / 180.0
            spawnEnemyShot(
                weaponId: 28,
                x: originX,
                y: originY,
                speedX: speed * sin(radians),
                speedY: -speed * cos(radians),
                angleDeg: aim - spread
            )
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
        CGRect(x: boss.x + 4.0, y: boss.y + 4.0, width: bossFrameSize.width - 8.0, height: bossFrameSize.height - 8.0)
    }

    func hitBoss() -> Bool {
        guard boss.status == .active else { return false }

        if definition.bossKind == .wingedDemon && boss.isShielded {
            // Folded wings deflect the shot (`BossSystem::hitBoss` case 3)
            RetroAudioSynthesizer.shared.playSfx(.bossShield)
            return true
        }

        let damage = playerWeapon.isSuperWeapon ? 2 : 1
        let previousHp = boss.hp
        boss.hp = max(0, boss.hp - damage)
        syncHudState()

        if definition.bossKind == .wingedDemon {
            // Next eye colour at 2/3 and 1/3 of the base life (`status++` at `aux * 2` and `aux`). Crossing is used
            // instead of the reference's exact match so 2-damage super weapons can't skip a threshold.
            let third = definition.bossBaseLife / 3
            for threshold in [third * 2, third] where previousHp > threshold && boss.hp <= threshold && boss.hp > 0 {
                boss.phase = min(4, boss.phase + 1)
            }
        }

        if definition.bossKind == .scytheReaper || definition.bossKind == .cyclops {
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
        // From here on Popolon is drawn behind the castle wall, so he vanishes into the doorway
        clipPlayerBelowCastleWall()
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

        // Fully inside the castle: the wall's bottom edge (y = 24) is past his feet (sprite space `y` = bottom - 16)
        if Int(playerY) <= Int(targetY) {
            playerSpriteNode.isHidden = true
            shieldSpriteNode.isHidden = true
            boss.wipeStep = 0
            playerState = .stageClearWipe
        }
    }

    /// Closes the screen toward its centre (`ObjectSystem::fadeMap`): each animation tick the window shrinks
    /// 2 px vertically and 3.2 px horizontally per side, holds briefly at its smallest, then the stage ends.
    func updateStageClearWipe() {
        boss.wipeStep += 1
        let closingSteps = 30
        let holdSteps = 10
        let step = CGFloat(min(boss.wipeStep, closingSteps))
        let insetY = 2.0 * step
        let insetX = 3.2 * step
        showExitWindow(
            left: insetX,
            top: insetY,
            width: Self.msxWidth - insetX * 2.0,
            height: Self.msxHeight - insetY * 2.0
        )

        if boss.wipeStep >= closingSteps + holdSteps {
            showExitWindow(left: Self.msxWidth / 2.0, top: Self.msxHeight / 2.0, width: 0, height: 0)
            playerState = .stageCleared
            gameState?.triggerStageClear(weapon: playerWeapon, speedLevel: playerSpeedLevel)
        }
    }

    // MARK: - Texture Helper & Interactive Boss Jump

    /// Boss frame (`bossFrameSize`) whose top-left corner is `(x, y)` in `bosses.png`.
    func bossSheetTexture(x: Int, y: Int) -> SKTexture? {
        let key = y * 1000 + x
        if let cached = bossFrameTextureCache[key] {
            return cached
        }
        let tex = SpriteSheetManager.shared.texture(from: .bosses, x: x, y: y, width: Int(bossFrameSize.width), height: Int(bossFrameSize.height))
        bossFrameTextureCache[key] = tex
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
