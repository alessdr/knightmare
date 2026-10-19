import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Loads and decodes a binary `stageN.map` (`238` rows × `32` columns of 16-bit big-endian cells),
/// matching `MapData.cpp`, `MapData.h`, and `MapSystem.cpp` from `knightmare-raylib`.
///
/// Binary layout (16-bit big-endian per tile):
/// - bits 0–6:   `tileId` (`0...127`, `raw & 0x7F`)
/// - bit  7:     `isSolid` (`(raw & 0x80) != 0`)
/// - bits 8–12:  `objectId` (`0...31`, `(raw >> 8) & 0x1F`)
/// - bits 13–15: `objectExtra` (`0...7`, `(raw >> 13) & 0x7`)
final class StageMapData {
    static let mapCols = 32
    static let mapRows = 238
    static let mapCols0 = 31
    static let mapRows0 = 237
    static let screenCols = 32
    static let screenRows = 22
    static let tileSize = 8

    struct Cell {
        var raw: Int

        /// Tile graphic index (`0...127`) inside `maps.png`.
        var tileId: Int {
            raw & 0x7F
        }

        /// Whether this `8×8` tile blocks Popolon's movement.
        var isSolid: Bool {
            get { (raw & 0x80) != 0 }
            set {
                if newValue {
                    raw |= 0x80
                } else {
                    raw &= 0xFF7F
                }
            }
        }

        /// Embedded object/enemy/block trigger ID (`0...31`).
        var objectId: Int {
            (raw >> 8) & 0x1F
        }

        /// Extra parameter (`0...7`) for blocks, bridges, or enemy waves.
        var objectExtra: Int {
            (raw >> 13) & 0x7
        }
    }

    private(set) var cells: [[Cell]]

    let assetName: String

    init(assetName: String = StageDefinition.stage1.mapAssetName) {
        self.assetName = assetName
        var loadedCells = Array(
            repeating: Array(repeating: Cell(raw: 0), count: Self.mapCols),
            count: Self.mapRows
        )

        if let data = Self.loadMapBinary(assetName: assetName) {
            var offset = 0
            for r in 0..<Self.mapRows {
                for c in 0..<Self.mapCols {
                    guard offset + 1 < data.count else { break }
                    let hi = Int(data[offset])
                    let lo = Int(data[offset + 1])
                    offset += 2
                    let word = (hi << 8) | lo
                    loadedCells[r][c] = Cell(raw: word)
                }
            }
        }

        self.cells = loadedCells
    }

    func tileId(row: Int, col: Int) -> Int {
        guard row >= 0, row < Self.mapRows else { return 0 }
        let wrappedCol = ((col % Self.mapCols) + Self.mapCols) % Self.mapCols
        return cells[row][wrappedCol].tileId
    }

    func isSolid(row: Int, col: Int) -> Bool {
        guard row >= 0, row < Self.mapRows else { return false }
        let wrappedCol = ((col % Self.mapCols) + Self.mapCols) % Self.mapCols
        return cells[row][wrappedCol].isSolid
    }

    func setSolid(row: Int, col: Int, solid: Bool) {
        guard row >= 0, row < Self.mapRows, col >= 0, col < Self.mapCols else { return }
        cells[row][col].isSolid = solid
    }

    func objectId(row: Int, col: Int) -> Int {
        guard row >= 0, row < Self.mapRows, col >= 0, col < Self.mapCols else { return 0 }
        return cells[row][col].objectId
    }

    func objectExtra(row: Int, col: Int) -> Int {
        guard row >= 0, row < Self.mapRows, col >= 0, col < Self.mapCols else { return 0 }
        return cells[row][col].objectExtra
    }

    /// Clears the solid river collision in a `4×4` tile area when a Bridge block (`Block::BRIDGE`) opens,
    /// matching `MapSystem::makeBridgeGround(row, col, down)` in `MapSystem.cpp`.
    func makeBridgeGround(row startRow: Int, col startCol: Int, down: Bool = false) {
        var r = startRow
        for _ in 0..<4 {
            for cOffset in 0..<4 {
                setSolid(row: r, col: startCol + cOffset, solid: false)
            }
            r += down ? 1 : -1
        }
    }

    /// Marks a `2×2` tile area as solid when a Barrier block (`Block::BARRIER`) is fully opened.
    func makeBlockSolid(row: Int, col: Int) {
        setSolid(row: row, col: col, solid: true)
        setSolid(row: row, col: col + 1, solid: true)
        setSolid(row: row + 1, col: col, solid: true)
        setSolid(row: row + 1, col: col + 1, solid: true)
    }

    /// Loads `assetName` (e.g. `stage2_map`) from the asset catalog, falling back to a bundled `stage2.map`.
    private static func loadMapBinary(assetName: String) -> Data? {
        if let asset = NSDataAsset(name: assetName) {
            return asset.data
        }
        let resourceName = assetName.replacingOccurrences(of: "_map", with: "")
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "map"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}
