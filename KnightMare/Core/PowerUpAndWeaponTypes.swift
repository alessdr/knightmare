import CoreGraphics
import Foundation

/// Authentic MSX weapon definitions, power-up crystal variants, `?` block / chess piece types,
/// enemy metadata (`OBJ_TILE`, `OBJ_DATA`, `OBJ_POINTS`), and animation tables matching `Constants.h`,
/// `Block.h`, `ObjectSystem.cpp`, `MapSystem.cpp`, and `PowerUpSystem.cpp`.
enum MSXWeapon: Int, CaseIterable {
    case arrow = 1
    case twinArrow = 2
    case flame = 3
    case boomerang = 4
    case sword = 5
    case fireArrow = 6
    case superTwinArrow = 7
    case superFlame = 8
    case superBoomerang = 9
    case doubleSword = 10
    case superFireArrow = 11

    var displayName: String {
        switch self {
        case .arrow: return "ARROW"
        case .twinArrow: return "TWIN ARROW"
        case .flame: return "FLAME"
        case .boomerang: return "BOOMERANG"
        case .sword: return "SWORD"
        case .fireArrow: return "FIRE ARROW"
        case .superTwinArrow: return "TWIN ARROW II"
        case .superFlame: return "FLAME II"
        case .superBoomerang: return "BOOMERANG II"
        case .doubleSword: return "DOUBLE SWORD"
        case .superFireArrow: return "FIRE ARROW II"
        }
    }

    var cooldownMs: Int {
        switch self {
        case .flame, .superFlame:
            return 260
        default:
            return 150
        }
    }

    /// Super weapons pierce through regular enemies (`PowerUpSystem::isSuperWeapon`).
    var isSuperWeapon: Bool {
        switch self {
        case .flame, .boomerang, .fireArrow, .superFlame, .superBoomerang, .superFireArrow:
            return true
        default:
            return false
        }
    }

    var baseTileId: Int {
        switch self {
        case .arrow: return 40
        case .twinArrow, .superTwinArrow: return 41
        case .flame, .superFlame: return 42
        case .boomerang, .superBoomerang: return 43
        case .sword: return 45
        case .doubleSword: return 46
        case .fireArrow, .superFireArrow: return 47
        }
    }
}

/// Active temporary or persistent power-up state on Popolon (`Player::PWR_*`).
enum MSXPowerUpState: Int, Equatable {
    case none = 0
    case shield = 1
    case invincible = 2   // Red Aura + Wings (Pink/Red Crystal): flies at max speed, kills on contact, cannot shoot
    case transparent = 3  // White Aura (Yellow/Flashing Crystal): intangible to shots/enemies, can still shoot

    var displayName: String {
        switch self {
        case .none: return "NONE"
        case .shield: return "SHIELD"
        case .invincible: return "WINGS"
        case .transparent: return "SPIRIT"
        }
    }
}

/// Interactive `?` Block and Chess Piece types (`Block.h` & `MapSystem.cpp`).
enum MSXBlockType: Int, CaseIterable {
    case rook = 1           // Rook (Torre): +500 / +1000 points
    case knight = 2         // Knight (Cavalo): Kills all on-screen enemies
    case queen = 3          // Queen (Rainha): +1 Extra Life
    case king = 4           // King (Rei): Freezes scroll & enemies
    case barrier = 5        // Solid barrier block
    case collected = 6      // Already collected / resolved
    case bridge = 7         // Hidden Water Bridge trigger

    var maxHits: Int {
        switch self {
        case .collected:
            return 0
        case .knight, .queen, .king:
            return 10
        case .rook, .barrier, .bridge:
            return 5
        }
    }
}

/// Sprite coordinates in `objects.png`, movement data (`OBJ_DATA`), and animation tables from `Constants.h`.
enum MSXObjectTiles {
    struct TileRect {
        let x: Int
        let y: Int
        let w: Int
        let h: Int
        let dataId: Int

        init(x: Int, y: Int, w: Int, h: Int, dataId: Int = 0) {
            self.x = x
            self.y = y
            self.w = w
            self.h = h
            self.dataId = dataId
        }
    }

    struct ObjDataEntry {
        let speedX: CGFloat
        let speedY: CGFloat
        let gpr1: CGFloat
        let gpr2: CGFloat
        let gpr3: CGFloat
    }

