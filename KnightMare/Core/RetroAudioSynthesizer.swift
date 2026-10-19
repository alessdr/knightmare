import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Audio engine managing the authentic MSX MP3 soundtrack (`specs/sounds/*.mp3`)
/// and WAV sound effects (`sfx_*.dataset`), with 8-bit PSG synthesis fallback.
@MainActor
final class RetroAudioSynthesizer {
    static let shared = RetroAudioSynthesizer()

    enum MusicTrack: String {
        case intro = "bgm_intro"
        case stage1 = "bgm_stage1"
        case stage2 = "bgm_stage2"
        case boss1 = "bgm_boss1"
        case boss2 = "bgm_boss2"
        case powerup = "bgm_powerup"
        case death = "bgm_death"
        case gameover = "bgm_gameover"
    }

    enum SoundEffect: String {
        case shot = "sfx_shot"
        case shotFireArrow = "sfx_shot_fire_arrow"
        case shotFlame = "sfx_shot_flame"
        case shotBoomerang = "sfx_shot_boomerang"
        case shotSword = "sfx_shot_sword"
        case crystal = "sfx_chrystal"
        case powerUpHit = "sfx_power_up_hit"
        case powerUpEnding = "sfx_power_up_ending"
        case shield = "sfx_shield"
        case helmet = "sfx_helmet"
        case blockHit = "sfx_block_hit"
        case blockOpen = "sfx_block_open"
        case points = "sfx_points"
        case newLife = "sfx_new_life"
        case killAllEnemies = "sfx_kill_all_enemies"
        case freezeTick = "sfx_freeze_tick"
        case enemyKill = "sfx_enemy_kill"
        case bossHit = "sfx_boss_hit"
        case bossKill = "sfx_boss_kill"
        case bossShield = "sfx_boss_shield"
        case playerDeath = "sfx_player_death"
        case pause = "sfx_pause"
        case terrain = "sfx_terrain"
        case split = "sfx_split"
        case skeletonRestored = "sfx_skeleton_restored"
    }

    var isSoundEnabled: Bool = true {
        didSet {
            if !isSoundEnabled {
                stopMusic()
                players.forEach { $0.stop() }
                players.removeAll()
            }
        }
    }

    private var bgmPlayer: AVAudioPlayer?
    private var currentTrack: MusicTrack?
    private var players: [AVAudioPlayer] = []

    private init() {}

    // MARK: - Background Music (MP3 from specs/sounds)

    func playMusic(_ track: MusicTrack, loop: Bool = true, volume: Float = 0.65) {
        guard isSoundEnabled else { return }
        if currentTrack == track, let bgmPlayer, bgmPlayer.isPlaying {
            return
        }
        stopMusic()

        guard let asset = NSDataAsset(name: track.rawValue) else { return }
        do {
            let player = try AVAudioPlayer(data: asset.data)
            player.numberOfLoops = loop ? -1 : 0
            player.volume = volume
            player.prepareToPlay()
            player.play()
            bgmPlayer = player
            currentTrack = track
        } catch {
            // Ignore audio device errors in headless/preview environments
        }
    }

    func pauseMusic() {
        bgmPlayer?.pause()
    }

    func resumeMusic() {
        guard isSoundEnabled else { return }
        bgmPlayer?.play()
    }

    func stopMusic() {
        bgmPlayer?.stop()
        bgmPlayer = nil
        currentTrack = nil
    }

    // MARK: - Authentic MSX Sound Effects

    func playSfx(_ sfx: SoundEffect, volume: Float = 0.75) {
        guard isSoundEnabled else { return }
        guard let asset = NSDataAsset(name: sfx.rawValue) else { return }
        do {
            let player = try AVAudioPlayer(data: asset.data)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            players.removeAll { !$0.isPlaying }
            players.append(player)
        } catch {
            // Ignore audio device errors in headless/preview environments
        }
    }

    // MARK: - Convenience Triggers

    func playMenuMove() {
        playToneSequence([(frequency: 880, duration: 0.045)])
    }

    func playMenuConfirm() {
        playToneSequence([
            (frequency: 523.25, duration: 0.06),
            (frequency: 659.25, duration: 0.06),
            (frequency: 783.99, duration: 0.06),
            (frequency: 1046.50, duration: 0.14)
        ])
    }

    func playTextBlip() {
        playToneSequence([(frequency: 660, duration: 0.02)], volume: 0.08)
    }

    func playPrologueAdvance() {
        playToneSequence([
            (frequency: 440.0, duration: 0.05),
            (frequency: 554.37, duration: 0.05),
            (frequency: 659.25, duration: 0.10)
        ])
    }

    func playShot() {
        if NSDataAsset(name: SoundEffect.shot.rawValue) != nil {
            playSfx(.shot, volume: 0.65)
        } else {
            playToneSequence([
                (frequency: 1320.0, duration: 0.022),
                (frequency: 987.77, duration: 0.025),
                (frequency: 659.25, duration: 0.03)
            ], volume: 0.12)
        }
    }

    func playPause() {
        if NSDataAsset(name: SoundEffect.pause.rawValue) != nil {
            playSfx(.pause, volume: 0.75)
        } else {
            playToneSequence([
                (frequency: 783.99, duration: 0.06),
                (frequency: 1046.50, duration: 0.09)
            ], volume: 0.14)
        }
    }

