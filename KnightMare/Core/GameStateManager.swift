import SwiftUI
import Observation

/// Global state manager for the screen lifecycle and player progression.
@MainActor
@Observable
final class GameStateManager {
    static let newLifePoints: Int = 50_000

    enum ScreenState: Equatable {
        case prologue
        case titleScreen
        case stageIntro
        case playingStage
        case stageClear
        case gameOver
    }

    enum Difficulty: Int, CaseIterable, Identifiable {
        case easy = 0
        case normal = 1
        case hard = 2

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .easy: return "EASY"
            case .normal: return "NORMAL"
            case .hard: return "HARD"
            }
        }

        var bossLifeMultiplier: Double {
            switch self {
            case .easy: return 0.5
            case .normal: return 1.0
            case .hard: return 1.5
            }
        }
    }

    var currentScreen: ScreenState = .prologue
    var difficulty: Difficulty = .normal
    var currentStage: Int = 1
    var selectedStartStage: Int = 1
    var score: Int = 0 {
        didSet {
            if score > hiScore {
                hiScore = score
            }
        }
    }
    var hiScore: Int = 20000
    var lives: Int = 3
    var isStagePaused: Bool = false
    var stageProgressRows: Int = 0
    var showVirtualControls: Bool = true

    // Marco 3, 4, 5 & 6 HUD status properties
    var currentWeaponName: String = MSXWeapon.arrow.displayName
    var speedLevel: Int = 0
    var shieldHits: Int = 0
    var activeAuraName: String = ""
    var auraRemainingSeconds: Int = 0
    var freezeRemainingSeconds: Int = 0
    var wavesClearedCount: Int = 0
    var activeEnemiesCount: Int = 0
    var bossHp: Int = 0
    var bossMaxHp: Int = 0

    /// Weapon and speed upgrades carried from a cleared stage into the next one (GDD §8).
    var carriedWeapon: MSXWeapon = .arrow
    var carriedSpeedLevel: Int = 0

    var currentStageDefinition: StageDefinition {
        StageDefinition.forStage(currentStage)
    }

    var hasNextStage: Bool {
        StageDefinition.all.contains { $0.number == currentStage + 1 }
    }

    var isSoundEnabled: Bool = true {
        didSet {
            RetroAudioSynthesizer.shared.isSoundEnabled = isSoundEnabled
        }
    }

    func incrementScore(_ points: Int) {
        let before = score / Self.newLifePoints
        score += points
        if score / Self.newLifePoints > before {
            lives += 1
            RetroAudioSynthesizer.shared.playSfx(.newLife)
        }
    }

    func completePrologue() {
        RetroAudioSynthesizer.shared.playMenuConfirm()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = .titleScreen
        }
    }

    func replayPrologue() {
        RetroAudioSynthesizer.shared.stopMusic()
        RetroAudioSynthesizer.shared.playMenuConfirm()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = .prologue
        }
    }

    func cycleDifficulty(delta: Int = 1) {
        let all = Difficulty.allCases
        let nextIndex = (difficulty.rawValue + delta + all.count) % all.count
        if let next = Difficulty(rawValue: nextIndex) {
            difficulty = next
            RetroAudioSynthesizer.shared.playMenuMove()
        }
    }

    /// Cycles the title screen's starting stage through the implemented stages (`TitleScreen` menu item 1).
    func cycleStartStage(delta: Int = 1) {
        let numbers = StageDefinition.all.map(\.number)
        let index = numbers.firstIndex(of: selectedStartStage) ?? 0
        selectedStartStage = numbers[(index + delta + numbers.count) % numbers.count]
        RetroAudioSynthesizer.shared.playMenuMove()
    }

    /// Starts a brand-new game from the stage selected on the title screen.
    func startNewGame() {
        score = 0
        lives = 3
        currentStage = selectedStartStage
        carriedWeapon = .arrow
        carriedSpeedLevel = 0
        wavesClearedCount = 0
        beginStageIntro()
    }

    /// Moves on to the next stage, keeping score, lives, weapon and speed upgrades.
    func advanceToNextStage() {
        guard hasNextStage else { return }
        currentStage += 1
        beginStageIntro()
    }

    private func beginStageIntro() {
        isStagePaused = false
        stageProgressRows = 0
        currentWeaponName = carriedWeapon.displayName
        speedLevel = carriedSpeedLevel
        shieldHits = 0
        activeAuraName = ""
        auraRemainingSeconds = 0
        freezeRemainingSeconds = 0
        activeEnemiesCount = 0
        bossHp = 0
        bossMaxHp = 0
        RetroAudioSynthesizer.shared.playStageStartFanfare()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = .stageIntro
        }
    }

    func enterStageGameplay() {
        isStagePaused = false
        withAnimation(.easeInOut(duration: 0.25)) {
            currentScreen = .playingStage
        }
    }

    func triggerStageClear(weapon: MSXWeapon, speedLevel carriedSpeed: Int) {
        carriedWeapon = weapon
        carriedSpeedLevel = carriedSpeed
        isStagePaused = false
        bossHp = 0
        bossMaxHp = 0
        RetroAudioSynthesizer.shared.playTitleFanfare()
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = .stageClear
        }
    }

    func triggerGameOver() {
        isStagePaused = false
        RetroAudioSynthesizer.shared.playGameOverMusic()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = .gameOver
        }
    }

    func returnToTitle() {
        isStagePaused = false
        RetroAudioSynthesizer.shared.stopMusic()
        RetroAudioSynthesizer.shared.playMenuMove()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = .titleScreen
        }
    }
}
