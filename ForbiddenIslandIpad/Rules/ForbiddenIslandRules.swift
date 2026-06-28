import Foundation

public enum Direction: Int, CaseIterable, Sendable {
    case up = 0
    case upRight = 1
    case right = 2
    case downRight = 3
    case down = 4
    case downLeft = 5
    case left = 6
    case upLeft = 7
    case current = 8

    public var offset: Int {
        switch self {
        case .up: -6
        case .upRight: -5
        case .right: 1
        case .downRight: 7
        case .down: 6
        case .downLeft: 5
        case .left: -1
        case .upLeft: -7
        case .current: 0
        }
    }
}

public enum Role: Int, CaseIterable, Sendable {
    case engineer = 1
    case explorer = 2
    case pilot = 3
    case navigator = 4
    case diver = 5
    case messenger = 6

    public var name: String {
        switch self {
        case .engineer: "Engineer"
        case .explorer: "Explorer"
        case .pilot: "Pilot"
        case .navigator: "Navigator"
        case .diver: "Diver"
        case .messenger: "Messenger"
        }
    }
}

public enum Treasure: Int, CaseIterable, Sendable {
    case fire = 1
    case water = 2
    case wind = 3
    case earth = 4
}

public enum TreasureCard: Equatable, Sendable {
    case treasure(Treasure)
    case helicopter
    case sandbag
    case watersRise

    public var legacyValue: Int {
        switch self {
        case .treasure(let treasure): treasure.rawValue
        case .helicopter: 5
        case .sandbag: 6
        case .watersRise: 7
        }
    }
}

public enum TileState: Int, Sendable {
    case sunk = 0
    case flooded = 1
    case dry = 2

    mutating func flood() {
        self = switch self {
        case .dry: .flooded
        case .flooded, .sunk: .sunk
        }
    }

    mutating func shoreUp() {
        if self == .flooded {
            self = .dry
        }
    }
}

public enum TileKind: String, CaseIterable, Sendable {
    case bronzeGate = "BG"
    case copperGate = "CG"
    case foolsLanding = "FL"
    case goldGate = "GG"
    case ironGate = "IG"
    case silverGate = "SG"
    case caveOfEmbers = "CE"
    case caveOfShadows = "CS"
    case coralPalace = "CP"
    case tidalPalace = "TP"
    case howlingGarden = "HG"
    case whisperingGarden = "WG"
    case templeOfTheMoon = "TM"
    case templeOfTheSun = "TS"
    case breakersBridge = "BB"
    case cliffsOfAbandon = "CA"
    case crimsonForest = "CF"
    case dunesOfDeception = "DD"
    case lostLagoon = "LL"
    case mistyMarsh = "MM"
    case observatory = "Ob"
    case phantomRock = "PR"
    case twilightHollow = "TH"
    case watchtower = "Wt"

    public static let legacyOrder: [TileKind] = [
        .bronzeGate, .copperGate, .foolsLanding, .goldGate, .ironGate, .silverGate,
        .caveOfEmbers, .caveOfShadows, .coralPalace, .tidalPalace,
        .howlingGarden, .whisperingGarden, .templeOfTheMoon, .templeOfTheSun,
        .breakersBridge, .cliffsOfAbandon, .crimsonForest, .dunesOfDeception,
        .lostLagoon, .mistyMarsh, .observatory, .phantomRock, .twilightHollow, .watchtower
    ]

    public var startingRole: Role? {
        switch self {
        case .bronzeGate: .engineer
        case .copperGate: .explorer
        case .foolsLanding: .pilot
        case .goldGate: .navigator
        case .ironGate: .diver
        case .silverGate: .messenger
        default: nil
        }
    }

    public var treasure: Treasure? {
        switch self {
        case .caveOfEmbers, .caveOfShadows: .fire
        case .coralPalace, .tidalPalace: .water
        case .howlingGarden, .whisperingGarden: .wind
        case .templeOfTheMoon, .templeOfTheSun: .earth
        default: nil
        }
    }

