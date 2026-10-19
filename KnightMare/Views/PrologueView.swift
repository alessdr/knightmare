import SwiftUI

/// Interactive 8-bit narrative prologue implementing Section 1.1 of the Knightmare GDD.
struct PrologueView: View {
    let gameState: GameStateManager

    @State private var currentActIndex: Int = 0
    @State private var revealedCharCount: Int = 0
    @State private var animFrame: Int = 0
    @FocusState private var isFocused: Bool

    private struct PrologueAct: Identifiable {
        let id: Int
        let chapterCode: String
        let title: String
        let subtitle: String
        let narrative: String
        let accentColor: Color
    }

    private let acts: [PrologueAct] = [
        PrologueAct(
            id: 0,
            chapterCode: "PROLOGUE I",
            title: "O RAPTO DE AFRODITE",
            subtitle: "CASTELO DOS PESADELOS",
            narrative: "Afrodite, a Deusa do Amor e da Beleza, foi aprisionada nas profundezas do Castelo dos Pesadelos pelo sinistro Principe das Trevas, Hudnos.",
            accentColor: Color(red: 1.0, green: 0.35, blue: 0.45)
        ),
        PrologueAct(
            id: 1,
            chapterCode: "PROLOGUE II",
            title: "O PESADELO DE POPOLON",
            subtitle: "A BUSCA INCANSAVEL",
            narrative: "O corajoso guerreiro Popolon, apaixonado por Afrodite, parte em seu resgate. Exausto apos longa jornada, ele adormece e ve em um pesadelo milhares de criaturas horrendas ameacando Afrodite.",
            accentColor: Color(red: 0.45, green: 0.75, blue: 1.0)
        ),
        PrologueAct(
            id: 2,
            chapterCode: "PROLOGUE III",
            title: "A INTERVENCAO DE HERA",
            subtitle: "ALEM DO SAGRADO MONTE ATHOS",
            narrative: "A Deusa Hera, irma de Zeus, surge no sonho de Popolon e revela a verdade: o Castelo dos Pesadelos ergue-se alem das trilhas e templos do Sagrado Monte Athos.",
            accentColor: Color(red: 1.0, green: 0.85, blue: 0.25)
        ),
        PrologueAct(
            id: 3,
            chapterCode: "PROLOGUE IV",
            title: "AS JOIAS DO OLIMPO",
            subtitle: "A MARCHA RUMO AO MONTE ATHOS",
            narrative: "Hera instrui Popolon a usar o poder das Joias Magicas deixadas por Afrodite nas caselas '?' e os Cristais do Olimpo. Renovado pela protecao divina, Popolon desperta e inicia sua marcha!",
            accentColor: Color(red: 0.35, green: 0.95, blue: 0.55)
        )
    ]

    private var currentAct: PrologueAct {
        acts[currentActIndex]
    }

    private var isTextFullyRevealed: Bool {
        revealedCharCount >= currentAct.narrative.count
    }

