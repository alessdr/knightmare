import Foundation

/// Per-stage data table, mirroring the stage-indexed constants of `knightmare-raylib`
/// (`TILES_OFFSET`, `BOSS_LIFE`, `SHOOT_CHANCE`, `MUSIC`, `BOSS_MUSIC` in `Constants.h` / `Assets.cpp`).
struct StageDefinition: Equatable {
    enum BossKind: Equatable {
        case medusa // Stage 1 (Medusa / Hecate)
        case scytheReaper // Stage 2 (Lissajous movement, orbiting scythe shot `33`)
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

    static let all: [StageDefinition] = [.stage1, .stage2]

    /// Definition for a 1-based stage number, falling back to the last implemented stage.
    static func forStage(_ number: Int) -> StageDefinition {
        all.first { $0.number == number } ?? all[all.count - 1]
    }
}