    public var name: String {
        switch self {
        case .bronzeGate: "Bronze Gate"
        case .copperGate: "Copper Gate"
        case .foolsLanding: "Fools' Landing"
        case .goldGate: "Gold Gate"
        case .ironGate: "Iron Gate"
        case .silverGate: "Silver Gate"
        case .caveOfEmbers: "Cave of Embers"
        case .caveOfShadows: "Cave of Shadows"
        case .coralPalace: "Coral Palace"
        case .tidalPalace: "Tidal Palace"
        case .howlingGarden: "Howling Garden"
        case .whisperingGarden: "Whispering Garden"
        case .templeOfTheMoon: "Temple of the Moon"
        case .templeOfTheSun: "Temple of the Sun"
        case .breakersBridge: "Breakers Bridge"
        case .cliffsOfAbandon: "Cliffs of Abandon"
        case .crimsonForest: "Crimson Forest"
        case .dunesOfDeception: "Dunes of Deception"
        case .lostLagoon: "Lost Lagoon"
        case .mistyMarsh: "Misty Marsh"
        case .observatory: "Observatory"
        case .phantomRock: "Phantom Rock"
        case .twilightHollow: "Twilight Hollow"
        case .watchtower: "Watchtower"
        }
    }
}

public struct IslandTile: Equatable, Identifiable, Sendable {
    public var id: TileKind { kind }
    public var kind: TileKind
    public var state: TileState

    public init(kind: TileKind, state: TileState = .dry) {
        self.kind = kind
        self.state = state
    }
}

public struct Player: Equatable, Identifiable, Sendable {
    public var id: Int
    public var role: Role
    public var location: Int
    public var actionsRemaining: Int
    public var hand: [TreasureCard]

    public init(id: Int, role: Role, location: Int, actionsRemaining: Int = 3, hand: [TreasureCard] = []) {
        self.id = id
        self.role = role
        self.location = location
        self.actionsRemaining = actionsRemaining
        self.hand = hand
    }
}

public enum MoveCost: Equatable, Sendable {
    case blocked
    case free
    case action
}

public enum GameLoss: Equatable, Sendable {
    case foolsLandingSunk
    case treasureUnavailable(Treasure)
    case waterLevelOverflow
    case playerDrowned(Int)
    case noPlayers
}

public enum DrawTreasureResult: Equatable, Sendable {
    case card(TreasureCard)
    case watersRise
}

public struct GameState: Equatable, Sendable {
    public static let validSquares: [Int] = [
        2, 3, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17,
        18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 32, 33
    ]

    public static let invalidSquares: Set<Int> = [
        0, 1, 4, 5, 6, 11, 24, 29, 30, 31, 34, 35
    ]

    public static let maximumHandSize = 5

    public static let floodDrawsByWaterLevel = [2, 2, 3, 3, 3, 4, 4, 5, 5, 5]

    public var tilesByLocation: [Int: IslandTile]
    public var floodDeck: [TileKind]
    public var floodDiscard: [TileKind]
    public var floodOut: [TileKind]
    public var treasureDeck: [TreasureCard]
    public var treasureDiscard: [TreasureCard]
    public var players: [Player]
    public var activePlayerIndex: Int
    public var waterLevel: Int
    public var collectedTreasures: Set<Treasure>
    public var totalFloodCardsFlipped: Int
    public var gameStarted: Bool
    public var engineerHasPendingShoreUp: Bool
    public var pilotHasFlownThisTurn: Bool
    public var helicopterLiftPlayed: Bool

    public init(
        tilesByLocation: [Int: IslandTile],
        floodDeck: [TileKind],
        floodDiscard: [TileKind] = [],
        floodOut: [TileKind] = [],
        treasureDeck: [TreasureCard] = GameState.makeTreasureDeck(),
        treasureDiscard: [TreasureCard] = [],
        players: [Player] = [],
        activePlayerIndex: Int = 0,
        waterLevel: Int = 1,
        collectedTreasures: Set<Treasure> = [],
        totalFloodCardsFlipped: Int = 0,
        gameStarted: Bool = false,
        engineerHasPendingShoreUp: Bool = false,
        pilotHasFlownThisTurn: Bool = false,
        helicopterLiftPlayed: Bool = false
    ) {
        self.tilesByLocation = tilesByLocation
        self.floodDeck = floodDeck
        self.floodDiscard = floodDiscard
        self.floodOut = floodOut
        self.treasureDeck = treasureDeck
        self.treasureDiscard = treasureDiscard
        self.players = players
        self.activePlayerIndex = activePlayerIndex
        self.waterLevel = waterLevel
        self.collectedTreasures = collectedTreasures
        self.totalFloodCardsFlipped = totalFloodCardsFlipped
        self.gameStarted = gameStarted
        self.engineerHasPendingShoreUp = engineerHasPendingShoreUp
        self.pilotHasFlownThisTurn = pilotHasFlownThisTurn
        self.helicopterLiftPlayed = helicopterLiftPlayed
    }