    var body: some View {
        ZStack {
            // MSX deep midnight background
            Color(red: 0.02, green: 0.02, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Top Header Bar
                HStack {
                    MSXBitmapText(
                        text: currentAct.chapterCode,
                        glyphSize: 13,
                        tint: currentAct.accentColor
                    )
                    Spacer()
                    Button {
                        gameState.completePrologue()
                    } label: {
                        HStack(spacing: 6) {
                            MSXBitmapText(
                                text: "SKIP",
                                glyphSize: 11,
                                tint: Color(white: 0.75)
                            )
                            Text("[ESC]")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(white: 0.55))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(white: 0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer(minLength: 4)

                // Stage Diorama Box (authentic MSX sprites & tiles)
                dioramaStageView
                    .frame(maxWidth: 520)
                    .frame(height: 190)
                    .background(Color.black)
                    .overlay(
                        Rectangle()
                            .strokeBorder(currentAct.accentColor, lineWidth: 3)
                    )
                    .shadow(color: currentAct.accentColor.opacity(0.25), radius: 12)

                // Act Title & Subtitle
                VStack(spacing: 6) {
                    MSXBitmapText(
                        text: currentAct.title,
                        glyphSize: 15,
                        tint: .white
                    )
                    MSXBitmapText(
                        text: currentAct.subtitle,
                        glyphSize: 10,
                        tint: currentAct.accentColor
                    )
                }
                .padding(.top, 4)

                // Narrative Text Frame
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(currentAct.narrative.prefix(revealedCharCount)))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)

                    HStack {
                        // Act progress indicators
                        HStack(spacing: 8) {
                            ForEach(acts) { act in
                                Rectangle()
                                    .fill(act.id == currentActIndex ? currentAct.accentColor : Color(white: 0.28))
                                    .frame(width: act.id == currentActIndex ? 24 : 10, height: 6)
                            }
                        }

                        Spacer()

                        Button {
                            advanceOrReveal()
                        } label: {
                            HStack(spacing: 8) {
                                MSXBitmapText(
                                    text: currentActIndex == acts.count - 1 && isTextFullyRevealed ? "TITLE SCREEN" : "NEXT",
                                    glyphSize: 12,
                                    tint: Color(red: 1.0, green: 0.85, blue: 0.2)
                                )
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Rectangle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.22))
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(Color(red: 1.0, green: 0.85, blue: 0.2), lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .frame(maxWidth: 520)
                .background(Color(red: 0.05, green: 0.05, blue: 0.12))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color(white: 0.3), lineWidth: 2)
                )

                Spacer(minLength: 8)

                // Footer instructions
                MSXBitmapText(
                    text: "PRESS SPACE OR TAP TO CONTINUE",
                    glyphSize: 10,
                    tint: animFrame % 2 == 0 ? Color(white: 0.75) : Color(white: 0.35)
                )
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            advanceOrReveal()
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) {
            advanceOrReveal()
            return .handled
        }
        .onKeyPress(.return) {
            advanceOrReveal()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            advanceOrReveal()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            goToPreviousAct()
            return .handled
        }
        .onKeyPress(.escape) {
            gameState.completePrologue()
            return .handled
        }
        .onAppear {
            isFocused = true
            startAct(0)
        }
        .task(id: currentActIndex) {
            // Typewriter + sprite frame animation loop
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(35))
                if revealedCharCount < currentAct.narrative.count {
                    revealedCharCount += 1
                    if revealedCharCount % 4 == 0 {
                        RetroAudioSynthesizer.shared.playTextBlip()
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(240))
                animFrame = (animFrame + 1) % 4
            }
        }
    }

    // MARK: - Act Dioramas (using authentic MSX sprites from objects.png, maps.png, bosses.png)

    @ViewBuilder
    private var dioramaStageView: some View {
        let sheets = SpriteSheetManager.shared
        ZStack {
            // Subtle 8-bit tiled floor backdrop from maps.png
            TiledBackdropView(stageOffsetRows: currentActIndex == 0 ? 19 : 0)
                .opacity(0.35)

            switch currentActIndex {
            case 0:
                // Act I: Aphrodite imprisoned in Nightmare Castle guarded by Medusa & Demons
                HStack(spacing: 36) {
                    MSXSpriteView(cgImage: sheets.demonSprite(), scale: 3.5)
                        .offset(y: animFrame % 2 == 0 ? -4 : 4)

                    VStack(spacing: 8) {
                        MSXSpriteView(cgImage: sheets.medusaBossSprite(frame: animFrame), scale: 2.6)
                        ZStack {
                            MSXSpriteView(cgImage: sheets.princessSprite(), scale: 3.5)
                            // Prison bars overlay
                            HStack(spacing: 10) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color(white: 0.65).opacity(0.75))
                                        .frame(width: 3, height: 78)
                                }
                            }
                        }
                    }

                    MSXSpriteView(cgImage: sheets.demonSprite(), scale: 3.5)
                        .scaleEffect(x: -1, y: 1)
                        .offset(y: animFrame % 2 == 0 ? 4 : -4)
                }

            case 1:
                // Act II: Popolon's nightmare surrounded by Bats, Clouds, and Blue Knights
                ZStack {
                    HStack(spacing: 110) {
                        VStack(spacing: 18) {
                            MSXSpriteView(cgImage: sheets.batSprite(frame: animFrame), scale: 3.2)
                            MSXSpriteView(cgImage: sheets.knightSprite(frame: animFrame), scale: 3.2)
                        }
                        VStack(spacing: 18) {
                            MSXSpriteView(cgImage: sheets.cloudSprite(), scale: 3.2)
                            MSXSpriteView(cgImage: sheets.knightSprite(frame: animFrame + 1), scale: 3.2)
                        }
                    }

                    VStack(spacing: 10) {
                        MSXBitmapText(text: "AFRODITE!", glyphSize: 10, tint: Color(red: 1.0, green: 0.4, blue: 0.5))
                        MSXSpriteView(
                            cgImage: sheets.popolonFrame(rightLeg: false, skinOffset: animFrame % 2 == 0 ? 0 : 96),
                            scale: 4.0
                        )
                    }
                }

            case 2:
                // Act III: Goddess Hera reveals Mount Athos
                HStack(spacing: 42) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.25))
                                .frame(width: 76, height: 76)
                            MSXSpriteView(cgImage: sheets.robedFigureSprite(), scale: 3.8)
                        }
                        MSXBitmapText(text: "HERA", glyphSize: 10, tint: .yellow)
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.yellow)

                    VStack(spacing: 6) {
                        MSXSpriteView(
                            cgImage: sheets.popolonFrame(rightLeg: animFrame % 2 == 0, skinOffset: 32),
                            scale: 3.8
                        )
                        MSXBitmapText(text: "MT. ATHOS", glyphSize: 10, tint: .cyan)
                    }
                }

            default:
                // Act IV: The Jewels (Chess Pieces / '?' blocks) and Olympus Crystals + Popolon marching
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        VStack(spacing: 6) {
                            MSXSpriteView(cgImage: sheets.blockOrChessSprite(column: 0), scale: 2.8)
                            MSXBitmapText(text: "?", glyphSize: 9, tint: .yellow)
                        }
                        VStack(spacing: 6) {
                            MSXSpriteView(cgImage: sheets.blockOrChessSprite(column: 2), scale: 2.8)
                            MSXBitmapText(text: "JEWEL", glyphSize: 9, tint: .orange)
                        }
                        VStack(spacing: 6) {
                            MSXSpriteView(cgImage: sheets.weaponCrystalSprite(column: (animFrame % 5) + 1), scale: 2.8)
                            MSXBitmapText(text: "WEAPON", glyphSize: 9, tint: .green)
                        }
                        VStack(spacing: 6) {
                            MSXSpriteView(cgImage: sheets.powerCrystalSprite(column: (animFrame % 4) + 1), scale: 2.8)
                            MSXBitmapText(text: "POWER", glyphSize: 9, tint: .cyan)
                        }
                    }

                    HStack(spacing: 12) {
                        MSXSpriteView(cgImage: sheets.shieldSprite(damageStage: 0), scale: 3.0)
                        MSXSpriteView(
                            cgImage: sheets.popolonFrame(rightLeg: animFrame % 2 == 0),
                            scale: 3.6
                        )
                    }
                }
            }
        }
    }

    // MARK: - Navigation Actions

    private func startAct(_ index: Int) {
        currentActIndex = index
        revealedCharCount = 0
    }

    private func advanceOrReveal() {
        if !isTextFullyRevealed {
            revealedCharCount = currentAct.narrative.count
            return
        }

        if currentActIndex < acts.count - 1 {
            RetroAudioSynthesizer.shared.playPrologueAdvance()
            startAct(currentActIndex + 1)
        } else {
            gameState.completePrologue()
        }
    }

    private func goToPreviousAct() {
        guard currentActIndex > 0 else { return }
        RetroAudioSynthesizer.shared.playMenuMove()
        startAct(currentActIndex - 1)
    }
}

/// Renders an 8-bit tiled background strip using tiles from `maps.png`.
struct TiledBackdropView: View {
    var stageOffsetRows: Int = 0

    var body: some View {
        let sheets = SpriteSheetManager.shared
        GeometryReader { geo in
            let tilePx: CGFloat = 24
            let cols = max(1, Int(ceil(geo.size.width / tilePx)))
            let rows = max(1, Int(ceil(geo.size.height / tilePx)))

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            let isBorder = (c < 2 || c >= cols - 2)
                            let tileId = isBorder ? 34 : ((r + c) % 2 == 0 ? 1 : 2)
                            if let cg = sheets.mapTile(tileId: tileId, stageOffsetRows: stageOffsetRows) {
                                Image(decorative: cg, scale: 1.0)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: tilePx, height: tilePx)
                            } else {
                                Color.black.frame(width: tilePx, height: tilePx)
                            }
                        }
                    }
                }
            }
        }
        .clipped()
    }
}
