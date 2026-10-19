import SpriteKit

/// Runtime entity representing an active enemy or explosion (`GameObj` in `GameObj.h`).
final class EnemyObject {
    var id: Int
    let node: SKSpriteNode
    let shadowNode: SKSpriteNode?
    var x: CGFloat
    var y: CGFloat
    var gpr1: CGFloat = 0 // HP / life / anim step
    var gpr2: CGFloat = 0 // state / angle / direction
    var gpr3: CGFloat = 0 // auxiliary state
    var aux1: Int = 0     // timer / secondary HP counter
    var renderOffsetX: CGFloat = 0
    var renderOffsetY: CGFloat = 0
    var flipX: Bool = false
    var flipY: Bool = false
    var prevX: CGFloat = 0
    var prevY: CGFloat = 0
    var hasPrev: Bool = false
    var waveGroupId: Int = 0
    var didPartingShot: Bool = false
    var isFree: Bool = false

    init(
        id: Int,
        node: SKSpriteNode,
        shadowNode: SKSpriteNode?,
        x: CGFloat,
        y: CGFloat,
        waveGroupId: Int = 0
    ) {
        self.id = id
        self.node = node
        self.shadowNode = shadowNode
        self.x = x
        self.y = y
        self.prevX = x
        self.prevY = y
        self.waveGroupId = waveGroupId
    }

    func updatePrev() {
        prevX = x
        prevY = y
        hasPrev = true
    }

    /// Compass-style angle (`0 = up`, `90 = right`, `180 = down`, `270 = left`) of the last movement vector,
    /// matching `GameObj::velocityAngleDeg()` in `GameObj.h`.
    func velocityAngleDeg() -> CGFloat {
        guard hasPrev else { return 0 }
        let dx = x - prevX
        let dy = y - prevY
        if dx == 0 && dy == 0 { return 0 }
        var a = atan2(dx, -dy) * 180.0 / .pi
        if a < 0 { a += 360.0 }
        return a
    }
}

/// Runtime entity representing an enemy projectile (`Shot` in `Shot.h`).
final class EnemyShot {
    var weaponId: Int // 23=dot, 24=energy, 25..27=bone, 29..31=arrow, 32=axe, 33=scythe
    let node: SKSpriteNode
    var x: CGFloat
    var y: CGFloat
    var speedX: CGFloat
    var speedY: CGFloat
    var gpr1: Int = 0
    var rotQuarterTurns: Int = 0
    var isFree: Bool = false
    /// Scythe (`33`): orbit center, current angle (degrees) and per-tick angle step (`±1`).
    var orbitCenter: CGPoint?
    var orbitAngle: CGFloat = 0
    var orbitStep: CGFloat = 1
    /// Stage 4 fireball (`28`): lands once it falls to this Y, then burns in place as `35` for `burnTicks` frames.
    var stopAtY: CGFloat?
    var burnTicks: Int = 0

    init(
        weaponId: Int,
        node: SKSpriteNode,
        x: CGFloat,
        y: CGFloat,
        speedX: CGFloat,
        speedY: CGFloat
    ) {
        self.weaponId = weaponId
        self.node = node
        self.x = x
        self.y = y
        self.speedX = speedX
        self.speedY = speedY
    }
}

/// Delayed wave spawn item (`QueuedAction` in `ActionQueueSystem.h`).
final class QueuedSpawnAction {
    var execCount: Int
    let objId: Int
    let x: CGFloat
    let y: CGFloat
    let objCfg: Int
    let delayMs: Int
    var nextExecMs: Int
    let waveGroupId: Int

    init(
        execCount: Int,
        objId: Int,
        x: CGFloat,
        y: CGFloat,
        objCfg: Int,
        delayMs: Int,
        nextExecMs: Int,
        waveGroupId: Int
    ) {
        self.execCount = execCount
        self.objId = objId
        self.x = x
        self.y = y
        self.objCfg = objCfg
        self.delayMs = delayMs
        self.nextExecMs = nextExecMs
        self.waveGroupId = waveGroupId
    }
}