    /// Complete `OBJ_TILE` table from `Constants.h`.
    static let objTiles: [Int: TileRect] = [
        1: TileRect(x: 1, y: 17, w: 14, h: 14, dataId: 1),      // Blob / Slime
        2: TileRect(x: 32, y: 16, w: 16, h: 11, dataId: 2),     // Bat
        3: TileRect(x: 32, y: 16, w: 16, h: 11, dataId: 3),     // Bat wave
        4: TileRect(x: 64, y: 16, w: 16, h: 16, dataId: 4),     // Knight
        5: TileRect(x: 113, y: 17, w: 14, h: 14, dataId: 5),    // Cloud / Tornado
        6: TileRect(x: 144, y: 16, w: 16, h: 16, dataId: 6),    // Blue demon
        7: TileRect(x: 176, y: 16, w: 16, h: 16, dataId: 7),    // Skeleton
        8: TileRect(x: 240, y: 17, w: 16, h: 15, dataId: 8),    // Demon / Witch
        9: TileRect(x: 16, y: 136, w: 15, h: 16, dataId: 9),    // Death ghost
        10: TileRect(x: 64, y: 136, w: 16, h: 16, dataId: 10),  // Zombie
        11: TileRect(x: 16, y: 120, w: 16, h: 16, dataId: 11),  // Ghost
        12: TileRect(x: 209, y: 2, w: 13, h: 13, dataId: 12),   // Yellow thing
        13: TileRect(x: 224, y: 1, w: 15, h: 14, dataId: 13),   // Red thing
        14: TileRect(x: 32, y: 16, w: 16, h: 11, dataId: 14),   // Bat reverse
        15: TileRect(x: 0, y: 120, w: 16, h: 16, dataId: 15),   // Sorcerer
        16: TileRect(x: 32, y: 136, w: 15, h: 16, dataId: 16),  // Red Death ghost

        20: TileRect(x: 0, y: 64, w: 16, h: 16, dataId: 20),    // Weapon orb
        21: TileRect(x: 0, y: 80, w: 16, h: 16, dataId: 21),    // Power-up crystal
        22: TileRect(x: 0, y: 104, w: 16, h: 16, dataId: 0),    // Blocks (`[?]`, Rook, Knight, Queen, King, Empty, Bridge)

        23: TileRect(x: 22, y: 38, w: 4, h: 4),                 // Enemy dot bullet
        24: TileRect(x: 35, y: 35, w: 10, h: 10),               // Enemy energy ray
        25: TileRect(x: 50, y: 37, w: 12, h: 6),                // Skeleton bone 1
        26: TileRect(x: 66, y: 35, w: 11, h: 11),               // Skeleton bone 2
        27: TileRect(x: 85, y: 34, w: 6, h: 12),                // Skeleton bone 3
        28: TileRect(x: 99, y: 35, w: 9, h: 9),                 // White explosion / fireball
        29: TileRect(x: 133, y: 34, w: 5, h: 14),                // Enemy arrow vertical
        30: TileRect(x: 145, y: 38, w: 13, h: 5),               // Enemy arrow horizontal
        31: TileRect(x: 163, y: 35, w: 11, h: 11),              // Enemy arrow diagonal
        32: TileRect(x: 177, y: 34, w: 13, h: 13),              // Axe
        33: TileRect(x: 48, y: 120, w: 16, h: 16),              // Scythe
        34: TileRect(x: 112, y: 104, w: 16, h: 16),             // Enemy death fire animation
        35: TileRect(x: 112, y: 120, w: 16, h: 16),             // Big fire
        36: TileRect(x: 136, y: 48, w: 16, h: 7),               // Shield
        37: TileRect(x: 200, y: 98, w: 40, h: 6),               // Boss shadow
        38: TileRect(x: 184, y: 49, w: 24, h: 6),               // Big shadow
        39: TileRect(x: 0, y: 33, w: 16, h: 6),                 // Shadow

        40: TileRect(x: 209, y: 50, w: 5, h: 13),               // Player Arrow
        41: TileRect(x: 210, y: 66, w: 12, h: 13),              // Player Twin arrows
        42: TileRect(x: 218, y: 54, w: 4, h: 10),               // Player Triple flames
        43: TileRect(x: 209, y: 35, w: 5, h: 10),               // Player Boomerang vertical
        44: TileRect(x: 218, y: 37, w: 10, h: 5),               // Player Boomerang horizontal
        45: TileRect(x: 225, y: 48, w: 6, h: 16),               // Player Sword
        46: TileRect(x: 226, y: 64, w: 13, h: 16),              // Player Double sword
        47: TileRect(x: 232, y: 49, w: 8, h: 14),               // Player Fire arrow
        48: TileRect(x: 184, y: 136, w: 32, h: 8),              // Bridge sprite
        49: TileRect(x: 240, y: 192, w: 16, h: 8),              // Terrain
        50: TileRect(x: 176, y: 128, w: 16, h: 16),             // Boss eyes
        51: TileRect(x: 0, y: 136, w: 16, h: 24)                // Princess
    ]