    public static func newGame<R: RandomNumberGenerator>(using generator: inout R) -> GameState {
        var tileKinds = TileKind.legacyOrder
        tileKinds.shuffle(using: &generator)

        var tiles: [Int: IslandTile] = [:]
        for (location, kind) in zip(validSquares, tileKinds) {
            tiles[location] = IslandTile(kind: kind)
        }

        var floodDeck = TileKind.legacyOrder
        floodDeck.shuffle(using: &generator)

        var treasureDeck = makeTreasureDeck()
        treasureDeck.shuffle(using: &generator)

        return GameState(
            tilesByLocation: tiles,
            floodDeck: floodDeck,
            treasureDeck: treasureDeck
        )
    }

    public static func makeTreasureDeck() -> [TreasureCard] {
        var cards: [TreasureCard] = []
        Treasure.allCases.forEach { treasure in
            cards.append(contentsOf: Array(repeating: .treasure(treasure), count: 5))
        }
        cards.append(contentsOf: Array(repeating: .helicopter, count: 3))
        cards.append(contentsOf: Array(repeating: .sandbag, count: 2))
        cards.append(contentsOf: Array(repeating: .watersRise, count: 3))
        return cards
    }

    public mutating func createPlayers<R: RandomNumberGenerator>(count: Int, using generator: inout R) {
        var roles = Role.allCases
        players = []

        for playerNumber in 0..<min(count, roles.count) {
            let selectedIndex = Int.random(in: roles.indices, using: &generator)
            let role = roles.remove(at: selectedIndex)
            let startLocation = location(forStartingRole: role) ?? Self.validSquares[0]
            players.append(Player(id: playerNumber, role: role, location: startLocation))
        }
    }

    public mutating func dealInitialTreasureCards(cardsPerPlayer: Int = 2) {
        guard cardsPerPlayer > 0 else {
            return
        }

        for _ in 0..<cardsPerPlayer {
            for player in players {
                _ = drawTreasureCard(for: player.id)
            }
        }
    }

    public func location(forStartingRole role: Role) -> Int? {
        tilesByLocation.first { $0.value.kind.startingRole == role }?.key
    }

    public func tileName(at location: Int) -> String {
        guard let tile = tilesByLocation[location] else {
            return "Location \(location)"
        }

        return "\(tile.kind.name) (\(location))"
    }

    public var activePlayer: Player? {
        players.indices.contains(activePlayerIndex) ? players[activePlayerIndex] : nil
    }

    public var floodDrawCount: Int {
        let index = max(0, min(waterLevel, Self.floodDrawsByWaterLevel.count - 1))
        return Self.floodDrawsByWaterLevel[index]
    }

    public func destination(from location: Int, direction: Direction) -> Int {
        location + direction.offset
    }

    public func isBoardLocation(_ location: Int) -> Bool {
        Self.validSquares.contains(location)
    }

    public func isLegalStep(from location: Int, direction: Direction, role: Role) -> Bool {
        if direction == .current {
            return true
        }

        if (location == 17 && direction == .right) || (location == 18 && direction == .left) {
            return false
        }

        if role == .explorer {
            if (location == 12 || location == 18) && direction == .downLeft {
                return false
            }
            if (location == 17 || location == 23) && direction == .upRight {
                return false
            }
        }

        return true
    }

    public func movementCost(for player: Player, direction: Direction) -> MoveCost {
        guard direction != .current else { return .blocked }

        let allowedDirections: Set<Direction> = player.role == .explorer
            ? Set(Direction.allCases.filter { $0 != .current })
            : [.up, .right, .down, .left]

        guard allowedDirections.contains(direction) else {
            return .blocked
        }

        guard isLegalStep(from: player.location, direction: direction, role: player.role) else {
            return .blocked
        }

        let destination = destination(from: player.location, direction: direction)
        guard isBoardLocation(destination), let destinationTile = tilesByLocation[destination] else {
            return .blocked
        }

        if player.role == .diver && destinationTile.state != .dry {
            return .free
        }

        return destinationTile.state == .sunk ? .blocked : .action
    }