/// Tracks a spawned enemy wave to evaluate the Last Unit Rule (`Regra da Última Unidade`).
final class EnemyWaveTracker {
    let waveGroupId: Int
    let objId: Int
    var totalUnits: Int
    var killedUnits: Int = 0
    var escapedUnits: Int = 0
    var bonusAwarded: Bool = false

    init(waveGroupId: Int, objId: Int, totalUnits: Int) {
        self.waveGroupId = waveGroupId
        self.objId = objId
        self.totalUnits = totalUnits
    }
}

/// Runtime state for the current stage boss (`BossSystem.cpp` in `knightmare-raylib`).
final class StageBossRuntime {
    enum Status: Int {
        case notSpawned = 0
        case dying = 1
        case active = 2
        case waiting = 3
    }

    var status: Status = .notSpawned
    var x: CGFloat = 108
    var y: CGFloat = -24
    var hp: Int = 20
    var maxHp: Int = 20
    var stepTick: Int = 0
    var targetX: CGFloat = 112
    var deathBlinksRemaining: Int = 0
    var nextBlinkTimeMs: Int = 0
    var portalStartMs: Int = 0
    var isPortalActive: Bool = false
    var wipeStep: Int = 0
    /// Lissajous phases in degrees (Stage 2 boss, body `gpr2` / `gpr3`).
    var phaseX: CGFloat = 0
    var phaseY: CGFloat = 0
    /// Horizontal offset (px) into `bosses.png` for the current damage skin (Stage 2 boss).
    var skinOffsetX: Int = 0
    /// Ground shadow, drawn at `shadowOffset` from the body; its Y is pinned once the boss activates.
    var shadowNode: SKSpriteNode?
    var shadowOffset: CGPoint = .zero
    var shadowFixedY: CGFloat?
    /// Stage 3 boss: damage phase (`2...4`, picks the eye colour) and whether the folded wings block shots.
    var phase: Int = 2
    var isShielded: Bool = false
    /// Stage 5 boss: remaining dash (`body->gpr3`): its sign is the direction, it decays by 1 per tick toward 0.
    var dashVelocity: CGFloat = 0
    /// Stage 7 boss: flight direction (math angle in degrees, y pointing down).
    var heading: CGFloat = 0

    var node: SKSpriteNode?

    func reset() {
        phaseX = 0
        phaseY = 0
        skinOffsetX = 0
        shadowNode?.removeFromParent()
        shadowNode = nil
        shadowOffset = .zero
        shadowFixedY = nil
        phase = 2
        isShielded = false
        dashVelocity = 0
        heading = 0
        status = .notSpawned
        x = 108
        y = -24
        hp = 20
        maxHp = 20
        stepTick = 0
        targetX = 112
        deathBlinksRemaining = 0
        nextBlinkTimeMs = 0
        portalStartMs = 0
        isPortalActive = false
        wipeStep = 0
        node?.removeFromParent()
        node = nil
    }
}

/// Ground fissure opened by the Stage 6 boss's stomp (object `49` in `knightmare-raylib`): a crack that grows
/// downward from the boss's feet, 8 px per step up to 96 px, kills Popolon on contact and then closes.
final class GroundFissure {
    static let maxGrowthSteps = 12
    static let lifetimeSteps = 22

    let node: SKSpriteNode
    let x: CGFloat
    let y: CGFloat
    var step: Int = 0
    var isFree: Bool = false

    init(node: SKSpriteNode, x: CGFloat, y: CGFloat) {
        self.node = node
        self.x = x
        self.y = y
    }

    /// Current crack length in px (`8 + min(96, 8 * step)`, `ObjectSystem::animateObjects` case 49).
    var length: CGFloat {
        8 + 8 * CGFloat(min(step, Self.maxGrowthSteps))
    }
}