    static let shotTiles: [Int: TileRect] = objTiles

    /// Complete `OBJ_DATA` table from `Constants.h`.
    static let objData: [Int: ObjDataEntry] = [
        1: ObjDataEntry(speedX: 0, speedY: 0, gpr1: 1, gpr2: 1, gpr3: 0),
        2: ObjDataEntry(speedX: 75, speedY: 65, gpr1: 1, gpr2: 90, gpr3: 0),
        3: ObjDataEntry(speedX: 120, speedY: 33, gpr1: 1, gpr2: 0, gpr3: 0),
        4: ObjDataEntry(speedX: 40, speedY: 40, gpr1: 3, gpr2: 0, gpr3: 0),
        5: ObjDataEntry(speedX: 25, speedY: 360, gpr1: 1, gpr2: 0, gpr3: 0),
        6: ObjDataEntry(speedX: 70, speedY: 70, gpr1: 1, gpr2: 0, gpr3: 0),
        7: ObjDataEntry(speedX: 50, speedY: 15, gpr1: 3, gpr2: 0, gpr3: 0),
        8: ObjDataEntry(speedX: 160, speedY: 160, gpr1: 1, gpr2: 0, gpr3: 0),
        9: ObjDataEntry(speedX: 90, speedY: 80, gpr1: 1, gpr2: 0, gpr3: 0),
        10: ObjDataEntry(speedX: 0, speedY: 25, gpr1: 1, gpr2: 60, gpr3: 0),
        11: ObjDataEntry(speedX: 90, speedY: 31, gpr1: 1, gpr2: 0, gpr3: 0),
        12: ObjDataEntry(speedX: 240, speedY: 240, gpr1: 1, gpr2: 0, gpr3: 0),
        13: ObjDataEntry(speedX: 140, speedY: 50, gpr1: 1, gpr2: 0, gpr3: 0),
        14: ObjDataEntry(speedX: 50, speedY: -35, gpr1: 1, gpr2: 90, gpr3: 0),
        15: ObjDataEntry(speedX: 0, speedY: 20, gpr1: 1, gpr2: 0, gpr3: 0),
        16: ObjDataEntry(speedX: 40, speedY: 20, gpr1: 1, gpr2: 0, gpr3: 0),
        20: ObjDataEntry(speedX: 50, speedY: 20, gpr1: 0, gpr2: 0, gpr3: -1),
        21: ObjDataEntry(speedX: 50, speedY: 20, gpr1: 0, gpr2: 0, gpr3: -1)
    ]

    /// `OBJ_POINTS` awarded per enemy ID from `Constants.h`.
    static let objPoints: [Int: Int] = [
        1: 10, 2: 50, 3: 50, 4: 100, 5: 200, 6: 50,
        7: 100, 8: 200, 9: 200, 10: 100, 11: 100, 12: 300,
        13: 200, 14: 50, 15: 200, 16: 300
    ]

    /// `WEAPON_ANIM[4][6]` from `Constants.h`.
    static let weaponAnim: [[Int]] = [
        [0, 3, 5, 7, 9, 11],
        [1, 4, 6, 8, 10, 12],
        [0, 3, 5, 7, 9, 11],
        [2, 1, 1, 1, 1, 1]
    ]

    /// `PUP_ANIM[4][5]` from `Constants.h`.
    static let pupAnim: [[Int]] = [
        [0, 3, 6, 9, 12],
        [1, 4, 7, 10, 13],
        [0, 3, 6, 9, 12],
        [2, 5, 8, 11, 14]
    ]

    /// `FIRE_ANIM[16]` for enemy death explosions (`objId == 34`) from `Constants.h`.
    static let fireAnim: [Int] = [1, 0, 1, 0, 1, 0, 2, 1, 2, 1, 2, 1, 3, 2, 3, 2]
}