    public func swimTargets(for player: Player) -> [Int] {
        if player.role == .pilot {
            return tilesByLocation
                .filter { $0.key != player.location && $0.value.state != .sunk }
                .map(\.key)
                .sorted()
        }

        if player.role == .diver {
            return reachableDiverDestinations(from: player.location)
        }

        let directions: [Direction] = player.role == .explorer
            ? [.up, .upRight, .right, .downRight, .down, .downLeft, .left, .upLeft]
            : [.up, .right, .down, .left]

        return directions.compactMap { direction in
            guard isLegalStep(from: player.location, direction: direction, role: player.role) else {
                return nil
            }

            let destination = destination(from: player.location, direction: direction)
            guard let tile = tilesByLocation[destination], tile.state != .sunk else {
                return nil
            }

            return destination
        }
    }

    @discardableResult
    public mutating func movePlayer(id playerID: Int, direction: Direction) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else {
            return false
        }

        let player = players[index]
        let cost = movementCost(for: player, direction: direction)
        guard cost != .blocked else {
            return false
        }

        players[index].location = destination(from: player.location, direction: direction)
        if cost == .action {
            players[index].actionsRemaining -= 1
        }
        return true
    }

    @discardableResult
    public mutating func movePlayerToSafety(id playerID: Int, location: Int) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }),
              swimTargets(for: players[index]).contains(location) else {
            return false
        }

        players[index].location = location
        return true
    }

    public func pilotFlyTargets(for player: Player) -> [Int] {
        guard player.role == .pilot, !pilotHasFlownThisTurn else {
            return []
        }

        return tilesByLocation
            .filter { $0.key != player.location && $0.value.state != .sunk }
            .map(\.key)
            .sorted()
    }

    @discardableResult
    public mutating func pilotFly(playerID: Int, destination: Int) -> Bool {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              pilotFlyTargets(for: players[playerIndex]).contains(destination),
              players[playerIndex].actionsRemaining > 0 else {
            return false
        }

        players[playerIndex].location = destination
        players[playerIndex].actionsRemaining -= 1
        pilotHasFlownThisTurn = true
        return true
    }

    public func navigatorMoveTargets(for target: Player) -> [Int] {
        let directions: [Direction] = target.role == .explorer
            ? [.up, .upRight, .right, .downRight, .down, .downLeft, .left, .upLeft]
            : [.up, .right, .down, .left]

        return directions.compactMap { direction in
            guard movementCost(for: target, direction: direction) != .blocked else {
                return nil
            }
            return destination(from: target.location, direction: direction)
        }
    }

    @discardableResult
    public mutating func navigatorMovePlayer(targetID: Int, destination: Int) -> Bool {
        guard let targetIndex = players.firstIndex(where: { $0.id == targetID }),
              navigatorMoveTargets(for: players[targetIndex]).contains(destination) else {
            return false
        }

        players[targetIndex].location = destination
        return true
    }

    @discardableResult
    public mutating func spendAction(playerID: Int) -> Bool {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              players[playerIndex].actionsRemaining > 0 else {
            return false
        }

        players[playerIndex].actionsRemaining -= 1
        return true
    }

    public func shoreUpTargets(for player: Player) -> [Int] {
        let directions: [Direction] = player.role == .explorer
            ? [.up, .upRight, .right, .downRight, .down, .downLeft, .left, .upLeft, .current]
            : [.up, .right, .down, .left, .current]

        return directions.compactMap { direction in
            guard isLegalStep(from: player.location, direction: direction, role: player.role) else {
                return nil
            }
            let location = destination(from: player.location, direction: direction)
            guard let tile = tilesByLocation[location], tile.state == .flooded else {
                return nil
            }
            return location
        }
    }

    @discardableResult
    public mutating func shoreUp(playerID: Int, location: Int) -> Bool {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              shoreUpTargets(for: players[playerIndex]).contains(location),
              tilesByLocation[location]?.state == .flooded else {
            return false
        }

        tilesByLocation[location]?.state.shoreUp()

        if players[playerIndex].role == .engineer && !engineerHasPendingShoreUp {
            engineerHasPendingShoreUp = true
        } else {
            engineerHasPendingShoreUp = false
            players[playerIndex].actionsRemaining -= 1
        }

        return true
    }

    public mutating func finishEngineerShoreUp(playerID: Int) {
        guard engineerHasPendingShoreUp,
              let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              players[playerIndex].role == .engineer else {
            return
        }

        engineerHasPendingShoreUp = false
        players[playerIndex].actionsRemaining -= 1
    }

    @discardableResult
    public mutating func floodNextTile() -> Int? {
        if floodDeck.isEmpty {
            recycleFloodDiscard()
        }

        guard let kind = floodDeck.popLast(),
              let location = tilesByLocation.first(where: { $0.value.kind == kind })?.key else {
            return nil
        }

        tilesByLocation[location]?.state.flood()
        if tilesByLocation[location]?.state == .sunk {
            floodOut.append(kind)
        } else {
            floodDiscard.append(kind)
        }

        totalFloodCardsFlipped += 1
        if totalFloodCardsFlipped > 5 {
            gameStarted = true
        }

        return location
    }

    public mutating func recycleFloodDiscard() {
        floodDeck.append(contentsOf: floodDiscard)
        floodDiscard.removeAll()
        floodDeck.shuffle()
    }

    public mutating func watersRise() {
        floodDiscard.shuffle()
        floodDeck.append(contentsOf: floodDiscard)
        floodDiscard.removeAll()
        waterLevel += 1
    }

    public mutating func drawTreasureCard(for playerID: Int) -> DrawTreasureResult? {
        if treasureDeck.isEmpty {
            treasureDiscard.shuffle()
            treasureDeck = treasureDiscard
            treasureDiscard.removeAll()
        }

        guard let card = treasureDeck.popLast() else {
            return nil
        }

        if card == .watersRise && !gameStarted {
            treasureDeck.insert(card, at: 0)
            treasureDeck.shuffle()
            return drawTreasureCard(for: playerID)
        }

        if card == .watersRise {
            treasureDiscard.append(card)
            watersRise()
            return .watersRise
        }

        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }) else {
            treasureDiscard.append(card)
            return nil
        }

        players[playerIndex].hand.append(card)
        return .card(card)
    }

    @discardableResult
    public mutating func discardTreasureCard(playerID: Int, cardIndex: Int) -> TreasureCard? {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              players[playerIndex].hand.indices.contains(cardIndex) else {
            return nil
        }

        let card = players[playerIndex].hand.remove(at: cardIndex)
        treasureDiscard.append(card)
        return card
    }

    public func collectableTreasure(for player: Player) -> Treasure? {
        guard let tile = tilesByLocation[player.location],
              tile.state != .sunk,
              let treasure = tile.kind.treasure,
              !collectedTreasures.contains(treasure) else {
            return nil
        }

        let matchingCards = player.hand.filter { $0 == .treasure(treasure) }.count
        return matchingCards >= 4 ? treasure : nil
    }

    @discardableResult
    public mutating func collectTreasure(playerID: Int) -> Treasure? {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              let treasure = collectableTreasure(for: players[playerIndex]) else {
            return nil
        }

        var removed = 0
        players[playerIndex].hand.removeAll { card in
            guard card == .treasure(treasure), removed < 4 else {
                return false
            }
            removed += 1
            treasureDiscard.append(card)
            return true
        }
        collectedTreasures.insert(treasure)
        players[playerIndex].actionsRemaining -= 1
        return treasure
    }

    @discardableResult
    public mutating func transferTreasure(from giverID: Int, to receiverID: Int, cardIndex: Int) -> Bool {
        guard let giverIndex = players.firstIndex(where: { $0.id == giverID }),
              let receiverIndex = players.firstIndex(where: { $0.id == receiverID }),
              players[giverIndex].hand.indices.contains(cardIndex),
              giverID != receiverID else {
            return false
        }

        let sameTile = players[giverIndex].location == players[receiverIndex].location
        let messenger = players[giverIndex].role == .messenger
        guard sameTile || messenger else {
            return false
        }

        let card = players[giverIndex].hand.remove(at: cardIndex)
        players[receiverIndex].hand.append(card)
        players[giverIndex].actionsRemaining -= 1
        return true
    }

    @discardableResult
    public mutating func playSandbag(playerID: Int, cardIndex: Int, location: Int) -> Bool {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              players[playerIndex].hand.indices.contains(cardIndex),
              players[playerIndex].hand[cardIndex] == .sandbag,
              tilesByLocation[location]?.state == .flooded else {
            return false
        }

        tilesByLocation[location]?.state.shoreUp()
        let card = players[playerIndex].hand.remove(at: cardIndex)
        treasureDiscard.append(card)
        helicopterLiftPlayed = true
        return true
    }

    @discardableResult
    public mutating func playHelicopter(playerID: Int, cardIndex: Int, movingPlayerIDs: [Int], destination: Int) -> Bool {
        guard let playerIndex = players.firstIndex(where: { $0.id == playerID }),
              players[playerIndex].hand.indices.contains(cardIndex),
              players[playerIndex].hand[cardIndex] == .helicopter,
              tilesByLocation[destination]?.state != .sunk,
              !movingPlayerIDs.isEmpty else {
            return false
        }

        for movingID in movingPlayerIDs {
            guard let movingIndex = players.firstIndex(where: { $0.id == movingID }) else {
                return false
            }
            players[movingIndex].location = destination
        }

        let card = players[playerIndex].hand.remove(at: cardIndex)
        treasureDiscard.append(card)
        return true
    }

    public mutating func nextPlayer() {
        guard !players.isEmpty else {
            activePlayerIndex = 0
            return
        }

        activePlayerIndex = (activePlayerIndex + 1) % players.count
        players[activePlayerIndex].actionsRemaining = 3
        engineerHasPendingShoreUp = false
        pilotHasFlownThisTurn = false
    }

    public func lossReason() -> GameLoss? {
        if players.isEmpty {
            return .noPlayers
        }

        if waterLevel > 8 {
            return .waterLevelOverflow
        }

        if tilesByLocation.values.contains(where: { $0.kind == .foolsLanding && $0.state == .sunk }) {
            return .foolsLandingSunk
        }

        for treasure in Treasure.allCases where !collectedTreasures.contains(treasure) {
            let remainingTreasureTiles = tilesByLocation.values.filter {
                $0.kind.treasure == treasure && $0.state != .sunk
            }
            if remainingTreasureTiles.isEmpty {
                return .treasureUnavailable(treasure)
            }
        }

        return nil
    }

    public func hasWon() -> Bool {
        guard collectedTreasures.count == Treasure.allCases.count,
              helicopterLiftPlayed,
              let foolsLanding = tilesByLocation.first(where: { $0.value.kind == .foolsLanding }) else {
            return false
        }

        return players.allSatisfy { $0.location == foolsLanding.key }
    }

    public func reachableDiverDestinations(from startLocation: Int) -> [Int] {
        var destinations: Set<Int> = []
        var queue: [Int] = []
        var visited: Set<Int> = []

        func enqueue(_ location: Int) {
            guard !visited.contains(location) else {
                return
            }
            visited.insert(location)
            queue.append(location)
        }

        for direction in [Direction.up, .right, .down, .left] {
            guard isLegalStep(from: startLocation, direction: direction, role: .diver) else {
                continue
            }
            let nextLocation = destination(from: startLocation, direction: direction)
            guard let tile = tilesByLocation[nextLocation] else {
                continue
            }
            if tile.state != .sunk {
                destinations.insert(nextLocation)
            }
            if tile.state != .dry {
                enqueue(nextLocation)
            }
        }

        var index = 0
        while index < queue.count {
            let current = queue[index]
            index += 1

            for direction in [Direction.up, .right, .down, .left] {
                guard isLegalStep(from: current, direction: direction, role: .diver) else {
                    continue
                }
                let nextLocation = destination(from: current, direction: direction)
                guard nextLocation != startLocation, let tile = tilesByLocation[nextLocation] else {
                    continue
                }
                if tile.state != .sunk {
                    destinations.insert(nextLocation)
                }
                if tile.state != .dry {
                    enqueue(nextLocation)
                }
            }
        }

        return destinations.sorted()
    }
}

public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}
