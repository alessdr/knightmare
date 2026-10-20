import SpriteKit

/// Ending cutscene after the Stage 8 boss: the reference's "stage 9" (`stage9.map`, `ObjectSystem` object 51).
/// On the castle's inner hall, Aphrodite steps out of the gate and walks down to the centre, Popolon walks up to
/// meet her, and the screen closes toward its centre (`fadeMap`). Coordinates follow the MSX screen (top-left
/// origin, 256×176); sprites use the game's sprite space (`y` = screen top + 16).
@MainActor
final class EndingScene: SKScene {
    enum Phase: Equatable {
        case message // "YOU HAVE BEATEN ALL DEMONS !" over the still scene (4 s in the reference)
        case princessDescends
        case popolonWalks
        case pause
        case closing
        case finished
    }

    private static let screenWidth: CGFloat = 256
    private static let screenHeight: CGFloat = 176
    private static let walkSpeed: CGFloat = 30 // px/s, for both characters
    private static let princessStopY: CGFloat = 80 // sprite space (`SCREEN_CENTER_H - TILE_SIZE`)
    private static let popolonStopY: CGFloat = 107 // sprite space (`SCREEN_CENTER_H + TILE_SIZE_X2 + 3`)

    private(set) var phase: Phase = .message
    var onPhaseChange: ((Phase) -> Void)?

    private let princessNode = SKSpriteNode()
    private let popolonNode = SKSpriteNode()
    private let windowNodes: [SKSpriteNode] = (0..<4).map { _ in SKSpriteNode(color: .black, size: .zero) }

    private var princessY: CGFloat = 0
    private var popolonY: CGFloat = 168
    private var lastUpdateTime: TimeInterval = 0
    private var phaseElapsed: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = .zero
        removeAllChildren()
        buildMap()

        let sheets = SpriteSheetManager.shared
        princessNode.texture = sheets.texture(from: .objects, x: 0, y: 136, width: 16, height: 24)
        princessNode.size = CGSize(width: 16, height: 24)
        princessNode.zPosition = 10
        addChild(princessNode)

        popolonNode.size = CGSize(width: 16, height: 16)
        popolonNode.zPosition = 10
        addChild(popolonNode)
        setPopolonFrame(rightLeg: false)

        for node in windowNodes {
            node.zPosition = 50
            node.isHidden = true
            addChild(node)
        }
        layoutCharacters()
    }

    /// Ends the message pause and starts the cutscene proper.
    func startCutscene() {
        guard phase == .message else { return }
        setPhase(.princessDescends)
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(0.1, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        phaseElapsed += dt

        switch phase {
        case .message, .finished:
            break
        case .princessDescends:
            princessY = min(Self.princessStopY, princessY + Self.walkSpeed * CGFloat(dt))
            if princessY >= Self.princessStopY { setPhase(.popolonWalks) }
        case .popolonWalks:
            popolonY = max(Self.popolonStopY, popolonY - Self.walkSpeed * CGFloat(dt))
            setPopolonFrame(rightLeg: Int(phaseElapsed / 0.25) % 2 == 1)
            if popolonY <= Self.popolonStopY {
                setPopolonFrame(rightLeg: false)
                setPhase(.pause)
            }
        case .pause:
            // The reference waits 11 animation ticks before the screen starts closing
            if phaseElapsed >= 0.55 { setPhase(.closing) }
        case .closing:
            // Same closing window as the stage exit door: 2.2 s to fully black, then a short hold
            let progress = CGFloat(min(1.0, phaseElapsed / 2.2))
            let insetX = Self.screenWidth / 2.0 * progress
            let insetY = Self.screenHeight / 2.0 * progress
            showWindow(left: insetX, top: insetY, width: Self.screenWidth - insetX * 2, height: Self.screenHeight - insetY * 2)
            if phaseElapsed >= 2.7 { setPhase(.finished) }
        }
        layoutCharacters()
    }

    private func setPhase(_ newPhase: Phase) {
        phase = newPhase
        phaseElapsed = 0
        onPhaseChange?(newPhase)
    }

    private func buildMap() {
        let map = StageMapData(assetName: StageDefinition.endingMapAssetName)
        let sheets = SpriteSheetManager.shared
        let tilesetOffset = StageDefinition.stage8.tilesetOffsetPx
        for row in 0..<StageMapData.screenRows {
            for col in 0..<StageMapData.screenCols {
                let tileId = map.tileId(row: row, col: col)
                let node = SKSpriteNode(
                    texture: sheets.texture(
                        from: .maps,
                        x: (tileId % SpriteSheetManager.tilesCols) * 8,
                        y: (tileId / SpriteSheetManager.tilesCols) * 8 + tilesetOffset,
                        width: 8,
                        height: 8
                    ),
                    size: CGSize(width: 8, height: 8)
                )
                node.position = Self.scenePosition(x: CGFloat(col * 8), top: CGFloat(row * 8), width: 8, height: 8)
                node.zPosition = 1
                addChild(node)
            }
        }
    }

    private func layoutCharacters() {
        let princessX = Self.screenWidth / 2.0 - 8 // `SCREEN_CENTER_W - OBJ_TILE[51].w / 2`
        let popolonX = Self.screenWidth / 2.0 - 8 // `PLAYER_INIT_COL * TILE_SIZE`
        princessNode.position = Self.scenePosition(x: princessX, top: princessY - 16, width: 16, height: 24)
        popolonNode.position = Self.scenePosition(x: popolonX, top: popolonY - 16, width: 16, height: 16)
    }

    private func setPopolonFrame(rightLeg: Bool) {
        popolonNode.texture = SpriteSheetManager.shared.texture(from: .objects, x: rightLeg ? 16 : 0, y: 0, width: 16, height: 16)
    }

    /// Paints black everywhere except the `(left, top, width, height)` window.
    private func showWindow(left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) {
        let bands = [
            CGRect(x: 0, y: 0, width: Self.screenWidth, height: top),
            CGRect(x: 0, y: top + height, width: Self.screenWidth, height: Self.screenHeight - top - height),
            CGRect(x: 0, y: top, width: left, height: height),
            CGRect(x: left + width, y: top, width: Self.screenWidth - left - width, height: height)
        ]
        for (node, band) in zip(windowNodes, bands) {
            node.isHidden = band.width <= 0 || band.height <= 0
            node.size = CGSize(width: max(0, band.width), height: max(0, band.height))
            node.position = Self.scenePosition(x: band.minX, top: band.minY, width: band.width, height: band.height)
        }
    }

    private static func scenePosition(x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: x + width / 2.0, y: screenHeight - (top + height / 2.0))
    }
}
