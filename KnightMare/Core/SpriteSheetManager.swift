import SwiftUI
import SpriteKit
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Central manager for slicing 8-bit MSX tilesets (`objects.png`, `maps.png`, `bosses.png`, `popolon.png`)
/// using the exact pixel coordinate conventions from `brunogamacatao/knightmare-raylib`.
final class SpriteSheetManager: @unchecked Sendable {
    static let shared = SpriteSheetManager()

    // MARK: - MSX Constants (matching Constants.h)
    static let tileSize: Int = 8
    static let tileSizeX2: Int = 16
    static let tileSizeX4: Int = 32
    static let tilesCols: Int = 32
    static let screenCols: Int = 32
    static let screenRows: Int = 22
    static let screenWidth: CGFloat = 256
    static let screenHeight: CGFloat = 176

    private static let symbolsX: Int = 0
    private static let symbolsY: Int = 48
    private static let numbersX: Int = 24
    private static let numbersY: Int = 48
    private static let lettersX: Int = 0
    private static let lettersY: Int = 56

    enum Sheet: String, Sendable {
        case objects = "objects"
        case maps = "maps"
        case bosses = "bosses"
        case popolon = "popolon"
    }

    private struct CacheKey: Hashable {
        let sheet: Sheet
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    private var sheetImages: [Sheet: CGImage] = [:]
    private var croppedCache: [CacheKey: CGImage] = [:]
    private let lock = NSLock()

    private init() {
        for sheet in [Sheet.objects, .maps, .bosses, .popolon] {
            if let cgImage = Self.loadCGImage(named: sheet.rawValue) {
                sheetImages[sheet] = cgImage
            }
        }
    }

    private static func loadCGImage(named name: String) -> CGImage? {
        #if os(macOS)
        guard let nsImage = NSImage(named: name) else { return nil }
        var rect = CGRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return UIImage(named: name)?.cgImage
        #endif
    }

    /// Returns a cropped `CGImage` using top-left pixel coordinates `(x, y, width, height)`.
    func cgImage(from sheet: Sheet, x: Int, y: Int, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let key = CacheKey(sheet: sheet, x: x, y: y, width: width, height: height)

        lock.lock()
        if let cached = croppedCache[key] {
            lock.unlock()
            return cached
        }
        let baseImage = sheetImages[sheet]
        lock.unlock()

        guard let baseImage else { return nil }
        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        guard let cropped = baseImage.cropping(to: cropRect) else { return nil }

        lock.lock()
        croppedCache[key] = cropped
        lock.unlock()
        return cropped
    }

    /// Returns a nearest-neighbor filtered `SKTexture` for SpriteKit nodes.
    func texture(from sheet: Sheet, x: Int, y: Int, width: Int, height: Int) -> SKTexture? {
        guard let cg = cgImage(from: sheet, x: x, y: y, width: width, height: height) else {
            return nil
        }
        let texture = SKTexture(cgImage: cg)
        texture.filteringMode = .nearest
        return texture
    }

    /// Returns a glyph `CGImage` from the MSX 8x8 bitmap font in `objects.png` (matching `Hud::glyph` in `Hud.cpp`).
    func glyphCGImage(for character: Character) -> CGImage? {
        guard let ascii = character.asciiValue else { return nil }
        let c = Int(ascii)
        let ts = Self.tileSize

        if c >= 32 && c <= 33 {
            return cgImage(from: .objects, x: Self.symbolsX + (c - 32) * ts, y: Self.symbolsY, width: ts, height: ts)
        }
        if c >= 40 && c <= 41 {
            return cgImage(from: .objects, x: Self.numbersX + (c - 29) * ts, y: Self.numbersY, width: ts, height: ts)
        }
        if c == 46 { // '.'
            return cgImage(from: .objects, x: Self.numbersX - ts, y: Self.numbersY, width: ts, height: ts)
        }
        if c >= 48 && c <= 58 { // '0'...'9' and ':'
            return cgImage(from: .objects, x: Self.numbersX + (c - 48) * ts, y: Self.numbersY, width: ts, height: ts)
        }
        if c >= 65 && c <= 90 { // 'A'...'Z'
            return cgImage(from: .objects, x: Self.lettersX + (c - 65) * ts, y: Self.lettersY, width: ts, height: ts)
        }
        if c >= 97 && c <= 122 { // 'a'...'z'
            return cgImage(from: .objects, x: Self.lettersX + (c - 97) * ts, y: Self.lettersY, width: ts, height: ts)
        }
        return nil
    }

    // MARK: - Named Sprite Helpers (from Constants.h)

