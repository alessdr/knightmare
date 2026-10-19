import Foundation

/// Per-stage data table, mirroring the stage-indexed constants of `knightmare-raylib`
/// (`TILES_OFFSET`, `BOSS_LIFE`, `SHOOT_CHANCE`, `MUSIC`, `BOSS_MUSIC` in `Constants.h` / `Assets.cpp`).
struct StageDefinition: Equatable {
    enum BossKind: Equatable {
        case medusa // Stage 1 (Medusa / Hecate)
        case scytheReaper // Stage 2 (Lissajous movement, orbiting scythe shot `33`)
        case wingedDemon // Stage 3 (wing shield cycle, 7-way fan shot `28`)
        case cyclops // Stage 4 (damage skins, fireballs that land and burn at Popolon's height)
        case redKnight // Stage 5 (dashes, helmet that opens and closes, twin falling axes `32`)
        case ogre // Stage 6 (stomps open ground fissures `49`, single fireballs `28`)
        case phantomKnight // Stage 7 (small flying knight, speeds up when hurt, calls Blue Knights, arrows)
    }

    let number: Int
    /// Location name shown on the stage intro screen.
    let title: String
    /// `NSDataAsset` name holding the binary `.map` file.
    let mapAssetName: String
    /// Y offset (pixels) of this stage's tileset inside `maps.png` (`TILES_OFFSET[stage - 1]`).
    let tilesetOffsetPx: Int
    /// Base boss life before the difficulty multiplier (`BOSS_LIFE[stage]`).
    let bossBaseLife: Int
    /// Chance (`0...1`) of an enemy firing on each periodic fire tick, indexed by `Difficulty.rawValue`
    /// (`SHOOT_CHANCE[difficulty][stage - 1]`).
    let shootChance: [Double]
    let stageMusic: RetroAudioSynthesizer.MusicTrack
    let bossMusic: RetroAudioSynthesizer.MusicTrack
    let bossKind: BossKind
    /// Subtitle shown on the stage clear screen.
    let clearMessage: String
    /// Periodic enemy fire only happens while `currentRow` is below this value.
    let enemyFireMaxRow: Int

    func shootChance(for difficulty: GameStateManager.Difficulty) -> Double {
        shootChance[min(max(0, difficulty.rawValue), shootChance.count - 1)]
    }

    static let stage1 = StageDefinition(
        number: 1,
        title: "MOUNT ATHOS",
        mapAssetName: "stage1_map",
        tilesetOffsetPx: 0,
        bossBaseLife: 20,
        shootChance: [0.5, 0.5, 0.5],
        stageMusic: .stage1,
        bossMusic: .boss1,
        bossKind: .medusa,
        clearMessage: "MOUNT ATHOS CONQUERED",
        enemyFireMaxRow: 195
    )

    static let stage2 = StageDefinition(
        number: 2,
        title: "MOUNTAIN PASS",
        mapAssetName: "stage2_map",
        tilesetOffsetPx: 24,
        bossBaseLife: 48,
        shootChance: [0.3, 0.5, 0.7],
        stageMusic: .stage2,
        bossMusic: .boss2,
        bossKind: .scytheReaper,
        clearMessage: "MOUNTAIN PASS CROSSED",
        enemyFireMaxRow: StageMapData.mapRows
    )

    static let stage3 = StageDefinition(
        number: 3,
        title: "RIVER CROSSING",
        mapAssetName: "stage3_map",
        tilesetOffsetPx: 40,
        bossBaseLife: 30,
        shootChance: [0.3, 0.5, 0.7],
        // Odd stages share the Stage 1 theme (GDD §2.1); the reference's own boss track isn't bundled
        stageMusic: .stage1,
        bossMusic: .boss1,
        bossKind: .wingedDemon,
        clearMessage: "THE RIVERS ARE BEHIND YOU",
        enemyFireMaxRow: StageMapData.mapRows
    )

    static let stage4 = StageDefinition(
        number: 4,
        title: "CASTLE GROUNDS",
        mapAssetName: "stage4_map",
        tilesetOffsetPx: 72,
        bossBaseLife: 48,
        shootChance: [0.4, 0.6, 0.8],
        // Even stages reuse the Stage 2 theme; the reference's own tracks aren't bundled
        stageMusic: .stage2,
        bossMusic: .boss2,
        bossKind: .cyclops,
        clearMessage: "THE CASTLE GATE AWAITS",
        enemyFireMaxRow: StageMapData.mapRows
    )

    static let stage5 = StageDefinition(
        number: 5,
        title: "CASTLE HALLS",
        mapAssetName: "stage5_map",
        tilesetOffsetPx: 96,
        bossBaseLife: 40,
        shootChance: [0.4, 0.6, 0.8],
        // Odd stages share the Stage 1 theme (GDD §2.1)
        stageMusic: .stage1,
        bossMusic: .boss1,
        bossKind: .redKnight,
        clearMessage: "THE HALLS FALL SILENT",
        enemyFireMaxRow: StageMapData.mapRows
    )

    static let stage6 = StageDefinition(
        number: 6,
        title: "THE LAST RIVERS",
        mapAssetName: "stage6_map",
        tilesetOffsetPx: 120,
        bossBaseLife: 40,
        shootChance: [0.5, 0.7, 0.9],
        // Even stages reuse the Stage 2 theme
        stageMusic: .stage2,
        bossMusic: .boss2,
        bossKind: .ogre,
        clearMessage: "THE CASTLE LIES AHEAD",
        enemyFireMaxRow: StageMapData.mapRows
    )

    static let stage7 = StageDefinition(
        number: 7,
        title: "LAKE OF PIERS",
        mapAssetName: "stage7_map",
        tilesetOffsetPx: 120, // shares the Stage 6 tileset (`TILES_OFFSET[6]`)
        bossBaseLife: 40,
        shootChance: [0.5, 0.7, 0.9],
        // Odd stages share the Stage 1 theme (GDD §2.1)
        stageMusic: .stage1,
        bossMusic: .boss1,
        bossKind: .phantomKnight,
        clearMessage: "THE CASTLE GATES ARE NEAR",
        enemyFireMaxRow: StageMapData.mapRows
    )

    static let all: [StageDefinition] = [.stage1, .stage2, .stage3, .stage4, .stage5, .stage6, .stage7]

    /// Definition for a 1-based stage number, falling back to the last implemented stage.
    static func forStage(_ number: Int) -> StageDefinition {
        all.first { $0.number == number } ?? all[all.count - 1]
    }
}