    func playPlayerDeath() {
        stopMusic()
        if NSDataAsset(name: MusicTrack.death.rawValue) != nil {
            playMusic(.death, loop: false, volume: 0.75)
        } else if NSDataAsset(name: SoundEffect.playerDeath.rawValue) != nil {
            playSfx(.playerDeath, volume: 0.8)
        } else {
            playToneSequence([
                (frequency: 587.33, duration: 0.09),
                (frequency: 523.25, duration: 0.09),
                (frequency: 440.00, duration: 0.09),
                (frequency: 349.23, duration: 0.11),
                (frequency: 261.63, duration: 0.24)
            ], volume: 0.18)
        }
    }

    func playTitleFanfare() {
        if NSDataAsset(name: MusicTrack.intro.rawValue) != nil {
            playMusic(.intro, loop: false, volume: 0.7)
        } else {
            let notes: [(frequency: Double, duration: Double)] = [
                (329.63, 0.11),
                (392.00, 0.11),
                (493.88, 0.11),
                (659.25, 0.22),
                (587.33, 0.11),
                (659.25, 0.11),
                (783.99, 0.28),
                (659.25, 0.14),
                (587.33, 0.14),
                (493.88, 0.30)
            ]
            playToneSequence(notes, volume: 0.16)
        }
    }

    func playStageStartFanfare() {
        if NSDataAsset(name: MusicTrack.intro.rawValue) != nil {
            playMusic(.intro, loop: false, volume: 0.7)
        } else {
            let notes: [(frequency: Double, duration: Double)] = [
                (440.00, 0.09),
                (440.00, 0.09),
                (440.00, 0.09),
                (587.33, 0.24),
                (523.25, 0.12),
                (587.33, 0.12),
                (659.25, 0.12),
                (783.99, 0.35)
            ]
            playToneSequence(notes, volume: 0.18)
        }
    }

    func playStage1Music() {
        playMusic(.stage1, loop: true, volume: 0.65)
    }

    func playBoss1Music() {
        playMusic(.boss1, loop: true, volume: 0.7)
    }

    func playPowerUpMusic() {
        playMusic(.powerup, loop: false, volume: 0.7)
    }

    func playGameOverMusic() {
        playMusic(.gameover, loop: false, volume: 0.75)
    }

    // MARK: - PSG Fallback Synthesizer

    private func playToneSequence(
        _ notes: [(frequency: Double, duration: Double)],
        volume: Float = 0.14
    ) {
        guard isSoundEnabled, !notes.isEmpty else { return }
        guard let wavData = Self.makeSquareWaveWAV(notes: notes, volume: volume) else { return }

        do {
            let player = try AVAudioPlayer(data: wavData)
            player.prepareToPlay()
            player.play()
            players.removeAll { !$0.isPlaying }
            players.append(player)
        } catch {
            // Ignore audio device errors in headless/preview environments
        }
    }

    private static func makeSquareWaveWAV(
        notes: [(frequency: Double, duration: Double)],
        volume: Float
    ) -> Data? {
        let sampleRate = 22050
        let totalDuration = notes.reduce(0.0) { $0 + $1.duration }
        let totalSamples = max(1, Int(totalDuration * Double(sampleRate)))

        var pcmSamples = [Int16](repeating: 0, count: totalSamples)
        var cursor = 0

        for note in notes {
            let count = Int(note.duration * Double(sampleRate))
            let amplitude = Double(Int16.max) * Double(min(max(volume, 0.01), 0.9))
            for i in 0..<count {
                guard cursor + i < totalSamples else { break }
                if note.frequency <= 0 {
                    pcmSamples[cursor + i] = 0
                } else {
                    let t = Double(i) / Double(sampleRate)
                    let cycle = (t * note.frequency).truncatingRemainder(dividingBy: 1.0)
                    let envelope = max(0.2, 1.0 - (Double(i) / Double(max(1, count))) * 0.45)
                    let value = (cycle < 0.5 ? amplitude : -amplitude) * envelope
                    pcmSamples[cursor + i] = Int16(clamping: Int(value))
                }
            }
            cursor += count
        }

        return encodeWAV(samples: pcmSamples, sampleRate: sampleRate)
    }

    private static func encodeWAV(samples: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample / 8))
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(littleEndianBytes(chunkSize))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(littleEndianBytes(UInt32(16)))
        data.append(littleEndianBytes(UInt16(1)))
        data.append(littleEndianBytes(numChannels))
        data.append(littleEndianBytes(UInt32(sampleRate)))
        data.append(littleEndianBytes(byteRate))
        data.append(littleEndianBytes(blockAlign))
        data.append(littleEndianBytes(bitsPerSample))
        data.append("data".data(using: .ascii)!)
        data.append(littleEndianBytes(dataSize))

        samples.withUnsafeBufferPointer { buffer in
            data.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                count: Int(dataSize)
            ))
        }
        return data
    }

    private static func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> Data {
        var le = value.littleEndian
        return Data(bytes: &le, count: MemoryLayout<T>.size)
    }
}