    /// Popolon walking frame (0 = left leg, 1 = right leg).
    /// `skinOffset` can be 0 (normal), 32 (white aura), 64 (red aura), etc.
    func popolonFrame(rightLeg: Bool, skinOffset: Int = 0) -> CGImage? {
        let baseX = rightLeg ? 16 : 0
        return cgImage(from: .objects, x: baseX + skinOffset, y: 0, width: 16, height: 16)
    }

    /// Aphrodite / Princess sprite (`t[51] = {0, 136, 16, 24}`).
    func princessSprite() -> CGImage? {
        cgImage(from: .objects, x: 0, y: 136, width: 16, height: 24)
    }

    /// Shield sprite (`t[36] = {136, 48, 16, 7}`), stage 0 = blue, 1 = yellow, 2 = red.
    func shieldSprite(damageStage: Int = 0) -> CGImage? {
        let clamped = max(0, min(2, damageStage))
        return cgImage(from: .objects, x: 136 + clamped * 16, y: 48, width: 16, height: 7)
    }

    /// Blue Knight enemy (`t[4] = {64, 16, 16, 16}`).
    func knightSprite(frame: Int = 0) -> CGImage? {
        cgImage(from: .objects, x: 64 + (frame % 2) * 16, y: 16, width: 16, height: 16)
    }

    /// Bat enemy (`t[2] = {32, 16, 16, 11}`).
    func batSprite(frame: Int = 0) -> CGImage? {
        cgImage(from: .objects, x: 32 + (frame % 2) * 16, y: 16, width: 16, height: 11)
    }

    /// Cloud enemy (`t[5] = {113, 17, 14, 14}`).
    func cloudSprite() -> CGImage? {
        cgImage(from: .objects, x: 113, y: 17, width: 14, height: 14)
    }

    /// Demon enemy (`t[8] = {240, 17, 16, 15}`).
    func demonSprite() -> CGImage? {
        cgImage(from: .objects, x: 240, y: 17, width: 16, height: 15)
    }

    /// Sorcerer / Hera-like robed figure (`t[15] = {0, 120, 16, 16}`).
    func robedFigureSprite() -> CGImage? {
        cgImage(from: .objects, x: 0, y: 120, width: 16, height: 16)
    }

    /// Weapon crystal (`t[20] = {0, 64, 16, 16}`).
    func weaponCrystalSprite(column: Int = 1) -> CGImage? {
        cgImage(from: .objects, x: column * 16, y: 64, width: 16, height: 16)
    }

    /// Power crystal (`t[21] = {0, 80, 16, 16}`).
    func powerCrystalSprite(column: Int = 3) -> CGImage? {
        cgImage(from: .objects, x: column * 16, y: 80, width: 16, height: 16)
    }

    /// Question block `?` and chess pieces (`t[22] = {0, 104, 16, 16}`).
    func blockOrChessSprite(column: Int = 0) -> CGImage? {
        cgImage(from: .objects, x: column * 16, y: 104, width: 16, height: 16)
    }

    /// Stage 1 Boss (Medusa) from `bosses.png`.
    func medusaBossSprite(frame: Int = 0) -> CGImage? {
        cgImage(from: .bosses, x: (frame % 2) * 32, y: 0, width: 32, height: 32)
    }

    /// Stage 1 map tile from `maps.png`.
    func mapTile(tileId: Int, stageOffsetRows: Int = 0) -> CGImage? {
        let tx = (tileId % Self.tilesCols) * Self.tileSize
        let ty = (tileId / Self.tilesCols + stageOffsetRows) * Self.tileSize
        return cgImage(from: .maps, x: tx, y: ty, width: Self.tileSize, height: Self.tileSize)
    }
}

// MARK: - SwiftUI Pixel-Art Views

/// Renders a single cropped `CGImage` with crisp nearest-neighbor pixel interpolation.
struct MSXSpriteView: View {
    let cgImage: CGImage?
    var scale: CGFloat = 3.0

    var body: some View {
        if let cgImage {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .frame(
                    width: CGFloat(cgImage.width) * scale,
                    height: CGFloat(cgImage.height) * scale
                )
        } else {
            Color.clear
                .frame(width: 16 * scale, height: 16 * scale)
        }
    }
}

/// Renders text using the authentic 8x8 MSX bitmap font from `objects.png`.
struct MSXBitmapText: View {
    let text: String
    var glyphSize: CGFloat = 16
    var tint: Color = .white
    var spacing: CGFloat = 0

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, ch in
                if ch == " " {
                    Color.clear
                        .frame(width: glyphSize, height: glyphSize)
                } else if let cg = SpriteSheetManager.shared.glyphCGImage(for: ch) {
                    Image(decorative: cg, scale: 1.0)
                        .interpolation(.none)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(tint)
                        .frame(width: glyphSize, height: glyphSize)
                } else {
                    Color.clear
                        .frame(width: glyphSize, height: glyphSize)
                }
            }
        }
    }
}
