import SwiftUI

/// Konami 1986 MSX Title Screen combining `TitleScreen.cpp` from `knightmare-raylib`
/// and Section 1.2 of the Knightmare GDD (`Knightmare` / `Majou Densetsu`).
struct TitleScreenView: View {
    let gameState: GameStateManager

    @State private var introProgress: CGFloat = 0.0
    @State private var isIntroDone: Bool = false
    @State private var selectedItem: Int = 2 // Default to "START GAME"
    @State private var animTick: Int = 0
    @FocusState private var isFocused: Bool

    private let menuCount = 4

    var body: some View {
        ZStack {
            // MSX background color matching TitleScreen.cpp: Color{5, 5, 15, 255}
            Color(red: 5.0 / 255.0, green: 5.0 / 255.0, blue: 15.0 / 255.0)
                .ignoresSafeArea()

            if !isIntroDone {
                introDescendingView
            } else {
                mainTitleMenuContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isIntroDone {
                finishIntroImmediately()
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.upArrow) {
            handleUpKey()
            return .handled
        }
        .onKeyPress(.downArrow) {
            handleDownKey()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            handleHorizontalKey(delta: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            handleHorizontalKey(delta: 1)
            return .handled
        }
        .onKeyPress(.space) {
            handleActivateKey()
            return .handled
        }
        .onKeyPress(.return) {
            handleActivateKey()
            return .handled
        }
        .onAppear {
            isFocused = true
            RetroAudioSynthesizer.shared.playTitleFanfare()
        }
        .task {
            // 1.6s descending intro animation matching TitleScreen.cpp
            let steps = 32
            for step in 1...steps {
                if Task.isCancelled || isIntroDone { break }
                try? await Task.sleep(for: .milliseconds(50))
                introProgress = CGFloat(step) / CGFloat(steps)
            }
            isIntroDone = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(220))
                animTick = (animTick + 1) % 8
            }
        }
    }

    // MARK: - Descending Intro (matching `TitleScreen::drawIntro()`)

    private var introDescendingView: some View {
        GeometryReader { geo in
            let targetY = geo.size.height * 0.42
            let currentY = -120 + (targetY + 120) * introProgress

            VStack(spacing: 18) {
                knightmareEmblem
                MSXBitmapText(
                    text: "ORIGINAL GAME BY KONAMI(C) 1986",
                    glyphSize: 12,
                    tint: .white
                )
            }
            .frame(maxWidth: .infinity)
            .offset(y: currentY)
        }
    }

    // MARK: - Main Title Screen Content

    private var mainTitleMenuContent: some View {
        VStack(spacing: 18) {
            // Top MSX Score Bar
            HStack {
                MSXBitmapText(
                    text: String(format: "1P %06d", gameState.score),
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
            .padding(.horizontal, 28)
            .padding(.top, 16)

            Spacer(minLength: 4)

            // Main Title Emblem: KNIGHTMARE + Majou Densetsu
            knightmareEmblem

            MSXBitmapText(
                text: "ORIGINAL GAME BY KONAMI(C) 1986",
                glyphSize: 11,
                tint: Color(white: 0.82)
            )
            .padding(.top, 2)

            // Animated Stage 1 Showcase Strip (Popolon + Mount Athos tiles + Crystals)
            stage1ShowcaseStrip
                .padding(.vertical, 6)

            // Interactive Menu Lines (matching `TitleScreen::drawMenu()`)
            VStack(spacing: 14) {
                menuRow(
                    index: 0,
                    label: "DIFFICULTY: \(gameState.difficulty.title)"
                ) {
                    gameState.cycleDifficulty(delta: 1)
                }

                menuRow(
                    index: 1,
                    label: "STAGE: 01 MOUNT ATHOS"
                ) {
                    RetroAudioSynthesizer.shared.playMenuMove()
                }

                menuRow(
                    index: 2,
                    label: "START GAME"
                ) {
                    gameState.startStage1()
                }

                menuRow(
                    index: 3,
                    label: "WATCH PROLOGUE"
                ) {
                    gameState.replayPrologue()
                }
            }
            .padding(.vertical, 8)

            Spacer(minLength: 4)

            // Blinking prompt + sound toggle
            HStack {
                Button {
                    gameState.isSoundEnabled.toggle()
                    if gameState.isSoundEnabled {
                        RetroAudioSynthesizer.shared.playMenuMove()
                    }
                } label: {
                    MSXBitmapText(
                        text: gameState.isSoundEnabled ? "SOUND: ON" : "SOUND: OFF",
                        glyphSize: 10,
                        tint: gameState.isSoundEnabled ? .green : .gray
                    )
                    .padding(6)
                }
                .buttonStyle(.plain)

                Spacer()

                MSXBitmapText(
                    text: "PUSH SPACE KEY OR TAP START",
                    glyphSize: 10,
                    tint: animTick % 2 == 0 ? Color(red: 1.0, green: 0.85, blue: 0.2) : Color(white: 0.45)
                )

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Subviews

    private var knightmareEmblem: some View {
        VStack(spacing: 10) {
            // Double-layered pixel title for 8-bit arcade depth
            ZStack {
                MSXBitmapText(
                    text: "KNIGHTMARE",
                    glyphSize: 28,
                    tint: Color(red: 0.75, green: 0.12, blue: 0.15)
                )
                .offset(x: 3, y: 3)

                MSXBitmapText(
                    text: "KNIGHTMARE",
                    glyphSize: 28,
                    tint: Color(red: 1.0, green: 0.86, blue: 0.22)
                )
            }

            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(red: 0.9, green: 0.25, blue: 0.25))
                    .frame(width: 32, height: 3)

                Text("魔城伝説  •  MAJOU DENSETSU")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                    .tracking(2)

                Rectangle()
                    .fill(Color(red: 0.9, green: 0.25, blue: 0.25))
                    .frame(width: 32, height: 3)
            }
        }
    }

    private var stage1ShowcaseStrip: some View {
        let sheets = SpriteSheetManager.shared
        return HStack(spacing: 26) {
            MSXSpriteView(
                cgImage: sheets.weaponCrystalSprite(column: (animTick % 5) + 1),
                scale: 2.5
            )
            MSXSpriteView(
                cgImage: sheets.blockOrChessSprite(column: 0),
                scale: 2.5
            )
            VStack(spacing: 2) {
                MSXSpriteView(
                    cgImage: sheets.shieldSprite(damageStage: 0),
                    scale: 2.5
                )
                MSXSpriteView(
                    cgImage: sheets.popolonFrame(rightLeg: animTick % 2 == 0),
                    scale: 3.2
                )
            }
            MSXSpriteView(
                cgImage: sheets.knightSprite(frame: animTick),
                scale: 2.5
            )
            MSXSpriteView(
                cgImage: sheets.powerCrystalSprite(column: (animTick % 4) + 1),
                scale: 2.5
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            ZStack {
                TiledBackdropView(stageOffsetRows: 0)
                    .opacity(0.45)
                Rectangle()
                    .strokeBorder(Color(red: 0.35, green: 0.55, blue: 0.95), lineWidth: 2)
            }
        )
    }

    private func menuRow(index: Int, label: String, action: @escaping () -> Void) -> some View {
        let isSelected = selectedItem == index
        let tint = isSelected
            ? Color(red: 1.0, green: 217.0 / 255.0, blue: 51.0 / 255.0)
            : Color.white

        return Button {
            selectedItem = index
            action()
        } label: {
            HStack(spacing: 12) {
                if isSelected {
                    MSXSpriteView(
                        cgImage: SpriteSheetManager.shared.popolonFrame(rightLeg: animTick % 2 == 0),
                        scale: 1.6
                    )
                } else {
                    Color.clear.frame(width: 25.6, height: 25.6)
                }

                MSXBitmapText(
                    text: label,
                    glyphSize: isSelected ? 15 : 13,
                    tint: tint
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.white.opacity(0.08)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Keyboard & Menu Input

    private func finishIntroImmediately() {
        introProgress = 1.0
        isIntroDone = true
    }

    private func handleUpKey() {
        guard isIntroDone else {
            finishIntroImmediately()
            return
        }
        selectedItem = (selectedItem - 1 + menuCount) % menuCount
        RetroAudioSynthesizer.shared.playMenuMove()
    }

    private func handleDownKey() {
        guard isIntroDone else {
            finishIntroImmediately()
            return
        }
        selectedItem = (selectedItem + 1) % menuCount
        RetroAudioSynthesizer.shared.playMenuMove()
    }

    private func handleHorizontalKey(delta: Int) {
        guard isIntroDone else {
            finishIntroImmediately()
            return
        }
        if selectedItem == 0 {
            gameState.cycleDifficulty(delta: delta)
        }
    }

    private func handleActivateKey() {
        guard isIntroDone else {
            finishIntroImmediately()
            return
        }
        switch selectedItem {
        case 0:
            gameState.cycleDifficulty(delta: 1)
        case 1:
            RetroAudioSynthesizer.shared.playMenuMove()
        case 2:
            gameState.startStage1()
        case 3:
            gameState.replayPrologue()
        default:
            break
        }
    }
}
