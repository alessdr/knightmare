import SpriteKit
import SwiftUI

/// SpriteKit scene implementing the 256×176 MSX playfield for the stage described by `definition`,
/// including binary map scrolling (`stageN.map`), Popolon 8-directional movement,
/// solid terrain collisions, scroll-crush detection, Marco 3's Weapon/Crystal/Shield/Aura
/// system, and Marco 4's `?` Blocks, Chess Pieces (Rook, King, Knight, Queen), and Water Bridges.
@MainActor
final class StageScene: SKScene {
    // MARK: - MSX Constants (matching Constants.h)
    static let msxWidth: CGFloat = 256
    static let msxHeight: CGFloat = 176
    static let tileSize: Int = 8
    static let tileSizeF: CGFloat = 8.0
    static let tileSizeX2: CGFloat = 16.0
    static let tileSizeX4: CGFloat = 32.0
    static let screenCols: Int = 32
    static let screenRows: Int = 22

    static let tickInterval: TimeInterval = 1.0 / 120.0
    static let tickMs: Int = 1000 / 120
    private static let playerInitSpeed: CGFloat = 60.0
    private static let playerSpeedInc: CGFloat = 20.0
    private static let playerMaxSpeed: CGFloat = 120.0
    private static let playerInitCol: Int = 15
    private static let playerInitRow: Int = 21
    private static let shieldMaxHits: Int = 15
    private static let powerUpDuration: CGFloat = 50.0
    private static let freezeDuration: CGFloat = 50.0
    private static let playerDeathAnim: [Int] = [
        0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12,
        14, 16, 18, 20, 22, 22, 22, 22, 22, 22
    ]

    // MARK: - Runtime Models
    enum PlayerState: Equatable {
        case playing
        case dead
        case restartStage
        case movingToPortal
        case stageClearWipe
        case stageCleared
    }

    private final class PlayerShot {
        let node: SKSpriteNode
        let weapon: MSXWeapon
        var tileId: Int
        var x: CGFloat
        var y: CGFloat
        var speedX: CGFloat
        var speedY: CGFloat
        var animStep: Int = 0
        var rotQuarterTurns: Int = 0
        var isFree: Bool = false

        init(
            node: SKSpriteNode,
            weapon: MSXWeapon,
            tileId: Int,
            x: CGFloat,
            y: CGFloat,
            speedX: CGFloat,
            speedY: CGFloat
        ) {
            self.node = node
            self.weapon = weapon
            self.tileId = tileId
            self.x = x
            self.y = y
            self.speedX = speedX
            self.speedY = speedY
        }
    }

    /// Floating Weapon Orb (`id == 20`) or Power Crystal (`id == 21`).
    private final class PickupOrb {
        let id: Int // 20 = Weapon Orb, 21 = Power Crystal
        let node: SKSpriteNode
        let shadowNode: SKSpriteNode
        var x: CGFloat
        var y: CGFloat
        var gpr1: Int = 0
        var gpr2: Int = 1
        var gpr3: CGFloat = -1.0
        var renderOffsetX: CGFloat = 0
        var isFree: Bool = false

        init(id: Int, node: SKSpriteNode, shadowNode: SKSpriteNode, x: CGFloat, y: CGFloat) {
            self.id = id
            self.node = node
            self.shadowNode = shadowNode
            self.x = x
            self.y = y
        }
    }

    /// Interactive `?` Block & Chess Piece (`objId == 22`, matching `Block` in `GameState.h`).
    private final class QuestionBlock {
        let node: SKSpriteNode
        let mapRow: Int
        let mapCol: Int
        let initialType: MSXBlockType
        var type: MSXBlockType
        var x: CGFloat
        var y: CGFloat
        var hits: Int = 0
        var isHidden: Bool = true
        var isFree: Bool = false

        init(node: SKSpriteNode, mapRow: Int, mapCol: Int, type: MSXBlockType, x: CGFloat, y: CGFloat) {
            self.node = node
            self.mapRow = mapRow
            self.mapCol = mapCol
            self.initialType = type
            self.type = type
            self.x = x
            self.y = y
        }
    }

    /// Bridge sprite (`objId == 48`, `{184, 136, 32, 8}`) scrolling with the map.
    private final class BridgeSprite {
        let node: SKSpriteNode
        var x: CGFloat
        var y: CGFloat
        var isFree: Bool = false

        init(node: SKSpriteNode, x: CGFloat, y: CGFloat) {
            self.node = node
            self.x = x
            self.y = y
        }
    }

    // MARK: - External References
    weak var gameState: GameStateManager?
    weak var inputController: InputController?

    // MARK: - Map & Scroll State
    var definition: StageDefinition = .stage1
    private var mapData = StageMapData()
    var currentRow: Int = StageMapData.mapRows0 - StageMapData.screenRows // 215
    var tilePx: Int = 0
    var scrollOn: Bool = true
    private var isGamePaused: Bool = false

    // MARK: - Timing State
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    var tickCount: Int = 0
    var animTick: Int = 0
    var clockMs: Int = 0
    private var restartWaitElapsed: TimeInterval = 0

    // MARK: - Popolon State & Power-Ups
    var playerState: PlayerState = .playing
    var playerX: CGFloat = 120
    var playerY: CGFloat = 168
    private var playerSpeed: CGFloat = StageScene.playerInitSpeed
    var playerWeapon: MSXWeapon = .arrow
    var powerUpState: MSXPowerUpState = .none
    var powerUpTimer: CGFloat = -1
    var freezeTimer: CGFloat = -1
    var shieldHits: Int = 0
    private var playerAnimCounter: CGFloat = 0
    private var playerAnimOffsetX: Int = 0
    var playerIsMoving: Bool = false
    private var fireDownLastFrame: Bool = false
    private var lastShotTimeMs: Int = -100_000
    /// Set when Popolon fires, cleared after each animation tick (`s.fire`); Red Death ghosts react to it.
    var playerFiredSinceAnimTick: Bool = false
    private var testBlockCycleIndex: Int = 0
    private var testWaveCycleIndex: Int = 0

    // MARK: - Scene Nodes & Texture Caches
    private let mapLayerNode = SKNode()
    let blocksLayerNode = SKNode()
    let shadowsLayerNode = SKNode()
    let enemiesLayerNode = SKNode()
    private let pickupsLayerNode = SKNode()
    let shotsLayerNode = SKNode()
    let playerSpriteNode = SKSpriteNode()
    /// Holds Popolon; masked to below the castle wall while he walks through the stage exit door.
    let playerClipNode = SKCropNode()
    let shieldSpriteNode = SKSpriteNode()
    let flashOverlayNode = SKSpriteNode(color: .white, size: CGSize(width: 256, height: 176))
    /// Black bands (top, bottom, left, right) of the closing stage-exit window (`ObjectSystem::fadeMap`).
    let exitWindowNodes: [SKSpriteNode] = (0..<4).map { _ in SKSpriteNode(color: .black, size: .zero) }

    private let visibleRowOffsets: [Int] = Array(-1...(StageScene.screenRows + 1))
    private var tileGridNodes: [[SKSpriteNode]] = []
    private var mapTileTextureCache: [Int: SKTexture] = [:]
    var shotTextureCache: [Int: SKTexture] = [:]
    private var shieldTextureCache: [Int: SKTexture] = [:]
    private var blockQuestionTexture: SKTexture?
    private var chessPieceTextureCache: [MSXBlockType: SKTexture] = [:]
    private var bridgeSpriteTexture: SKTexture?
    var shadowTexture: SKTexture?
    var bossFrameTextureCache: [Int: SKTexture] = [:]

