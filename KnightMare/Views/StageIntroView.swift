import SwiftUI

/// Displays the classic MSX "STAGE 01" opening iris/window reveal and HUD bar,
/// transitioning automatically into `StageGameplayView`.
struct StageIntroView: View {
    let gameState: GameStateManager

    @State private var revealProgress: CGFloat = 0.0
    @State private var animTick: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            msxHudHeader

            GeometryReader { geo in
                ZStack {
                    TiledBackdropView(
                        stageOffsetRows: gameState.currentStageDefinition.tilesetOffsetPx / SpriteSheetManager.tileSize
                    )

                    VStack {
                        Spacer()
                        MSXSpriteView(
                            cgImage: SpriteSheetManager.shared.popolonFrame(rightLeg: animTick % 2 == 0),
                            scale: 3.2
                        )
                        .padding(.bottom, 32)
                    }

                    if revealProgress < 1.0 {
                        Color.black
                            .opacity(1.0 - revealProgress * 0.85)
                    }

                    VStack(spacing: 16) {
                        MSXBitmapText(
                            text: String(format: "STAGE %02d", gameState.currentStage),
                            glyphSize: 22,
                            tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                        )
                        MSXBitmapText(
                            text: gameState.currentStageDefinition.title,
                            glyphSize: 13,
                            tint: .white
                        )
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.85))
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            gameState.enterStageGameplay()
        }
        .task {
            let totalSteps = 22
            for step in 1...totalSteps {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(55))
                revealProgress = CGFloat(step) / CGFloat(totalSteps)
            }
            if !Task.isCancelled {
                gameState.enterStageGameplay()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                animTick = (animTick + 1) % 4
            }
        }
    }

    private var msxHudHeader: some View {
        VStack(spacing: 6) {
            HStack {
                MSXBitmapText(
                    text: String(format: "SCORE %06d", gameState.score),
                    glyphSize: 12,
                    tint: .white
                )
                Spacer()
                MSXBitmapText(
                    text: String(format: "HI %06d", gameState.hiScore),
                    glyphSize: 12,
                    tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                )
            }
            HStack {
                MSXBitmapText(
                    text: "LIVES \(max(0, gameState.lives))",
                    glyphSize: 12,
                    tint: .cyan
                )
                Spacer()
                MSXBitmapText(
                    text: String(format: "STAGE %02d", gameState.currentStage),
                    glyphSize: 12,
                    tint: .green
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.25))
                .frame(height: 2)
        }
    }
}
