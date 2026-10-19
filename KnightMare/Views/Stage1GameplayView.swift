import SwiftUI
import SpriteKit

/// Main Stage 1 gameplay container pairing the MSX HUD bar, the 256×176 SpriteKit viewport,
/// hardware keyboard monitoring, and optional virtual arcade controls.
struct Stage1GameplayView: View {
    let gameState: GameStateManager

    @State private var inputController = InputController()
    @State private var scene: Stage1Scene = {
        let s = Stage1Scene(size: CGSize(width: Stage1Scene.msxWidth, height: Stage1Scene.msxHeight))
        s.scaleMode = .aspectFit
        return s
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Top MSX HUD Bar
            hudHeaderBar

            // Main MSX Playfield (256x176 logical aspect ratio)
            GeometryReader { _ in
                ZStack {
                    Color(red: 0.02, green: 0.02, blue: 0.05)

                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .aspectRatio(Stage1Scene.msxWidth / Stage1Scene.msxHeight, contentMode: .fit)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color(white: 0.28), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.8), radius: 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                    if gameState.isStagePaused {
                        pauseOverlay
                    }
                }
            }

            // Bottom Virtual Arcade Controls & Marco 3 Quick-Test Strip
            if gameState.showVirtualControls {
                virtualArcadeBar
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            scene.gameState = gameState
            scene.inputController = inputController
            let activeScene = scene
            inputController.onPauseToggle = { [weak activeScene] in
                activeScene?.togglePause()
            }
            inputController.onEscapePressed = {
                gameState.returnToTitle()
            }
            inputController.startMonitoring()
        }
        .onDisappear {
            inputController.stopMonitoring()
        }
    }

    // MARK: - MSX HUD Header

    private var hudHeaderBar: some View {
        VStack(spacing: 5) {
            HStack {
                MSXBitmapText(
                    text: String(format: "SCORE %06d", gameState.score),
                    glyphSize: 11,
                    tint: .white
                )
                Spacer()
                MSXBitmapText(
                    text: String(format: "HI %06d", gameState.hiScore),
                    glyphSize: 11,
                    tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                )
            }

            HStack(spacing: 14) {
                MSXBitmapText(
                    text: "LIVES \(max(0, gameState.lives))",
                    glyphSize: 10,
                    tint: .cyan
                )

                MSXBitmapText(
                    text: "WPN \(gameState.currentWeaponName)",
                    glyphSize: 10,
                    tint: Color(red: 0.65, green: 0.95, blue: 0.55)
                )

                MSXBitmapText(
                    text: "SPD +\(gameState.speedLevel)",
                    glyphSize: 10,
                    tint: Color(red: 0.45, green: 0.75, blue: 1.0)
                )

                if gameState.shieldHits > 0 {
                    MSXBitmapText(
                        text: "SHD \(gameState.shieldHits)",
                        glyphSize: 10,
                        tint: shieldHudTint
                    )
                }

                if !gameState.activeAuraName.isEmpty {
                    MSXBitmapText(
                        text: "\(gameState.activeAuraName) \(gameState.auraRemainingSeconds)",
                        glyphSize: 10,
                        tint: gameState.activeAuraName == "WINGS"
                            ? Color(red: 1.0, green: 0.45, blue: 0.75)
                            : .yellow
                    )
                }

                if gameState.freezeRemainingSeconds > 0 {
                    MSXBitmapText(
                        text: "FREEZE \(gameState.freezeRemainingSeconds)",
                        glyphSize: 10,
                        tint: Color(red: 0.55, green: 0.9, blue: 1.0)
                    )
                }

                if gameState.wavesClearedCount > 0 {
                    MSXBitmapText(
                        text: "WAVES \(gameState.wavesClearedCount)",
                        glyphSize: 10,
                        tint: Color(red: 1.0, green: 0.78, blue: 0.35)
                    )
                }

                if gameState.bossMaxHp > 0 {
                    MSXBitmapText(
                        text: "BOSS \(gameState.bossHp)/\(gameState.bossMaxHp)",
                        glyphSize: 10,
                        tint: Color(red: 1.0, green: 0.38, blue: 0.38)
                    )
                }

                Spacer()

                MSXBitmapText(
                    text: String(format: "STG %02d", gameState.currentStage),
                    glyphSize: 10,
                    tint: .green
                )

                Button {
                    scene.togglePause()
                } label: {
                    MSXBitmapText(
                        text: gameState.isStagePaused ? "RESUME" : "PAUSE",
                        glyphSize: 9,
                        tint: gameState.isStagePaused ? .yellow : Color(white: 0.75)
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Rectangle()
                            .strokeBorder(Color(white: 0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    gameState.returnToTitle()
                } label: {
                    MSXBitmapText(
                        text: "EXIT",
                        glyphSize: 9,
                        tint: Color(red: 1.0, green: 0.45, blue: 0.45)
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Rectangle()
                            .strokeBorder(Color(red: 0.8, green: 0.3, blue: 0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.22))
                .frame(height: 2)
        }
    }

    private var shieldHudTint: Color {
        if gameState.shieldHits > 10 {
            return .cyan
        } else if gameState.shieldHits > 5 {
            return .yellow
        } else {
            return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        VStack(spacing: 18) {
            MSXBitmapText(
                text: "PAUSED",
                glyphSize: 20,
                tint: Color(red: 1.0, green: 0.85, blue: 0.2)
            )

            Button {
                scene.togglePause()
            } label: {
                MSXBitmapText(text: "CONTINUE", glyphSize: 13, tint: .white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.25))
                            .overlay(Rectangle().strokeBorder(Color.yellow, lineWidth: 2))
                    )
            }
            .buttonStyle(.plain)

            Button {
                gameState.returnToTitle()
            } label: {
                MSXBitmapText(text: "TITLE SCREEN", glyphSize: 12, tint: Color(white: 0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(Color.black.opacity(0.88))
        .overlay(
            Rectangle()
                .strokeBorder(Color.yellow, lineWidth: 2)
        )
    }

    // MARK: - Virtual Controls & Power-Up Test Bar

    private var virtualArcadeBar: some View {
        HStack(spacing: 16) {
            // D-Pad cluster
            HStack(spacing: 6) {
                arcadeHoldButton(symbol: "arrow.left", isActive: inputController.isLeft) { pressed in
                    inputController.virtualLeft = pressed
                }
                VStack(spacing: 6) {
                    arcadeHoldButton(symbol: "arrow.up", isActive: inputController.isUp) { pressed in
                        inputController.virtualUp = pressed
                    }
                    arcadeHoldButton(symbol: "arrow.down", isActive: inputController.isDown) { pressed in
                        inputController.virtualDown = pressed
                    }
                }
                arcadeHoldButton(symbol: "arrow.right", isActive: inputController.isRight) { pressed in
                    inputController.virtualRight = pressed
                }
            }

            Spacer()

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    quickActionButton(title: "ORB", tint: Color(red: 0.55, green: 0.9, blue: 1.0)) {
                        scene.spawnTestWeaponOrb()
                    }
                    quickActionButton(title: "CRYSTAL", tint: Color(red: 1.0, green: 0.7, blue: 0.95)) {
                        scene.spawnTestPowerCrystal()
                    }
                    quickActionButton(title: "SHIELD", tint: Color(red: 0.55, green: 0.95, blue: 0.65)) {
                        scene.testShieldHit()
                    }
                    quickActionButton(title: "? BLOCK", tint: Color(red: 1.0, green: 0.85, blue: 0.35)) {
                        scene.spawnTestQuestionBlock()
                    }
                    quickActionButton(title: "+WAVE", tint: Color(red: 1.0, green: 0.55, blue: 0.45)) {
                        scene.spawnTestEnemyWave()
                    }
                    quickActionButton(title: "BOSS", tint: Color(red: 1.0, green: 0.35, blue: 0.35)) {
                        scene.jumpToBossEncounter()
                    }
                }

                MSXBitmapText(
                    text: "ARROWS/WASD: MOVE • SPACE/Z: FIRE • P: PAUSE",
                    glyphSize: 8,
                    tint: Color(white: 0.55)
                )
            }

            Spacer()

            // Fire Button
            GestureHoldButton(
                isPressed: inputController.isFireHeld,
                activeColor: Color(red: 0.95, green: 0.25, blue: 0.25),
                onChanged: { pressed in
                    inputController.virtualFire = pressed
                }
            ) {
                MSXBitmapText(
                    text: "FIRE",
                    glyphSize: 13,
                    tint: .white
                )
                .frame(width: 84, height: 48)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.06, blue: 0.11))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(white: 0.22))
                .frame(height: 2)
        }
    }

    private func quickActionButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MSXBitmapText(text: title, glyphSize: 8, tint: tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(tint.opacity(0.65), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func arcadeHoldButton(
        symbol: String,
        isActive: Bool,
        onChanged: @escaping (Bool) -> Void
    ) -> some View {
        GestureHoldButton(
            isPressed: isActive,
            activeColor: Color(red: 0.25, green: 0.55, blue: 0.95),
            onChanged: onChanged
        ) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 32)
        }
    }
}

/// Press-and-hold arcade button supporting mouse and touch drag gestures.
private struct GestureHoldButton<Label: View>: View {
    let isPressed: Bool
    let activeColor: Color
    let onChanged: (Bool) -> Void
    @ViewBuilder let label: () -> Label

    @State private var isTouching: Bool = false

    var body: some View {
        label()
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed || isTouching ? activeColor : Color(white: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isPressed || isTouching ? Color.white : Color(white: 0.4), lineWidth: 1.5)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isTouching {
                            isTouching = true
                            onChanged(true)
                        }
                    }
                    .onEnded { _ in
                        isTouching = false
                        onChanged(false)
                    }
            )
    }
}

/// Classic MSX "GAME OVER" screen with automatic or manual return to Title Screen.
struct GameOverView: View {
    let gameState: GameStateManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                MSXBitmapText(
                    text: "GAME OVER",
                    glyphSize: 24,
                    tint: Color(red: 1.0, green: 0.3, blue: 0.3)
                )

                MSXBitmapText(
                    text: String(format: "SCORE %06d", gameState.score),
                    glyphSize: 14,
                    tint: .white
                )

                Button {
                    gameState.returnToTitle()
                } label: {
                    MSXBitmapText(
                        text: "TITLE SCREEN",
                        glyphSize: 13,
                        tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Rectangle()
                            .strokeBorder(Color(red: 1.0, green: 0.85, blue: 0.2), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4.2))
            if !Task.isCancelled && gameState.currentScreen == .gameOver {
                gameState.returnToTitle()
            }
        }
    }
}
/// Classic MSX "STAGE 01 CLEAR" victory screen displayed after defeating Medusa & entering the portal.
struct Stage1ClearView: View {
    let gameState: GameStateManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                MSXBitmapText(
                    text: "STAGE 01 CLEAR",
                    glyphSize: 22,
                    tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                )

                MSXBitmapText(
                    text: "MOUNT ATHOS CONQUERED",
                    glyphSize: 13,
                    tint: .cyan
                )

                VStack(spacing: 12) {
                    MSXBitmapText(
                        text: String(format: "FINAL SCORE %06d", gameState.score),
                        glyphSize: 14,
                        tint: .white
                    )

                    MSXBitmapText(
                        text: String(format: "HI SCORE    %06d", gameState.hiScore),
                        glyphSize: 13,
                        tint: Color(red: 1.0, green: 0.78, blue: 0.35)
                    )

                    MSXBitmapText(
                        text: "WAVES CLEARED \(gameState.wavesClearedCount)",
                        glyphSize: 12,
                        tint: Color(red: 0.55, green: 0.95, blue: 0.65)
                    )
                }
                .padding(.vertical, 8)

                HStack(spacing: 18) {
                    Button {
                        gameState.startStage1()
                    } label: {
                        MSXBitmapText(
                            text: "PLAY AGAIN",
                            glyphSize: 12,
                            tint: .black
                        )
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Rectangle()
                                .fill(Color(red: 1.0, green: 0.85, blue: 0.2))
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        gameState.returnToTitle()
                    } label: {
                        MSXBitmapText(
                            text: "TITLE SCREEN",
                            glyphSize: 12,
                            tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                        )
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Rectangle()
                                .strokeBorder(Color(red: 1.0, green: 0.85, blue: 0.2), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .overlay(
                Rectangle()
                    .strokeBorder(Color(white: 0.3), lineWidth: 2)
            )
        }
    }
}

