import SwiftUI
import SpriteKit

/// The game's ending: the Aphrodite rescue cutscene (`EndingScene`), preceded by the reference's 4-second
/// "YOU HAVE BEATEN ALL DEMONS !" message, followed by the final score card.
struct EndingView: View {
    let gameState: GameStateManager

    @State private var scene: EndingScene = {
        let scene = EndingScene(size: CGSize(width: 256, height: 176))
        scene.scaleMode = .aspectFit
        return scene
    }()
    @State private var phase: EndingScene.Phase = .message

    private let gold = Color(red: 1.0, green: 0.85, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if phase == .finished {
                finalCard
                    .transition(.opacity)
            } else {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .aspectRatio(256.0 / 176.0, contentMode: .fit)
                    .padding(8)

                if phase == .message {
                    MSXBitmapText(text: "YOU HAVE BEATEN ALL DEMONS !", glyphSize: 14, tint: gold)
                        .padding(16)
                        .background(Color.black.opacity(0.85))
                }
            }
        }
        .onAppear {
            scene.onPhaseChange = { newPhase in
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = newPhase
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                scene.startCutscene()
            }
        }
    }

    private var finalCard: some View {
        VStack(spacing: 22) {
            MSXBitmapText(text: "APHRODITE IS FREE", glyphSize: 22, tint: gold)
            MSXBitmapText(text: "THE CASTLE OF NIGHTMARES HAS FALLEN", glyphSize: 11, tint: .cyan)

            VStack(spacing: 12) {
                MSXBitmapText(text: String(format: "FINAL SCORE %06d", gameState.score), glyphSize: 14, tint: .white)
                MSXBitmapText(
                    text: String(format: "HI SCORE    %06d", gameState.hiScore),
                    glyphSize: 13,
                    tint: Color(red: 1.0, green: 0.78, blue: 0.35)
                )
            }
            .padding(.vertical, 8)

            Button {
                gameState.returnToTitle()
            } label: {
                MSXBitmapText(text: "TITLE SCREEN", glyphSize: 12, tint: gold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Rectangle().strokeBorder(gold, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .overlay(Rectangle().strokeBorder(Color(white: 0.3), lineWidth: 2))
    }
}