    private var playerShots: [PlayerShot] = []
    private var pickupOrbs: [PickupOrb] = []
    private var questionBlocks: [QuestionBlock] = []
    private var bridgeSprites: [BridgeSprite] = []
    var enemies: [EnemyObject] = []
    var fissures: [GroundFissure] = []
    var enemyShots: [EnemyShot] = []
    var spawnQueue: [QueuedSpawnAction] = []
    var waveTrackers: [Int: EnemyWaveTracker] = [:]
    var nextWaveGroupId: Int = 0
    let boss = StageBossRuntime()

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0, y: 0)

        removeAllChildren()
        setupTextureCaches()
        setupMapGridNodes()
        setupPlayerNodes()

        addChild(mapLayerNode)
        addChild(blocksLayerNode)
        addChild(shadowsLayerNode)
        addChild(enemiesLayerNode)
        addChild(pickupsLayerNode)
        addChild(shotsLayerNode)
        playerSpriteNode.removeFromParent()
        playerClipNode.addChild(playerSpriteNode)
        addChild(playerClipNode)
        addChild(shieldSpriteNode)

        flashOverlayNode.position = CGPoint(x: Self.msxWidth / 2, y: Self.msxHeight / 2)
        flashOverlayNode.zPosition = 50
        flashOverlayNode.alpha = 0
        addChild(flashOverlayNode)

        for node in exitWindowNodes {
            node.zPosition = 49
            node.isHidden = true
            addChild(node)
        }

        startNewStage()
    }

    // MARK: - Setup

    private func setupTextureCaches() {
        let sheets = SpriteSheetManager.shared
        for id in 0..<128 {
            let tx = (id % SpriteSheetManager.tilesCols) * SpriteSheetManager.tileSize
            let ty = (id / SpriteSheetManager.tilesCols) * SpriteSheetManager.tileSize + definition.tilesetOffsetPx
            if let tex = sheets.texture(from: .maps, x: tx, y: ty, width: 8, height: 8) {
                mapTileTextureCache[id] = tex
            }
        }

        for (tileId, rect) in MSXObjectTiles.objTiles {
            if let tex = sheets.texture(from: .objects, x: rect.x, y: rect.y, width: rect.w, height: rect.h) {
                shotTextureCache[tileId] = tex
            }
        }

        for idx in 0..<3 {
            if let tex = sheets.texture(from: .objects, x: 136 + idx * 16, y: 48, width: 16, height: 7) {
                shieldTextureCache[idx] = tex
            }
        }

        // `[?]` Block sprite (`t[22] = {0, 104, 16, 16}`) and Chess Pieces (`offset = 16 * b.type`)
        blockQuestionTexture = sheets.texture(from: .objects, x: 0, y: 104, width: 16, height: 16)
        for blockType in [MSXBlockType.rook, .knight, .queen, .king, .barrier, .collected] {
            let tx = 16 * blockType.rawValue
            if let tex = sheets.texture(from: .objects, x: tx, y: 104, width: 16, height: 16) {
                chessPieceTextureCache[blockType] = tex
            }
        }

        // Bridge sprite (`t[48] = {184, 136, 32, 8}`)
        bridgeSpriteTexture = sheets.texture(from: .objects, x: 184, y: 136, width: 32, height: 8)

        // Shadow sprite (`t[39] = {0, 33, 16, 6}`)
        shadowTexture = sheets.texture(from: .objects, x: 0, y: 33, width: 16, height: 6)
    }

    private func setupMapGridNodes() {
        mapLayerNode.removeAllChildren()
        tileGridNodes.removeAll()

        for rOffset in visibleRowOffsets {
            var rowNodes: [SKSpriteNode] = []
            let msxTopY = CGFloat(rOffset * Self.tileSize)
            for col in 0..<Self.screenCols {
                let msxX = CGFloat(col * Self.tileSize)
                let node = SKSpriteNode(color: .black, size: CGSize(width: 8, height: 8))
                node.position = Self.scenePosition(msxX: msxX, msxTopY: msxTopY, width: 8, height: 8)
                node.zPosition = 1
                mapLayerNode.addChild(node)
                rowNodes.append(node)
            }
            tileGridNodes.append(rowNodes)
        }
    }

    private func setupPlayerNodes() {
        playerSpriteNode.size = CGSize(width: 16, height: 16)
        // The layer depth lives on the crop node: once it gets a mask (stage exit door) SpriteKit renders the
        // cropped subtree as one unit at the crop node's own zPosition, so a z of 0 there drew Popolon under the map.
        playerClipNode.zPosition = 20
        playerSpriteNode.zPosition = 0
        updatePlayerTexture()

        shieldSpriteNode.size = CGSize(width: 16, height: 7)
        shieldSpriteNode.zPosition = 21
        shieldSpriteNode.isHidden = true
    }

    // MARK: - Stage Initialization & Respawn

    func startNewStage() {
        currentRow = StageMapData.mapRows0 - StageMapData.screenRows // 215
        // Weapon and speed upgrades carry over from the previous stage (GDD §8)
        playerWeapon = gameState?.carriedWeapon ?? .arrow
        let carriedSpeedLevel = CGFloat(gameState?.carriedSpeedLevel ?? 0)
        playerSpeed = min(Self.playerMaxSpeed, Self.playerInitSpeed + Self.playerSpeedInc * carriedSpeedLevel)
        powerUpState = .none
        powerUpTimer = -1
        freezeTimer = -1
        shieldHits = 0
        resetStageAttempt()
    }

    /// Current speed upgrade level (`0...3`), as shown on the HUD.
    var playerSpeedLevel: Int {
        Int(round((playerSpeed - Self.playerInitSpeed) / Self.playerSpeedInc))
    }

    func clearDynamicEntities() {
        for fissure in fissures { fissure.node.removeFromParent() }
        fissures.removeAll()

        for shot in playerShots { shot.node.removeFromParent() }
        playerShots.removeAll()

        for orb in pickupOrbs {
            orb.node.removeFromParent()
            orb.shadowNode.removeFromParent()
        }
        pickupOrbs.removeAll()

        for block in questionBlocks { block.node.removeFromParent() }
        questionBlocks.removeAll()

        for bridge in bridgeSprites { bridge.node.removeFromParent() }
        bridgeSprites.removeAll()

        for enemy in enemies {
            enemy.node.removeFromParent()
            enemy.shadowNode?.removeFromParent()
        }
        enemies.removeAll()

        for eShot in enemyShots { eShot.node.removeFromParent() }
        enemyShots.removeAll()

        spawnQueue.removeAll()
        waveTrackers.removeAll()
    }

    private func resetStageAttempt() {
        // Reload a pristine map on every attempt so opened barriers and bridges reset (`Engine::initStage` → `loadMap`)
        mapData = StageMapData(assetName: definition.mapAssetName)
        clearDynamicEntities()
        boss.reset()
        flashOverlayNode.color = .white
        flashOverlayNode.alpha = 0
        playerSpriteNode.isHidden = false
        playerClipNode.maskNode = nil
        hideExitWindow()

        tilePx = 0
        clockMs = 0
        tickCount = 0
        animTick = 0
        lastShotTimeMs = -100_000
        freezeTimer = -1
        scrollOn = (currentRow > 0)
        restartWaitElapsed = 0

        playerState = .playing
        playerX = CGFloat(Self.playerInitCol * Self.tileSize)
        playerY = CGFloat(Self.playerInitRow * Self.tileSize)
        playerAnimCounter = 0
        playerAnimOffsetX = 0
        playerIsMoving = false

        // Populate any `?` blocks already inside the initial visible screen window
        let maxInitialRow = min(StageMapData.mapRows0, currentRow + Self.screenRows - 1)
        if currentRow <= maxInitialRow {
            for r in currentRow...maxInitialRow {
                spawnBlocksInRow(row: r)
            }
        }

        if currentRow <= 7 {
            spawnBoss()
            if currentRow == 0 {
                activateBoss()
            }
        }

        refreshMapTileTextures()
        updateShieldAppearance()
        syncHudState()
        syncAllNodePositions()

        playCurrentStageTheme()
    }

    private func playCurrentStageTheme() {
        if currentRow > 8 {
            RetroAudioSynthesizer.shared.playStageMusic(definition.stageMusic)
        } else {
            RetroAudioSynthesizer.shared.playBossMusic(definition.bossMusic)
        }
    }

    private func calculateStartRow() {
        if currentRow <= 10 {
            currentRow = 0
            return
        }
        // Measure against the pristine map the next attempt will use: bridges opened in this attempt close again
        mapData = StageMapData(assetName: definition.mapAssetName)

        // Step back until Popolon's whole 2×2 footprint is free. He spawns at `y = playerInitRow * 8` in sprite space,
        // i.e. screen rows `playerInitRow - 2 ... playerInitRow - 1` (`mapCollide` subtracts 16 px). The reference only
        // skipped rows where *every* cell was solid, two rows too low, which could respawn him half inside a river.
        let lastRow = StageMapData.mapRows0 - StageMapData.screenRows
        let footprintTopRow = Self.playerInitRow - 2
        currentRow = min(lastRow, currentRow + 5)
        while currentRow < lastRow && isFootprintSolid(topRow: currentRow + footprintTopRow, col: Self.playerInitCol) {
            currentRow += 1
        }
    }

    private func isFootprintSolid(topRow: Int, col: Int) -> Bool {
        for r in topRow...(topRow + 1) {
            for c in col...(col + 1) where mapData.isSolid(row: r, col: c) {
                return true
            }
        }
        return false
    }

    func togglePause() {
        isGamePaused.toggle()
        if isGamePaused {
            RetroAudioSynthesizer.shared.pauseMusic()
        } else {
            RetroAudioSynthesizer.shared.resumeMusic()
        }
        RetroAudioSynthesizer.shared.playPause()
        gameState?.isStagePaused = isGamePaused
    }

    // MARK: - Interactive Test Helpers for Marcos 3 & 4

    func spawnTestWeaponOrb() {
        let spawnX = min(Self.msxWidth - Self.tileSizeF * 6, max(Self.tileSizeX4, playerX))
        spawnPickupOrb(id: 20, x: spawnX, y: 16)
    }

    func spawnTestPowerCrystal() {
        let spawnX = min(Self.msxWidth - Self.tileSizeF * 6, max(Self.tileSizeX4, playerX))
        spawnPickupOrb(id: 21, x: spawnX, y: 16)
    }

    func testShieldHit() {
        if shieldHits <= 0 {
            activateShield()
            RetroAudioSynthesizer.shared.playSfx(.crystal)
        } else {
            damageShield(force: 5)
        }
    }

    /// Spawns an interactive `[?]` block right above Popolon cycling through Rook, King, Knight, Queen.
    func spawnTestQuestionBlock() {
        let types: [MSXBlockType] = [.rook, .king, .knight, .queen]
        let chosen = types[testBlockCycleIndex % types.count]
        testBlockCycleIndex += 1

        let blockX = min(Self.msxWidth - Self.tileSizeX2, max(0, round(playerX / 8.0) * 8.0))
        let blockY = max(32, playerY - 56)

        let node = SKSpriteNode(texture: blockQuestionTexture, size: CGSize(width: 16, height: 16))
        node.zPosition = 6
        node.isHidden = false
        blocksLayerNode.addChild(node)

        let block = QuestionBlock(
            node: node,
            mapRow: max(0, currentRow + Int(blockY / 8.0)),
            mapCol: Int(blockX / 8.0),
            type: chosen,
            x: blockX,
            y: blockY
        )
        block.hits = 1
        block.isHidden = false
        questionBlocks.append(block)
        RetroAudioSynthesizer.shared.playSfx(.blockHit)
    }

    /// Spawns a test wave of classic Stage 1 enemies (`Bat`, `Knight`, `Skeleton`, `Cloud`, `Blue Demon`, `Death Ghost`)
    /// so the user can test enemy waves, active aiming, parting shots, and the Last Unit bonus at any moment.
    func spawnTestEnemyWave() {
        let sampleWaves: [(id: Int, count: Int)] = [
            (2, 3),  // Bat wave
            (4, 2),  // Knight squad (3 HP each + directional arrows)
            (7, 0),  // Skeleton (splits & reassembles + spinning bones)
            (5, 0),  // Cloud (turns into Tornado when shot)
            (6, 2),  // Blue Demon swoop wave
            (9, 2)   // Death Ghost wave (fires energy rays)
        ]
        let wave = sampleWaves[testWaveCycleIndex % sampleWaves.count]
        testWaveCycleIndex += 1
        let spawnX = min(Self.msxWidth - 32, max(24, playerX))
        spawnEnemyWaveFromMap(id: wave.id, x: spawnX, y: 16, extraCount: wave.count)
    }

    // MARK: - Frame Update Loop (Fixed 120 Hz MSX Engine Tick)

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let delta = min(0.1, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        guard !isGamePaused else { return }

        if playerState == .restartStage {
            restartWaitElapsed += delta
            if restartWaitElapsed >= 1.5 {
                if let gs = gameState, gs.lives <= 0 {
                    gs.triggerGameOver()
                } else {
                    calculateStartRow()
                    resetStageAttempt()
                }
            }
            return
        }

        accumulator += delta
        var steps = 0
        while accumulator >= Self.tickInterval && steps < 12 {
            engineTick()
            accumulator -= Self.tickInterval
            steps += 1
        }

        syncAllNodePositions()
    }

    private func engineTick() {
        clockMs += Self.tickMs
        tickCount += 1

        if freezeTimer < 0 && scrollOn && currentRow >= -1 && tickCount % 16 == 0 {
            scrollMap()
        }

        if playerState == .playing {
            processInput()
        } else if playerState == .movingToPortal {
            autoMovePlayerToPortal()
        }

        if tickCount % 6 == 0 {
            animTick += 1
            animatePlayer()
            animateShots()
            animateEnemyShots()
            animatePickups()
            animateEnemies()
            playerFiredSinceAnimTick = false
            animateBoss()
            animateFissures()
            if playerState == .stageClearWipe {
                updateStageClearWipe()
            }
        }

        moveShots()
        moveEnemyShots()
        movePickups()
        moveBoss()
        bossFireTick()

        if freezeTimer < 0 {
            moveEnemies()
            processSpawnQueue()
            if tickCount % 250 == 0 && currentRow < definition.enemyFireMaxRow {
                enemiesFire()
            }
        }

        updateCollisions()
        sweepFreeEntities()

        if powerUpTimer >= 0 {
            processPowerUpTimer()
        }
        if freezeTimer >= 0 {
            processFreezeTimer()
        }
    }

    // MARK: - Scrolling & Map Row Spawning (`MapSystem.cpp`)

    private func scrollMap() {
        guard scrollOn else { return }

        moveBlocksWithScroll()
        scrollBoss()
        checkScrollCollision()
        tilePx += 1

        if tilePx == Self.tileSize {
            tilePx = 0
            currentRow -= 1
            checkBossMapTriggers(row: currentRow)
            if currentRow >= 0 {
                spawnRowContent(row: currentRow)
            } else {
                currentRow = 0
                scrollOn = false
            }
            refreshMapTileTextures()
            gameState?.stageProgressRows = max(0, (StageMapData.mapRows0 - StageMapData.screenRows) - currentRow)
        }
    }

    private func spawnRowContent(row: Int) {
        guard row >= 0 && row < StageMapData.mapRows else { return }
        let topOffset = CGFloat(row - currentRow) * Self.tileSizeF

        for col in (0...StageMapData.mapCols0).reversed() {
            let objId = mapData.objectId(row: row, col: col)
            guard objId > 0 else { continue }
            let extra = mapData.objectExtra(row: row, col: col)

            if objId == 20 || objId == 21 {
                let spawnX = min(Self.msxWidth - Self.tileSizeF * 6, max(Self.tileSizeX4, playerX))
                spawnPickupOrb(id: objId, x: spawnX, y: max(0, topOffset))
            } else if objId == 22 {
                spawnBlockAt(row: row, col: col, y: topOffset)
            } else if objId >= 1 && objId <= 16 {
                let cfg = (gameState?.difficulty == .easy) ? min(3, extra) : extra
                spawnEnemyWaveFromMap(
                    id: objId,
                    x: CGFloat(col * Self.tileSize),
                    y: max(0, topOffset),
                    extraCount: cfg
                )
            }
        }
    }

    private func spawnBlocksInRow(row: Int) {
        guard row >= 0 && row < StageMapData.mapRows else { return }
        let topOffset = CGFloat(row - currentRow) * Self.tileSizeF
        for col in (0...StageMapData.mapCols0).reversed() {
            if mapData.objectId(row: row, col: col) == 22 {
                spawnBlockAt(row: row, col: col, y: topOffset)
            }
        }
    }

    private func spawnBlockAt(row: Int, col: Int, y: CGFloat) {
        let extra = mapData.objectExtra(row: row, col: col)
        let blockType = MSXBlockType(rawValue: extra) ?? .rook
        let bx = CGFloat(col * Self.tileSize)
        // Blocks live in sprite space (screen top = y - 16), so `+16` lines the sprite and its hitbox up
        // with the `?` map tile at `row` (`MapSystem::spawnBlock(row, col, extra, topOffset + TILE_SIZE_X2)`).
        let by = y + Self.tileSizeX2

        let node = SKSpriteNode(texture: blockQuestionTexture, size: CGSize(width: 16, height: 16))
        node.zPosition = 6
        node.isHidden = true
        blocksLayerNode.addChild(node)

        let block = QuestionBlock(
            node: node,
            mapRow: row,
            mapCol: col,
            type: blockType,
            x: bx,
            y: by
        )
        questionBlocks.append(block)
    }

    private func moveBlocksWithScroll() {
        for block in questionBlocks where !block.isFree {
            block.y += 1
            if block.y >= Self.msxHeight + Self.tileSizeX2 {
                block.isFree = true
            }
        }
        for bridge in bridgeSprites where !bridge.isFree {
            bridge.y += 1
            if bridge.y >= Self.msxHeight + Self.tileSizeX2 {
                bridge.isFree = true
            }
        }
    }

    private func spawnPickupOrb(id: Int, x: CGFloat, y: CGFloat) {
        let node = SKSpriteNode(color: .clear, size: CGSize(width: 16, height: 16))
        node.zPosition = 15
        pickupsLayerNode.addChild(node)

        let shadow = SKSpriteNode(texture: shadowTexture, size: CGSize(width: 16, height: 6))
        shadow.zPosition = 8
        shadowsLayerNode.addChild(shadow)

        let orb = PickupOrb(id: id, node: node, shadowNode: shadow, x: x, y: y)
        applyPickupTexture(orb)
        pickupOrbs.append(orb)
    }

    // MARK: - Terrain Collision

    /// Moves Popolon to the free ground closest to where he stands (same height first, then higher up), so a
    /// position change of the map (the HUD "BOSS" shortcut) never leaves him inside water or walls, where the
    /// scroll would push him off screen at once. A tile of clearance above is required, since the map scrolls down.
    func placePlayerOnSafeGround() {
        let isFree: (CGFloat, CGFloat) -> Bool = { x, y in
            !self.mapCollideForEnemy(px: x, py: y) && !self.mapCollideForEnemy(px: x, py: y - Self.tileSizeF)
        }
        guard !isFree(playerX, playerY) else { return }

        let minY = Self.tileSizeF * 6 // same top limit as player movement
        let maxX = Self.msxWidth - Self.tileSizeX2
        var y = playerY
        while y >= minY {
            for distance in stride(from: CGFloat(0), through: maxX, by: Self.tileSizeF) {
                for x in [playerX - distance, playerX + distance] where x >= 0 && x <= maxX && isFree(x, y) {
                    playerX = x
                    playerY = y
                    return
                }
            }
            y -= 1
        }
    }

    func mapCollideForEnemy(px: CGFloat, py: CGFloat) -> Bool {
        let classicYTop = py - Self.tileSizeX2
        let classicYBottom = classicYTop + Self.tileSizeX2 - 1

        let rowTop = currentRow + Int(floor((classicYTop - CGFloat(tilePx)) / Self.tileSizeF))
        let rowBottom = currentRow + Int(floor((classicYBottom - CGFloat(tilePx)) / Self.tileSizeF))

        let colLeft = Int(floor(px / Self.tileSizeF))
        let colRight = Int(floor((px + Self.tileSizeX2 - 1) / Self.tileSizeF))

        if rowTop > rowBottom || colLeft > colRight { return false }

        for r in rowTop...rowBottom {
            for c in colLeft...colRight {
                if mapData.isSolid(row: r, col: c) {
                    return true
                }
            }
        }
        return false
    }

    func mapCollide(px: CGFloat, py: CGFloat) -> Bool {
        if powerUpState == .invincible {
            return false
        }

        let classicYTop = py - Self.tileSizeX2
        let classicYBottom = classicYTop + Self.tileSizeX2 - 1

        let rowTop = currentRow + Int(floor((classicYTop - CGFloat(tilePx)) / Self.tileSizeF))
        let rowBottom = currentRow + Int(floor((classicYBottom - CGFloat(tilePx)) / Self.tileSizeF))

        let colLeft = Int(floor(px / Self.tileSizeF))
        let colRight = Int(floor((px + Self.tileSizeX2 - 1) / Self.tileSizeF))

        if rowTop > rowBottom || colLeft > colRight { return false }

        for r in rowTop...rowBottom {
            for c in colLeft...colRight {
                if mapData.isSolid(row: r, col: c) {
                    return true
                }
            }
        }
        return false
    }

    private func checkScrollCollision() {
        guard playerState == .playing else { return }
        if mapCollide(px: playerX, py: playerY) {
            playerY += 2
            if floor(playerY + Self.tileSizeF / 2.0) > Self.msxHeight {
                killPlayer()
            }
        }
    }

    // MARK: - Input & Movement (`ObjectSystem::processInput` and `movePlayer`)

    private var effectivePlayerSpeed: CGFloat {
        powerUpState == .invincible ? Self.playerMaxSpeed : playerSpeed
    }

    private func processInput() {
        guard playerState == .playing, let input = inputController else { return }
        playerIsMoving = false

        let fireHeld = input.isFireHeld
        if fireHeld {
            if !fireDownLastFrame || (clockMs - lastShotTimeMs >= playerWeapon.cooldownMs) {
                firePlayerShot()
            }
            fireDownLastFrame = true
        } else {
            fireDownLastFrame = false
        }

        let dt = CGFloat(Self.tickInterval)
        let speed = effectivePlayerSpeed

        if input.isLeft {
            let oldX = playerX
            playerX -= speed * dt
            if mapCollide(px: playerX, py: playerY) { playerX = oldX }
            if playerX < 0 { playerX = Self.msxWidth - Self.tileSizeX2 }
            playerIsMoving = true
            checkScrollCollision()
        } else if input.isRight {
            let oldX = playerX
            playerX += speed * dt
            if mapCollide(px: playerX, py: playerY) { playerX = oldX }
            if playerX > Self.msxWidth - Self.tileSizeX2 { playerX = 0 }
            playerIsMoving = true
            checkScrollCollision()
        }

        if input.isUp {
            let oldY = playerY
            playerY -= speed * dt
            if mapCollide(px: playerX, py: playerY) { playerY = oldY }
            let minY = Self.tileSizeF * 6
            if playerY < minY { playerY = minY }
            playerIsMoving = true
            checkScrollCollision()
        } else if input.isDown {
            let oldY = playerY
            playerY += speed * dt
            if mapCollide(px: playerX, py: playerY) { playerY = oldY }
            let maxY = Self.msxHeight
            if playerY > maxY { playerY = maxY }
            playerIsMoving = true
            checkScrollCollision()
        }
    }

    // MARK: - Weapon Firing, Movement & Animation

    private func firePlayerShot() {
        guard powerUpState != .invincible else { return }
        guard clockMs - lastShotTimeMs >= playerWeapon.cooldownMs else { return }

        if playerWeapon == .boomerang || playerWeapon == .superBoomerang {
            let maxBoomerangs = (playerWeapon == .superBoomerang) ? 3 : 2
            let inFlight = playerShots.filter {
                !$0.isFree && ($0.weapon == .boomerang || $0.weapon == .superBoomerang)
            }.count
            if inFlight >= maxBoomerangs { return }
        }

        let tileId = playerWeapon.baseTileId
        guard let rect = MSXObjectTiles.shotTiles[tileId] else { return }
        playerFiredSinceAnimTick = true

        var shotsCount = (playerWeapon.rawValue > 6) ? 2 : 1
        var speedX: CGFloat = 0
        var speedY: CGFloat = -220.0
        var sfx: RetroAudioSynthesizer.SoundEffect = .shot

        var spawnX = playerX + (Self.tileSizeF - CGFloat(rect.w) / 2.0)
        let spawnY = playerY - CGFloat(rect.h) - 1

        switch playerWeapon {
        case .arrow, .twinArrow, .superTwinArrow:
            sfx = .shot
        case .flame, .superFlame:
            shotsCount = 2
            spawnX -= Self.tileSizeX2
            speedY = -200.0
            sfx = .shotFlame
        case .boomerang, .superBoomerang:
            sfx = .shotBoomerang
        case .sword, .doubleSword:
            shotsCount = 2
            sfx = .shotSword
        case .fireArrow, .superFireArrow:
            sfx = .shotFireArrow
        }

        for i in 0...shotsCount {
            var yOffset: CGFloat = 0

            if playerWeapon == .flame || playerWeapon == .superFlame {
                if i > 0 { spawnX += Self.tileSizeX2 }
                if i == 1 { yOffset = Self.tileSizeF }
                if playerWeapon == .flame {
                    speedX = 50.0 * CGFloat(i) - 50.0
                }
            }

            let node = SKSpriteNode(
                texture: shotTextureCache[tileId],
                size: CGSize(width: rect.w, height: rect.h)
            )
            node.zPosition = 18
            shotsLayerNode.addChild(node)

            let shot = PlayerShot(
                node: node,
                weapon: playerWeapon,
                tileId: tileId,
                x: spawnX,
                y: spawnY - yOffset,
                speedX: speedX,
                speedY: speedY
            )
            playerShots.append(shot)

            RetroAudioSynthesizer.shared.playSfx(sfx, volume: 0.65)
            lastShotTimeMs = clockMs

            if playerWeapon != .flame && playerWeapon != .superFlame {
                break
            }
        }
    }

    private func moveShots() {
        let dt = CGFloat(Self.tickInterval)
        for shot in playerShots where !shot.isFree {
            let currentSpeedX: CGFloat
            let currentSpeedY: CGFloat

            if shot.weapon == .boomerang || shot.weapon == .superBoomerang {
                shot.x = playerX
                shot.speedY += 2.5
                currentSpeedX = 0
                currentSpeedY = shot.speedY
            } else {
                currentSpeedX = shot.speedX
                currentSpeedY = shot.speedY
            }

            shot.x += currentSpeedX * dt
            shot.y += currentSpeedY * dt

            if shot.weapon == .boomerang || shot.weapon == .superBoomerang {
                if shot.y < 0 { shot.y = 0 }
            }

            if shot.y < 0 || shot.y > Self.msxHeight + Self.tileSizeX2 || shot.x < 0 || shot.x > Self.msxWidth {
                shot.isFree = true
            }
        }
    }

    private func animateShots() {
        for shot in playerShots where !shot.isFree {
            guard shot.weapon == .boomerang || shot.weapon == .superBoomerang else { continue }
            shot.animStep += 1
            let m = shot.animStep % 12
            let newTileId: Int
            let newRot: Int
            if m == 9 {
                newRot = 3; newTileId = 44
            } else if m == 6 {
                newRot = 3; newTileId = 43
            } else if m == 3 {
                newRot = 0; newTileId = 44
            } else if m == 0 {
                newRot = 0; newTileId = 43
            } else {
                continue
            }
            shot.tileId = newTileId
            shot.rotQuarterTurns = newRot
            if let rect = MSXObjectTiles.shotTiles[newTileId] {
                shot.node.texture = shotTextureCache[newTileId]
                shot.node.size = CGSize(width: rect.w, height: rect.h)
                shot.node.zRotation = -CGFloat(newRot) * (.pi / 2.0)
            }
        }
    }

    // MARK: - Pickup Orbs Movement

    private func movePickups() {
        let dt = CGFloat(Self.tickInterval)
        for orb in pickupOrbs where !orb.isFree {
            if orb.gpr3 >= 0 {
                orb.renderOffsetX = floor(-Self.tileSizeX4 * sin(orb.gpr3 * .pi / 180.0))
                orb.gpr3 += 180.0 * dt
            } else {
                orb.renderOffsetX = 0
            }
            orb.y += 12.0 * dt

            if orb.y > Self.msxHeight + Self.tileSizeF {
                orb.isFree = true
            }
        }
    }

    private func animatePickups() {
        for orb in pickupOrbs where !orb.isFree {
            if orb.id == 20 {
                applyPickupTexture(orb)
                orb.gpr1 = (orb.gpr1 >= MSXObjectTiles.weaponAnim.count - 1) ? 0 : orb.gpr1 + 1
            } else if orb.id == 21 {
                if animTick % 2 == 0 {
                    applyPickupTexture(orb)
                    orb.gpr1 = (orb.gpr1 >= MSXObjectTiles.pupAnim.count - 1) ? 0 : orb.gpr1 + 1
                }
            }
        }
    }

    private func applyPickupTexture(_ orb: PickupOrb) {
        let sheets = SpriteSheetManager.shared
        if orb.id == 20 {
            let row = min(max(0, orb.gpr1), MSXObjectTiles.weaponAnim.count - 1)
            let col = min(max(0, orb.gpr2 - 2), MSXObjectTiles.weaponAnim[row].count - 1)
            let frameIndex = MSXObjectTiles.weaponAnim[row][col]
            orb.node.texture = sheets.texture(from: .objects, x: frameIndex * 16, y: 64, width: 16, height: 16)
        } else {
            let row = min(max(0, orb.gpr1), MSXObjectTiles.pupAnim.count - 1)
            let col = min(max(0, orb.gpr2 - 2), MSXObjectTiles.pupAnim[row].count - 1)
            let frameIndex = MSXObjectTiles.pupAnim[row][col]
            orb.node.texture = sheets.texture(from: .objects, x: frameIndex * 16, y: 80, width: 16, height: 16)
        }
    }

    // MARK: - Collisions (`CollisionSystem.cpp` & `MapSystem.cpp`)

    private func updateCollisions() {
        guard playerState == .playing else { return }

        // 1. Player shots vs `?` Blocks, Pickup Orbs, Enemies, and Skeleton Bones
        for shot in playerShots where !shot.isFree {
            let sRect = shotBox(shot)
            var shotConsumed = false

            // 1a. Check `?` Blocks first (`CollisionSystem::update`)
            for block in questionBlocks where !block.isFree {
                let bRect = CGRect(x: block.x, y: block.y, width: 16, height: 16)
                if sRect.intersects(bRect) {
                    if hitQuestionBlock(block) {
                        shotConsumed = true
                        break
                    }
                }
            }
            if shotConsumed {
                shot.isFree = true
                continue
            }

            // 1b. Check Pickup Orbs
            for orb in pickupOrbs where !orb.isFree {
                let oRect = CGRect(x: orb.x + orb.renderOffsetX, y: orb.y, width: 16, height: 16)
                if sRect.intersects(oRect) {
                    let modulo = (orb.id == 20) ? 8 : 7
                    orb.gpr2 = (orb.gpr2 + 1) % modulo
                    if orb.gpr2 > 3 && orb.gpr3 < 0 {
                        orb.gpr3 = 0
                    }
                    applyPickupTexture(orb)
                    RetroAudioSynthesizer.shared.playSfx(.powerUpHit)
                    shotConsumed = true
                    break
                }
            }
            if shotConsumed {
                shot.isFree = true
                continue
            }

            // 1c. Check the stage boss (`BossSystem::hitBoss`; a shielded boss still absorbs the shot)
            if boss.status == .active && bossAbsorbsShot(sRect) {
                shot.isFree = true
                continue
            }

            // 1d. Check Enemies (`1...16`)
            let enemyCount = enemies.count
            for idx in 0..<enemyCount {
                let enemy = enemies[idx]
                guard !enemy.isFree && enemy.id < 20 && !enemy.node.isHidden else { continue }
                if sRect.intersects(enemyBox(enemy)) {
                    let didHit = hitEnemyObject(enemy, instantKill: false)
                    if didHit && !shot.weapon.isSuperWeapon {
                        shotConsumed = true
                        break
                    }
                }
            }
            if shotConsumed {
                shot.isFree = true
                continue
            }

            // 1e. Check Destructible Enemy Projectiles (Skeleton Bones `25...27` & Scythe `33`, `CollisionSystem::hitShot`)
            for eShot in enemyShots where !eShot.isFree && ((25...27).contains(eShot.weaponId) || eShot.weaponId == 33) {
                if sRect.intersects(enemyShotBox(eShot)) {
                    spawnEnemyObject(
                        id: 34,
                        x: eShot.x,
                        y: eShot.y,
                        objCfg: 0,
                        waveGroupId: 0,
                        enqueueRemaining: false
                    )
                    RetroAudioSynthesizer.shared.playSfx(.enemyKill)
                    eShot.isFree = true
                    if !shot.weapon.isSuperWeapon {
                        shotConsumed = true
                        break
                    }
                }
            }
            if shotConsumed {
                shot.isFree = true
                continue
            }
        }

        // 2. Popolon vs open Chess Piece blocks (`MapSystem::collectBlockBonus`)
        let playerRect = CGRect(x: playerX, y: playerY, width: 16, height: 16)
        for block in questionBlocks where !block.isFree && !block.isHidden {
            let bRect = CGRect(x: block.x, y: block.y, width: 16, height: 16)
            if playerRect.intersects(bRect) {
                collectBlockBonus(block)
            }
        }

        // 3. Popolon catching returning Boomerang
        if playerWeapon == .boomerang || playerWeapon == .superBoomerang {
            for shot in playerShots where !shot.isFree {
                if (shot.weapon == .boomerang || shot.weapon == .superBoomerang) && shot.speedY > 0 {
                    if playerRect.intersects(shotBox(shot)) {
                        shot.isFree = true
                    }
                }
            }
        }

        // 4. Enemy Shots vs Frontal Shield & Popolon
        let shieldRect = CGRect(x: playerX, y: playerY - Self.tileSizeF, width: 16, height: 7)
        let playerHitbox = playerRect.insetBy(dx: 3, dy: 3)

        for eShot in enemyShots where !eShot.isFree {
            let esRect = enemyShotBox(eShot)
            // Landed ground fire (`35`) slips past the shield (`hitShield`: a stopped `28` is not absorbed)
            if shieldHits > 0 && eShot.weaponId != 35 && powerUpState != .invincible && powerUpState != .transparent && esRect.intersects(shieldRect) {
                let force = (eShot.weaponId == 23 || (25...27).contains(eShot.weaponId)) ? 1 : 3
                damageShield(force: force)
                eShot.isFree = true
                continue
            }
            if powerUpState != .invincible && powerUpState != .transparent && esRect.intersects(playerHitbox) {
                eShot.isFree = true
                killPlayer()
                return
            }
        }

        // 5. Popolon vs Pickup Orbs & Enemy Bodies (`CollisionSystem::circleOverlap`)
        let pcx = playerX + 8.0
        let pcy = playerY + 8.0
        for orb in pickupOrbs where !orb.isFree {
            let ocx = orb.x + orb.renderOffsetX + 8.0
            let ocy = orb.y + 8.0
            if hypot(pcx - ocx, pcy - ocy) < 16.0 {
                collectPickupOrb(orb)
                orb.isFree = true
            }
        }

        let currentEnemiesCount = enemies.count
        for idx in 0..<currentEnemiesCount {
            let enemy = enemies[idx]
            guard !enemy.isFree && enemy.id < 20 && !enemy.node.isHidden else { continue }
            let eBox = enemyBox(enemy)
            let ecx = eBox.midX
            let ecy = eBox.midY
            if hypot(pcx - ecx, pcy - ecy) < 12.0 {
                if powerUpState == .invincible {
                    _ = hitEnemyObject(enemy, instantKill: true)
                } else if powerUpState != .transparent {
                    killPlayer()
                    return
                }
            }
        }

        // 6. Popolon vs ground fissures (Stage 6 boss): deadly along their whole visible length; the invincible
        //    aura closes them instead (`playerHitObj` → `hitObject(o, true, true)` destroys object 49)
        if playerState == .playing && powerUpState != .transparent {
            for fissure in fissures where !fissure.isFree {
                let rect = CGRect(x: fissure.x, y: fissure.y, width: 16, height: fissure.length)
                guard playerHitbox.intersects(rect) else { continue }
                if powerUpState == .invincible {
                    fissure.isFree = true
                } else {
                    killPlayer()
                    return
                }
            }
        }

        // 7. Popolon vs the stage boss body
        if boss.status == .active && powerUpState != .invincible && powerUpState != .transparent {
            if playerHitbox.intersects(bossBodyRect()) {
                killPlayer()
                return
            }
        }
    }

    /// Implements `CollisionSystem::hitBlock` and `MapSystem::replaceBlock`.
    private func hitQuestionBlock(_ block: QuestionBlock) -> Bool {
        let maxHits = block.type.maxHits
        if block.type == .collected || block.hits >= maxHits {
            return false
        }

        block.hits += 1
        if block.hits < maxHits {
            RetroAudioSynthesizer.shared.playSfx(.blockHit)
        } else if block.hits == maxHits {
            RetroAudioSynthesizer.shared.playSfx(.blockOpen)
        }

        if block.hits == 1 || block.hits == maxHits {
            replaceQuestionBlockAppearance(block)
        }
        return true
    }

    private func replaceQuestionBlockAppearance(_ block: QuestionBlock) {
        let maxHits = block.type.maxHits
        if block.type == .bridge {
            if block.hits >= maxHits {
                block.type = .collected
                block.isHidden = true
                block.node.isHidden = true
                openRiverBridge(block: block)
            } else {
                // First hit reveals the `?` so a secret bridge block over water shows it was found
                block.isHidden = false
                block.node.isHidden = false
                block.node.texture = blockQuestionTexture
            }
        } else if block.hits < maxHits {
            block.isHidden = false
            block.node.isHidden = false
            block.node.texture = blockQuestionTexture
        } else if block.hits == maxHits {
            block.isHidden = false
            block.node.isHidden = false
            block.node.texture = chessPieceTextureCache[block.type] ?? blockQuestionTexture
            if block.type == .barrier {
                mapData.makeBlockSolid(row: block.mapRow, col: block.mapCol)
            }
        }
    }

    private func openRiverBridge(block: QuestionBlock) {
        // Clears the `4×4` water solidity (rows `mapRow - 2 ... mapRow + 1`, cols `mapCol - 1 ... mapCol + 2`) and
        // stacks four bridge planks (`t[48] = {184, 136, 32, 8}`) over it, matching the map's prebuilt bridges.
        // (The reference draws a single plank on the block row, leaving three rows of walkable "water".)
        for rowOffset in -2...1 {
            let node = SKSpriteNode(texture: bridgeSpriteTexture, size: CGSize(width: 32, height: 8))
            node.zPosition = 5
            blocksLayerNode.addChild(node)
            bridgeSprites.append(BridgeSprite(
                node: node,
                x: block.x - Self.tileSizeF,
                y: block.y + CGFloat(rowOffset) * Self.tileSizeF
            ))
        }

        mapData.makeBridgeGround(row: block.mapRow + 1, col: block.mapCol - 1, down: false)
        refreshMapTileTextures()
        RetroAudioSynthesizer.shared.playSfx(.terrain)
    }

    /// Implements `MapSystem::collectBlockBonus` when Popolon walks over an exposed Chess Piece.
    private func collectBlockBonus(_ block: QuestionBlock) {
        let maxHits = block.type.maxHits
        guard block.hits == maxHits && block.type != .collected && block.type != .barrier else { return }

        switch block.type {
        case .rook:
            gameState?.incrementScore(500)
            RetroAudioSynthesizer.shared.playSfx(.points)

        case .king:
            scrollOn = false
            freezeTimer = Self.freezeDuration
            RetroAudioSynthesizer.shared.playSfx(.freezeTick)
            syncHudState()

        case .knight:
            killAllActiveEnemies()
            RetroAudioSynthesizer.shared.playSfx(.killAllEnemies)

        case .queen:
            gameState?.lives += 1
            RetroAudioSynthesizer.shared.playSfx(.newLife)

        case .barrier, .bridge, .collected:
            break
        }

        // Keep showing the plain "collected" block so the `?` map tile underneath stays covered
        // (`MapSystem::replaceBlock` with `offset = TILE_SIZE_X2 * COLLECTED`).
        block.type = .collected
        block.node.texture = chessPieceTextureCache[.collected]
    }

    func killAllActiveEnemies(playSfx: Bool = true) {
        let count = enemies.count
        for idx in 0..<count {
            let e = enemies[idx]
            if !e.isFree && e.id < 20 {
                killEnemyObject(e, playSfx: playSfx)
            }
        }
        for eShot in enemyShots where !eShot.isFree {
            eShot.isFree = true
        }
        if playSfx {
            flashOverlayNode.removeAllActions()
            flashOverlayNode.color = .white
            flashOverlayNode.alpha = 0.85
            flashOverlayNode.run(.fadeOut(withDuration: 0.35))
        }
    }

    private func shotBox(_ shot: PlayerShot) -> CGRect {
        let rect = MSXObjectTiles.shotTiles[shot.tileId] ?? MSXObjectTiles.TileRect(x: 0, y: 0, w: 5, h: 13)
        return CGRect(x: shot.x, y: shot.y, width: CGFloat(rect.w), height: CGFloat(rect.h))
    }

    /// Implements `PowerUpSystem::changeWeapon` and `PowerUpSystem::powerUp`.
    private func collectPickupOrb(_ orb: PickupOrb) {
        let variant = orb.gpr2
        if orb.id == 20 {
            if variant <= 2 {
                gameState?.incrementScore(1000)
                RetroAudioSynthesizer.shared.playSfx(.points)
            } else {
                gameState?.incrementScore(200)
                RetroAudioSynthesizer.shared.playSfx(.crystal)
                let baseWeaponRaw = variant - 1
                if baseWeaponRaw == 5 {
                    increasePlayerSpeed()
                }
                let upgradedRaw: Int
                if playerWeapon.rawValue == baseWeaponRaw || playerWeapon.rawValue == baseWeaponRaw + 5 {
                    upgradedRaw = baseWeaponRaw + 5
                } else {
                    upgradedRaw = baseWeaponRaw
                }
                if let newW = MSXWeapon(rawValue: upgradedRaw) {
                    playerWeapon = newW
                }
            }
        } else if orb.id == 21 {
            if variant <= 2 {
                gameState?.incrementScore(1000)
                RetroAudioSynthesizer.shared.playSfx(.points)
                syncHudState()
                return
            }
            switch variant {
            case 3:
                increasePlayerSpeed()
            case 4:
                activateShield()
            case 5:
                powerUpState = .transparent
                powerUpTimer = Self.powerUpDuration
            case 6:
                powerUpState = .invincible
                powerUpTimer = Self.powerUpDuration
            default:
                break
            }
            gameState?.incrementScore(200)
            RetroAudioSynthesizer.shared.playSfx(.crystal)
        }
        updateShieldAppearance()
        syncHudState()
    }

    private func increasePlayerSpeed() {
        if playerSpeed < Self.playerMaxSpeed {
            playerSpeed = min(Self.playerMaxSpeed, playerSpeed + Self.playerSpeedInc)
        }
    }

    // MARK: - Shield, Aura & Freeze Timers

    private func activateShield() {
        shieldHits = Self.shieldMaxHits
        if powerUpState == .none {
            powerUpState = .shield
        }
        updateShieldAppearance()
        syncHudState()
    }

    func damageShield(force: Int = 1) {
        guard shieldHits > 0 else { return }
        shieldHits = max(0, shieldHits - force)
        RetroAudioSynthesizer.shared.playSfx(.shield)
        if shieldHits == 0 && powerUpState == .shield {
            powerUpState = .none
        }
        updateShieldAppearance()
        syncHudState()
    }

    func updateShieldAppearance() {
        guard shieldHits > 0 && playerState == .playing && powerUpState != .invincible && powerUpState != .transparent else {
            shieldSpriteNode.isHidden = true
            return
        }
        shieldSpriteNode.isHidden = false
        let colorIndex: Int
        if shieldHits > 10 {
            colorIndex = 0
        } else if shieldHits > 5 {
            colorIndex = 1
        } else {
            colorIndex = 2
        }
        shieldSpriteNode.texture = shieldTextureCache[colorIndex]
    }

    private func processPowerUpTimer() {
        let prevWhole = Int(ceil(powerUpTimer))
        powerUpTimer -= 0.025
        let newWhole = Int(ceil(powerUpTimer))
        if powerUpTimer > 0 && powerUpTimer < 11 && newWhole != prevWhole {
            RetroAudioSynthesizer.shared.playSfx(.powerUpEnding)
        }
        if powerUpTimer < 0 {
            powerUpTimer = -1
            powerUpState = (shieldHits > 0) ? .shield : .none
            updateShieldAppearance()
        }
        syncHudState()
    }

    /// Implements `Engine::processFreezeTimer` for the King Chess Piece (`Block::FREEZE`).
    private func processFreezeTimer() {
        let before = floor(freezeTimer * 2.0)
        freezeTimer -= 0.025
        if floor(freezeTimer * 2.0) != before {
            RetroAudioSynthesizer.shared.playSfx(.freezeTick, volume: 0.55)
        }
        if freezeTimer < 0 {
            freezeTimer = -1
            scrollOn = (currentRow > 0)
        }
        syncHudState()
    }

    // MARK: - Animation & Player Death

    private func animatePlayer() {
        if playerState == .dead {
            let maxIdx = Self.playerDeathAnim.count - 1
            let idx = min(Int(playerAnimCounter), maxIdx)
            playerAnimOffsetX = Self.playerDeathAnim[idx] * Self.tileSize
            playerAnimCounter += 0.5
            if playerAnimCounter > CGFloat(maxIdx) * 1.5 {
                playerState = .restartStage
                restartWaitElapsed = 0
            }
        } else {
            let step: CGFloat = playerIsMoving ? (2.0 + effectivePlayerSpeed / Self.playerInitSpeed) : 1.0
            playerAnimCounter += step
            var offset = 0
            if powerUpState == .invincible || powerUpState == .transparent {
                if powerUpTimer > 10 || (powerUpTimer - floor(powerUpTimer)) > 0.5 {
                    offset = Int(Self.tileSizeX2) * powerUpState.rawValue
                }
            }
            playerAnimOffsetX = offset
        }
        updatePlayerTexture()
        updateShieldAppearance()
    }

    private func killPlayer() {
        guard playerState == .playing else { return }
        guard powerUpState != .invincible && powerUpState != .transparent else { return }
        scrollOn = false
        playerState = .dead
        playerAnimCounter = 0
        playerWeapon = .arrow
        playerSpeed = Self.playerInitSpeed
        powerUpState = .none
        powerUpTimer = -1
        freezeTimer = -1
        shieldHits = 0
        updateShieldAppearance()
        if let gs = gameState {
            gs.lives = max(0, gs.lives - 1)
        }
        syncHudState()
        RetroAudioSynthesizer.shared.playPlayerDeath()
    }

    private func updatePlayerTexture() {
        let leftLeg = (playerState != .dead) && (Int(playerAnimCounter) % 10 < 5)
        let baseX = leftLeg ? 0 : 16
        let tx = baseX + playerAnimOffsetX
        if let tex = SpriteSheetManager.shared.texture(from: .objects, x: tx, y: 0, width: 16, height: 16) {
            playerSpriteNode.texture = tex
        }
    }

    func syncHudState() {
        guard let gs = gameState else { return }
        gs.currentWeaponName = playerWeapon.displayName
        gs.speedLevel = playerSpeedLevel
        gs.shieldHits = shieldHits
        if powerUpState == .invincible || powerUpState == .transparent {
            gs.activeAuraName = powerUpState.displayName
            gs.auraRemainingSeconds = max(0, Int(ceil(powerUpTimer / 3.0)))
        } else {
            gs.activeAuraName = ""
            gs.auraRemainingSeconds = 0
        }
        gs.freezeRemainingSeconds = freezeTimer >= 0 ? max(1, Int(ceil(freezeTimer / 3.0))) : 0
        gs.activeEnemiesCount = enemies.filter { !$0.isFree && $0.id < 20 }.count
        if boss.status == .active || boss.status == .waiting {
            gs.bossHp = boss.hp
            gs.bossMaxHp = boss.maxHp
        } else {
            gs.bossHp = 0
            gs.bossMaxHp = 0
        }
    }

    // MARK: - Entity Cleanup & Node Sync

    private func sweepFreeEntities() {
        playerShots.removeAll { shot in
            if shot.isFree {
                shot.node.removeFromParent()
                return true
            }
            return false
        }
        enemyShots.removeAll { eShot in
            if eShot.isFree {
                eShot.node.removeFromParent()
                return true
            }
            return false
        }
        fissures.removeAll { fissure in
            if fissure.isFree {
                fissure.node.removeFromParent()
                return true
            }
            return false
        }
        enemies.removeAll { enemy in
            if enemy.isFree {
                enemy.node.removeFromParent()
                enemy.shadowNode?.removeFromParent()
                return true
            }
            return false
        }
        pickupOrbs.removeAll { orb in
            if orb.isFree {
                orb.node.removeFromParent()
                orb.shadowNode.removeFromParent()
                return true
            }
            return false
        }
        questionBlocks.removeAll { block in
            if block.isFree {
                block.node.removeFromParent()
                return true
            }
            return false
        }
        bridgeSprites.removeAll { bridge in
            if bridge.isFree {
                bridge.node.removeFromParent()
                return true
            }
            return false
        }
        gameState?.activeEnemiesCount = enemies.filter { !$0.isFree && $0.id < 20 }.count
    }

    func refreshMapTileTextures() {
        for (rowIdx, rOffset) in visibleRowOffsets.enumerated() {
            let mapRow = currentRow + rOffset
            for col in 0..<Self.screenCols {
                let node = tileGridNodes[rowIdx][col]
                if mapRow >= 0 && mapRow < StageMapData.mapRows {
                    let tId = mapData.tileId(row: mapRow, col: col)
                    node.texture = mapTileTextureCache[tId]
                    node.isHidden = false
                } else {
                    node.isHidden = true
                }
            }
        }
    }

    func syncAllNodePositions() {
        mapLayerNode.position = CGPoint(x: 0, y: -CGFloat(tilePx))

        if let bossNode = boss.node, boss.status != .notSpawned {
            let bossTopY = boss.y - Self.tileSizeX2
            bossNode.position = Self.scenePosition(
                msxX: boss.x,
                msxTopY: bossTopY,
                width: bossFrameSize.width,
                height: bossFrameSize.height
            )
        }

        if let shadowNode = boss.shadowNode, boss.status != .notSpawned {
            let shadowY = boss.shadowFixedY ?? (boss.y + boss.shadowOffset.y)
            shadowNode.position = Self.scenePosition(
                msxX: boss.x + boss.shadowOffset.x,
                msxTopY: shadowY - Self.tileSizeX2,
                width: shadowNode.size.width,
                height: shadowNode.size.height
            )
        }

        let playerScreenTopY = playerY - Self.tileSizeX2
        playerSpriteNode.position = Self.scenePosition(
            msxX: playerX,
            msxTopY: playerScreenTopY,
            width: 16,
            height: 16
        )

        if !shieldSpriteNode.isHidden {
            let shieldTopY = (playerY - Self.tileSizeF) - Self.tileSizeX2
            shieldSpriteNode.position = Self.scenePosition(
                msxX: playerX,
                msxTopY: shieldTopY,
                width: 16,
                height: 7
            )
        }

        for block in questionBlocks where !block.isFree && !block.isHidden {
            let blockTopY = block.y - Self.tileSizeX2
            block.node.position = Self.scenePosition(
                msxX: block.x,
                msxTopY: blockTopY,
                width: 16,
                height: 16
            )
        }

        for bridge in bridgeSprites where !bridge.isFree {
            let bridgeTopY = bridge.y - Self.tileSizeX2
            bridge.node.position = Self.scenePosition(
                msxX: bridge.x,
                msxTopY: bridgeTopY,
                width: 32,
                height: 8
            )
        }

        for shot in playerShots where !shot.isFree {
            let shotTopY = shot.y - Self.tileSizeX2
            shot.node.position = Self.scenePosition(
                msxX: shot.x,
                msxTopY: shotTopY,
                width: shot.node.size.width,
                height: shot.node.size.height
            )
        }

        for eShot in enemyShots where !eShot.isFree {
            let shotTopY = eShot.y - Self.tileSizeX2
            eShot.node.position = Self.scenePosition(
                msxX: eShot.x,
                msxTopY: shotTopY,
                width: eShot.node.size.width,
                height: eShot.node.size.height
            )
        }

        for enemy in enemies where !enemy.isFree {
            let drawX = enemy.x + enemy.renderOffsetX
            let drawY = enemy.y + enemy.renderOffsetY
            let topY = drawY - Self.tileSizeX2
            let w = enemy.node.size.width
            let h = enemy.node.size.height
            enemy.node.xScale = enemy.flipX ? -1.0 : 1.0
            enemy.node.yScale = enemy.flipY ? -1.0 : 1.0
            enemy.node.position = Self.scenePosition(
                msxX: drawX,
                msxTopY: topY,
                width: w,
                height: h
            )
            if let shadow = enemy.shadowNode {
                shadow.position = Self.scenePosition(
                    msxX: drawX,
                    msxTopY: topY + 20,
                    width: 16,
                    height: 6
                )
            }
        }

        for orb in pickupOrbs where !orb.isFree {
            let orbTopY = orb.y - Self.tileSizeX2
            let drawX = orb.x + orb.renderOffsetX
            orb.node.position = Self.scenePosition(
                msxX: drawX,
                msxTopY: orbTopY,
                width: 16,
                height: 16
            )
            orb.shadowNode.position = Self.scenePosition(
                msxX: drawX,
                msxTopY: orbTopY + 20,
                width: 16,
                height: 6
            )
        }
    }

    // MARK: - Stage Exit Door & Closing Window

    /// Hides Popolon above the bottom edge of the castle wall (map rows `0...2`), so walking up into the
    /// doorway notch makes him disappear inside the castle instead of being drawn over the bricks.
    func clipPlayerBelowCastleWall() {
        let wallBottomY = CGFloat((3 - currentRow) * Self.tileSize + tilePx)
        let visibleHeight = max(0, Self.msxHeight - wallBottomY)
        let mask = SKSpriteNode(color: .white, size: CGSize(width: Self.msxWidth, height: visibleHeight))
        mask.position = CGPoint(x: Self.msxWidth / 2.0, y: visibleHeight / 2.0)
        playerClipNode.maskNode = mask
    }

    /// Paints black everywhere except the `(left, top, width, height)` window, in MSX top-left coordinates.
    func showExitWindow(left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) {
        let bands = [
            CGRect(x: 0, y: 0, width: Self.msxWidth, height: top),
            CGRect(x: 0, y: top + height, width: Self.msxWidth, height: Self.msxHeight - top - height),
            CGRect(x: 0, y: top, width: left, height: height),
            CGRect(x: left + width, y: top, width: Self.msxWidth - left - width, height: height)
        ]
        for (node, band) in zip(exitWindowNodes, bands) {
            node.isHidden = band.width <= 0 || band.height <= 0
            node.size = CGSize(width: max(0, band.width), height: max(0, band.height))
            node.position = Self.scenePosition(msxX: band.minX, msxTopY: band.minY, width: band.width, height: band.height)
        }
    }

    func hideExitWindow() {
        for node in exitWindowNodes { node.isHidden = true }
    }

    static func scenePosition(msxX: CGFloat, msxTopY: CGFloat, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(
            x: msxX + width / 2.0,
            y: msxHeight - (msxTopY + height / 2.0)
        )
    }
}
