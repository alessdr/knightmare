import SwiftUI

struct ContentView: View {
    @State private var gameState = GameStateManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch gameState.currentScreen {
            case .prologue:
                PrologueView(gameState: gameState)
                    .transition(.opacity)

            case .titleScreen:
                TitleScreenView(gameState: gameState)
                    .transition(.opacity)

            case .stageIntro:
                StageIntroView(gameState: gameState)
                    .transition(.opacity)

            case .playingStage:
                StageGameplayView(gameState: gameState)
                    .id(gameState.currentStage)
                    .transition(.opacity)

            case .stageClear:
                StageClearView(gameState: gameState)
                    .transition(.opacity)

            case .gameOver:
                GameOverView(gameState: gameState)
                    .transition(.opacity)
            }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 580)
        #endif
    }
}

#Preview("Title Screen") {
    ContentView()
}
