import Combine
import Foundation

public enum GameOutcome: Equatable, Sendable {
    case won
    case lost(GameLoss)
}

public struct GameLogEntry: Identifiable, Equatable, Sendable {
    public let id: Int
    public let symbol: String
    public let message: String
}

public enum PlayerAction: Equatable, Sendable {
    case move
    case shoreUp
    case giveTreasure
    case collectTreasure
    case special
    case endTurn
}

public enum HandLimitContinuation: Equatable, Sendable {
    case drawingTreasure(playerID: Int, drawnCount: Int)
    case flooding
    case resume(PostHandLimitResume)
}

public enum PostHandLimitResume: Equatable, Sendable {
    case playerAction(playerID: Int)
    case drawingTreasure(playerID: Int, drawnCount: Int)
    case flooding(remaining: Int, lastFloodedLocation: Int?)
}

public struct HandLimitCardSelection: Equatable, Sendable {
    public let playerID: Int
    public let cardIndex: Int
}

public enum FloodContinuation: Equatable, Sendable {
    case initialFlood(remainingBeforeFlood: Int, lastFloodedLocation: Int?)
    case flooding(remainingBeforeFlood: Int, lastFloodedLocation: Int?)
}

public enum GamePhase: Equatable, Sendable {
    case choosePlayerCount
    case chooseDifficulty(playerCount: Int)
    case initialFlood(remaining: Int, lastFloodedLocation: Int?)
    case playerAction(playerID: Int)
    case selectingMove(playerID: Int, targets: [Int])
    case selectingShoreUp(playerID: Int, targets: [Int])
    case selectingPilotFly(playerID: Int, targets: [Int])
    case selectingNavigatorTarget(playerID: Int, targetPlayerIDs: [Int])
    case selectingNavigatorMove(playerID: Int, targetPlayerID: Int, remainingSteps: Int, hasMoved: Bool, targets: [Int])
    case selectingTreasureReceiver(playerID: Int, receiverIDs: [Int])
    case selectingTreasureToGive(playerID: Int, receiverID: Int, receiverIDs: [Int])
    case selectingSandbagTarget(playerID: Int, cardIndex: Int, targets: [Int])
    case selectingHelicopterSource(playerID: Int, cardIndex: Int, sourceLocations: [Int])
    case selectingHelicopterPassengers(playerID: Int, cardIndex: Int, candidatePlayerIDs: [Int], selectedPlayerIDs: [Int])
    case selectingHelicopterDestination(playerID: Int, cardIndex: Int, movingPlayerIDs: [Int], targets: [Int])
    case drawingTreasure(playerID: Int, drawnCount: Int)
    case resolvingWatersRise(playerID: Int, drawnCount: Int)
    case discardingHandLimit(playerID: Int, continuation: HandLimitContinuation)
    case swimmingToSafety(playerID: Int, targets: [Int], continuation: FloodContinuation)
    case flooding(remaining: Int, lastFloodedLocation: Int?)
    case gameOver(GameOutcome)
}

public final class GameViewModel: ObservableObject {
    @Published public private(set) var game: GameState
    @Published public private(set) var phase: GamePhase
    @Published public private(set) var eventLog: [GameLogEntry] = []
    @Published public private(set) var selectedHandLimitCard: HandLimitCardSelection?

    private var generator: SeededGenerator
    private var nextLogID = 0
    private var suspendedPhases: [GamePhase] = []

    public init(seed: UInt64 = 1) {
        var generator = SeededGenerator(seed: seed)
        self.game = GameState.newGame(using: &generator)
        self.phase = .choosePlayerCount
        self.generator = generator
    }

    public init(game: GameState, phase: GamePhase = .choosePlayerCount, seed: UInt64 = 1) {
        self.game = game
        self.phase = phase
        self.generator = SeededGenerator(seed: seed)
    }

    public var activePlayer: Player? {
        game.activePlayer
    }

    public var selectableTileLocations: [Int] {
        switch phase {
        case .selectingMove(_, let targets),
             .selectingShoreUp(_, let targets),
             .selectingPilotFly(_, let targets),
             .selectingNavigatorMove(_, _, _, _, let targets),
             .selectingSandbagTarget(_, _, let targets),
             .selectingHelicopterSource(_, _, let targets),
             .selectingHelicopterDestination(_, _, _, let targets),
             .swimmingToSafety(_, let targets, _):
            targets
        default:
            []
        }
    }

    public var canCollectTreasure: Bool {
        guard let activePlayer else {
            return false
        }
        return game.collectableTreasure(for: activePlayer) != nil
    }

    public var canGiveTreasure: Bool {
        guard let activePlayer else {
            return false
        }
        return !activePlayer.hand.isEmpty && !treasureReceiverIDs(for: activePlayer).isEmpty
    }

    public var canUseSpecialAction: Bool {
        guard case .playerAction(let playerID) = phase,
              let player = activePlayer,
              player.id == playerID,
              player.actionsRemaining > 0 else {
            return false
        }

        switch player.role {
        case .pilot:
            return !game.pilotFlyTargets(for: player).isEmpty
        case .navigator:
            return !navigatorTargetIDs(for: player).isEmpty
        default:
            return false
        }
    }

    public var canPlayReactionCards: Bool {
        game.gameStarted && !isGameOver
    }

    private var isGameOver: Bool {
        if case .gameOver = phase {
            return true
        }
        return false
    }

    public var canCancelSelection: Bool {
        switch phase {
        case .selectingMove,
             .selectingShoreUp,
             .selectingPilotFly,
             .selectingNavigatorTarget,
             .selectingTreasureReceiver,
             .selectingTreasureToGive,
             .selectingSandbagTarget,
             .selectingHelicopterSource,
             .selectingHelicopterPassengers,
             .selectingHelicopterDestination:
            return true
        case .discardingHandLimit:
            return selectedHandLimitCard != nil
        case .selectingNavigatorMove(_, _, _, let hasMoved, _):
            return !hasMoved
        default:
            return false
        }
    }

    public var latestTreasureDiscard: TreasureCard? {
        game.treasureDiscard.last(where: { $0 != .watersRise })
    }

    public var treasureDiscardTopCard: TreasureCard? {
        game.treasureDiscard.last
    }

    public var revealedTreasureCard: TreasureCard? {
        if case .resolvingWatersRise = phase {
            return .watersRise
        }
        return nil
    }

    public var latestFloodDiscard: TileKind? {
        game.floodDiscard.last ?? game.floodOut.last
    }

    public var recentEvents: [GameLogEntry] {
        Array(eventLog.suffix(12).reversed())
    }

    public func resetGame(seed: UInt64? = nil) {
        if let seed {
            generator = SeededGenerator(seed: seed)
        }

        game = GameState.newGame(using: &generator)
        phase = .choosePlayerCount
        eventLog.removeAll()
        nextLogID = 0
        suspendedPhases.removeAll()
        selectedHandLimitCard = nil
        log("New game ready.", symbol: "arrow.counterclockwise")
    }

    @discardableResult
    public func choosePlayerCount(_ count: Int) -> Bool {
        guard phase == .choosePlayerCount, (2...4).contains(count) else {
            return false
        }

        game.createPlayers(count: count, using: &generator)
        game.dealInitialTreasureCards()
        log("Selected \(count) players.", symbol: "person.3.fill")
        phase = .chooseDifficulty(playerCount: game.players.count)
        return true
    }

    @discardableResult
    public func chooseDifficulty(waterLevel: Int) -> Bool {
        guard case .chooseDifficulty = phase, (0...3).contains(waterLevel) else {
            return false
        }

        game.waterLevel = waterLevel
        log("Water level set to \(waterLevel).", symbol: "water.waves")
        phase = .initialFlood(remaining: 6, lastFloodedLocation: nil)
        return true
    }

    @discardableResult
    public func floodInitialTile() -> Int? {
        guard case .initialFlood(let remaining, _) = phase, remaining > 0 else {
            return nil
        }

        let location = game.floodNextTile()
        logFloodEvent(at: location)
        resolvePlayersInWaterOrContinue(
            .initialFlood(remainingBeforeFlood: remaining, lastFloodedLocation: location)
        )
        return location
    }

    @discardableResult
    public func selectAction(_ action: PlayerAction) -> Bool {
        guard case .playerAction(let playerID) = phase,
              let player = activePlayer,
              player.id == playerID else {
            return false
        }

        switch action {
        case .move:
            log("Selected move.", symbol: "figure.walk")
            phase = .selectingMove(playerID: playerID, targets: movementTargets(for: player))
            return true
        case .shoreUp:
            log("Selected shore up.", symbol: "hammer.fill")
            phase = .selectingShoreUp(playerID: playerID, targets: game.shoreUpTargets(for: player))
            return true
        case .collectTreasure:
            guard game.collectTreasure(playerID: playerID) != nil else {
                return false
            }
            log("\(player.role.name) collected treasure.", symbol: "cube.box.fill")
            advanceAfterAction()
            return true
        case .giveTreasure:
            let receiverIDs = treasureReceiverIDs(for: player)
            guard !receiverIDs.isEmpty else {
                return false
            }
            log("Selected give treasure.", symbol: "hand.raised.fill")
            phase = .selectingTreasureReceiver(playerID: playerID, receiverIDs: receiverIDs)
            return true
        case .endTurn:
            log("\(player.role.name) ended turn.", symbol: "arrow.turn.up.right")
            setActivePlayerActions(to: 0)
            beginTreasureDraw()
            return true
        case .special:
            log("Selected special action.", symbol: "sparkles")
            return beginSpecialAction(for: player)
        }
    }

    @discardableResult
    public func pilotFly(to location: Int) -> Bool {
        guard case .selectingPilotFly(let playerID, let targets) = phase,
              targets.contains(location),
              game.pilotFly(playerID: playerID, destination: location) else {
            return false
        }

        if let player = game.players.first(where: { $0.id == playerID }) {
            log("\(player.role.name) flew to \(game.tileName(at: location)).", symbol: "paperplane.fill")
        }
        advanceAfterAction()
        return true
    }

    @discardableResult
    public func selectNavigatorTarget(_ targetPlayerID: Int) -> Bool {
        guard case .selectingNavigatorTarget(let playerID, let targetPlayerIDs) = phase,
              targetPlayerIDs.contains(targetPlayerID),
              let target = game.players.first(where: { $0.id == targetPlayerID }) else {
            return false
        }

        let targets = game.navigatorMoveTargets(for: target)
        guard !targets.isEmpty else {
            return false
        }

        phase = .selectingNavigatorMove(
            playerID: playerID,
            targetPlayerID: targetPlayerID,
            remainingSteps: 2,
            hasMoved: false,
            targets: targets
        )
        return true
    }

    @discardableResult
    public func moveNavigatorTarget(to location: Int) -> Bool {
        guard case .selectingNavigatorMove(
            let playerID,
            let targetPlayerID,
            let remainingSteps,
            _,
            let targets
        ) = phase,
            remainingSteps > 0,
            targets.contains(location),
            game.navigatorMovePlayer(targetID: targetPlayerID, destination: location) else {
            return false
        }

        let nextRemainingSteps = remainingSteps - 1
        guard nextRemainingSteps > 0,
              let target = game.players.first(where: { $0.id == targetPlayerID }) else {
            return finishNavigatorMove(playerID: playerID)
        }

        let nextTargets = game.navigatorMoveTargets(for: target)
        if nextTargets.isEmpty {
            return finishNavigatorMove(playerID: playerID)
        }

        log("\(target.role.name) moved to \(game.tileName(at: location)).", symbol: "arrow.right")
        phase = .selectingNavigatorMove(
            playerID: playerID,
            targetPlayerID: targetPlayerID,
            remainingSteps: nextRemainingSteps,
            hasMoved: true,
            targets: nextTargets
        )
        return true
    }

    @discardableResult
    public func finishNavigatorMove() -> Bool {
        guard case .selectingNavigatorMove(let playerID, _, _, let hasMoved, _) = phase,
              hasMoved else {
            return false
        }

        return finishNavigatorMove(playerID: playerID)
    }

    @discardableResult
    public func selectTreasureReceiver(_ receiverID: Int) -> Bool {
        switch phase {
        case .selectingTreasureReceiver(let playerID, let receiverIDs):
            guard receiverIDs.contains(receiverID) else {
                return false
            }
            phase = .selectingTreasureToGive(playerID: playerID, receiverID: receiverID, receiverIDs: receiverIDs)
            return true
        case .selectingTreasureToGive(let playerID, _, let receiverIDs):
            guard receiverIDs.contains(receiverID) else {
                return false
            }
            phase = .selectingTreasureToGive(playerID: playerID, receiverID: receiverID, receiverIDs: receiverIDs)
            return true
        default:
            return false
        }
    }

    @discardableResult
    public func giveTreasure(cardIndex: Int) -> Bool {
        guard case .selectingTreasureToGive(let playerID, let receiverID, _) = phase,
              game.transferTreasure(from: playerID, to: receiverID, cardIndex: cardIndex) else {
            return false
        }

        if let giver = game.players.first(where: { $0.id == playerID }),
           let receiver = game.players.first(where: { $0.id == receiverID }) {
            log("\(giver.role.name) gave treasure to \(receiver.role.name).", symbol: "hand.raised.fill")
        }

        if let receiver = game.players.first(where: { $0.id == receiverID }),
           receiver.hand.count > GameState.maximumHandSize {
            phase = .discardingHandLimit(
                playerID: receiverID,
                continuation: .resume(postActionResume())
            )
            return true
        }

        advanceAfterAction()
        return true
    }

    @discardableResult
    public func moveActivePlayer(to location: Int) -> Bool {
        guard case .selectingMove(let playerID, let targets) = phase,
              targets.contains(location),
              let player = game.players.first(where: { $0.id == playerID }),
              let direction = direction(from: player.location, to: location) else {
            return false
        }

        guard game.movePlayer(id: playerID, direction: direction) else {
            return false
        }

        logMovement(playerID: playerID, destination: location)
        advanceAfterAction()
        return true
    }

    @discardableResult
    public func shoreUp(location: Int) -> Bool {
        guard case .selectingShoreUp(let playerID, let targets) = phase,
              targets.contains(location) else {
            return false
        }

        guard game.shoreUp(playerID: playerID, location: location) else {
            return false
        }

        if let player = game.players.first(where: { $0.id == playerID }) {
            log("\(player.role.name) shored up \(game.tileName(at: location)).", symbol: "hammer.fill")
        }
        if let player = game.players.first(where: { $0.id == playerID }),
           game.engineerHasPendingShoreUp,
           !game.shoreUpTargets(for: player).isEmpty {
            phase = .selectingShoreUp(playerID: playerID, targets: game.shoreUpTargets(for: player))
        } else {
            game.finishEngineerShoreUp(playerID: playerID)
            advanceAfterAction()
        }

        return true
    }

    @discardableResult
    public func playTreasureCard(playerID: Int, cardIndex: Int) -> Bool {
        guard let player = game.players.first(where: { $0.id == playerID }),
              player.hand.indices.contains(cardIndex) else {
            return false
        }

        let card = player.hand[cardIndex]
        if card == .sandbag || card == .helicopter {
            guard canPlayReactionCards else {
                return false
            }
        }

        switch card {
        case .sandbag:
            let targets = floodedTileLocations()
            guard !targets.isEmpty else {
                return false
            }
            beginReactionSelectionIfNeeded(for: playerID)
            phase = .selectingSandbagTarget(playerID: playerID, cardIndex: cardIndex, targets: targets)
            return true
        case .helicopter:
            let sourceLocations = helicopterSourceLocations()
            guard !sourceLocations.isEmpty else {
                return false
            }
            beginReactionSelectionIfNeeded(for: playerID)
            phase = .selectingHelicopterSource(
                playerID: playerID,
                cardIndex: cardIndex,
                sourceLocations: sourceLocations
            )
            return true
        case .treasure, .watersRise:
            guard case .playerAction(let activePlayerID) = phase,
                  activePlayerID == playerID else {
                return false
            }
            return false
        }
    }

    @discardableResult
    public func playSandbag(at location: Int) -> Bool {
        guard case .selectingSandbagTarget(let playerID, let cardIndex, let targets) = phase,
              targets.contains(location),
              game.playSandbag(playerID: playerID, cardIndex: cardIndex, location: location) else {
            return false
        }

        if let player = game.players.first(where: { $0.id == playerID }) {
            log("\(player.role.name) sandbagged \(game.tileName(at: location)).", symbol: "hand.raised.fill")
        }
        completeReactionOrAdvance()
        return true
    }

    @discardableResult
    public func selectHelicopterSource(_ location: Int) -> Bool {
        guard case .selectingHelicopterSource(let playerID, let cardIndex, let sourceLocations) = phase,
              sourceLocations.contains(location) else {
            return false
        }

        let candidatePlayerIDs = helicopterPassengerCandidates(at: location)
        guard !candidatePlayerIDs.isEmpty else {
            return false
        }

        phase = .selectingHelicopterPassengers(
            playerID: playerID,
            cardIndex: cardIndex,
            candidatePlayerIDs: candidatePlayerIDs,
            selectedPlayerIDs: []
        )
        return true
    }

    @discardableResult
    public func toggleHelicopterPassenger(_ passengerID: Int) -> Bool {
        guard case .selectingHelicopterPassengers(
            let playerID,
            let cardIndex,
            let candidatePlayerIDs,
            var selectedPlayerIDs
        ) = phase,
            candidatePlayerIDs.contains(passengerID) else {
            return false
        }

        if let existingIndex = selectedPlayerIDs.firstIndex(of: passengerID) {
            selectedPlayerIDs.remove(at: existingIndex)
        } else {
            selectedPlayerIDs.append(passengerID)
            selectedPlayerIDs.sort()
        }

        phase = .selectingHelicopterPassengers(
            playerID: playerID,
            cardIndex: cardIndex,
            candidatePlayerIDs: candidatePlayerIDs,
            selectedPlayerIDs: selectedPlayerIDs
        )
        return true
    }

    @discardableResult
    public func confirmHelicopterPassengers() -> Bool {
        guard case .selectingHelicopterPassengers(
            let playerID,
            let cardIndex,
            let candidatePlayerIDs,
            let selectedPlayerIDs
        ) = phase,
            !selectedPlayerIDs.isEmpty,
            selectedPlayerIDs.allSatisfy(candidatePlayerIDs.contains),
            let firstSelectedID = selectedPlayerIDs.first,
            let sourceLocation = game.players.first(where: { $0.id == firstSelectedID })?.location else {
            return false
        }

        let targets = helicopterDestinations(excluding: sourceLocation)
        guard !targets.isEmpty else {
            return false
        }

        phase = .selectingHelicopterDestination(
            playerID: playerID,
            cardIndex: cardIndex,
            movingPlayerIDs: selectedPlayerIDs,
            targets: targets
        )
        return true
    }

    @discardableResult
    public func playHelicopter(to location: Int) -> Bool {
        guard case .selectingHelicopterDestination(let playerID, let cardIndex, let movingPlayerIDs, let targets) = phase,
              targets.contains(location),
              game.playHelicopter(
                playerID: playerID,
                cardIndex: cardIndex,
                movingPlayerIDs: movingPlayerIDs,
                destination: location
              ) else {
            return false
        }

        let passengers = movingPlayerIDs
            .compactMap { id in game.players.first(where: { $0.id == id })?.role.name }
            .joined(separator: ", ")
        log("Helicopter moved \(passengers) to \(game.tileName(at: location)).", symbol: "airplane")
        completeReactionOrAdvance()
        return true
    }

    @discardableResult
    public func drawTreasureCard() -> DrawTreasureResult? {
        guard case .drawingTreasure(let playerID, let drawnCount) = phase else {
            return nil
        }

        let result = game.drawTreasureCard(for: playerID)

        switch result {
        case .watersRise:
            log("Waters Rise: water level \(game.waterLevel).", symbol: "water.waves")
            if let loss = game.lossReason() {
                logLoss(loss)
                phase = .gameOver(.lost(loss))
            } else {
                phase = .resolvingWatersRise(playerID: playerID, drawnCount: drawnCount)
            }
        case .card(let card):
            log("Drew \(treasureCardName(card)).", symbol: "rectangle.stack.fill")
            advanceAfterTreasureDraw(playerID: playerID, drawnCount: drawnCount + 1)
        case nil:
            break
        }

        return result
    }

    @discardableResult
    public func resolveWatersRise() -> Bool {
        guard case .resolvingWatersRise(let playerID, let drawnCount) = phase else {
            return false
        }

        log("Resolved Waters Rise.", symbol: "water.waves")
        advanceAfterTreasureDraw(playerID: playerID, drawnCount: drawnCount + 1)
        return true
    }

    @discardableResult
    public func floodNextTile() -> Int? {
        guard case .flooding(let remaining, _) = phase, remaining > 0 else {
            return nil
        }

        let location = game.floodNextTile()
        logFloodEvent(at: location)
        resolvePlayersInWaterOrContinue(.flooding(remainingBeforeFlood: remaining, lastFloodedLocation: location))
        return location
    }

    @discardableResult
    public func swimPlayerToSafety(to location: Int) -> Bool {
        guard case .swimmingToSafety(let playerID, let targets, let continuation) = phase,
              targets.contains(location),
              game.movePlayerToSafety(id: playerID, location: location) else {
            return false
        }

        if let player = game.players.first(where: { $0.id == playerID }) {
            log("\(player.role.name) swam to \(game.tileName(at: location)).", symbol: "drop.fill")
        }
        resolvePlayersInWaterOrContinue(continuation)
        return true
    }

    public func movementTargets(for player: Player) -> [Int] {
        let directions: [Direction] = player.role == .explorer
            ? [.up, .upRight, .right, .downRight, .down, .downLeft, .left, .upLeft]
            : [.up, .right, .down, .left]

        return directions.compactMap { direction in
            guard game.movementCost(for: player, direction: direction) != .blocked else {
                return nil
            }
            return game.destination(from: player.location, direction: direction)
        }
    }

    public func canPlayTreasureCard(playerID: Int, cardIndex: Int) -> Bool {
        guard case .playerAction(let activePlayerID) = phase,
              activePlayerID == playerID,
              let player = game.players.first(where: { $0.id == playerID }),
              player.hand.indices.contains(cardIndex) else {
            return false
        }

        return player.hand[cardIndex] == .sandbag || player.hand[cardIndex] == .helicopter
    }

    public func canPlayReactionCard(playerID: Int, cardIndex: Int) -> Bool {
        guard canPlayReactionCards,
              let player = game.players.first(where: { $0.id == playerID }),
              player.hand.indices.contains(cardIndex) else {
            return false
        }

        switch player.hand[cardIndex] {
        case .sandbag, .helicopter:
            return true
        case .treasure, .watersRise:
            return false
        }
    }

    public func canSelectTreasureToGive(playerID: Int, cardIndex: Int) -> Bool {
        guard case .selectingTreasureToGive(let giverID, _, _) = phase,
              giverID == playerID,
              let player = game.players.first(where: { $0.id == playerID }),
              player.hand.indices.contains(cardIndex) else {
            return false
        }

        if case .treasure = player.hand[cardIndex] {
            return true
        }
        return false
    }

    public func canDiscardForHandLimit(playerID: Int, cardIndex: Int) -> Bool {
        guard case .discardingHandLimit(let discardingPlayerID, _) = phase,
              discardingPlayerID == playerID,
              let player = game.players.first(where: { $0.id == playerID }) else {
            return false
        }

        return player.hand.indices.contains(cardIndex)
    }

    public func canSelectHandLimitCardAction(playerID: Int, cardIndex: Int) -> Bool {
        guard case .discardingHandLimit(let discardingPlayerID, _) = phase,
              discardingPlayerID == playerID,
              let player = game.players.first(where: { $0.id == playerID }),
              player.hand.indices.contains(cardIndex) else {
            return false
        }

        switch player.hand[cardIndex] {
        case .sandbag, .helicopter:
            return true
        case .treasure, .watersRise:
            return false
        }
    }

    @discardableResult
    public func selectHandLimitCardAction(playerID: Int, cardIndex: Int) -> Bool {
        guard canSelectHandLimitCardAction(playerID: playerID, cardIndex: cardIndex) else {
            return false
        }

        selectedHandLimitCard = HandLimitCardSelection(playerID: playerID, cardIndex: cardIndex)
        return true
    }

    public func canPlaySelectedHandLimitCard() -> Bool {
        guard let selection = selectedHandLimitCard,
              let player = game.players.first(where: { $0.id == selection.playerID }),
              player.hand.indices.contains(selection.cardIndex) else {
            return false
        }

        switch player.hand[selection.cardIndex] {
        case .sandbag:
            return canPlayReactionCards && !floodedTileLocations().isEmpty
        case .helicopter:
            return canPlayReactionCards && !helicopterSourceLocations().isEmpty
        case .treasure, .watersRise:
            return false
        }
    }

    @discardableResult
    public func playSelectedHandLimitCard() -> Bool {
        guard let selection = selectedHandLimitCard else {
            return false
        }

        selectedHandLimitCard = nil
        let didPlay = playTreasureCard(playerID: selection.playerID, cardIndex: selection.cardIndex)
        if !didPlay {
            selectedHandLimitCard = selection
        }
        return didPlay
    }

    @discardableResult
    public func discardSelectedHandLimitCard() -> Bool {
        guard let selection = selectedHandLimitCard else {
            return false
        }

        let didDiscard = discardForHandLimit(playerID: selection.playerID, cardIndex: selection.cardIndex)
        if didDiscard {
            selectedHandLimitCard = nil
        }
        return didDiscard
    }

    @discardableResult
    public func discardForHandLimit(playerID: Int, cardIndex: Int) -> Bool {
        guard case .discardingHandLimit(let discardingPlayerID, let continuation) = phase,
              discardingPlayerID == playerID,
              game.discardTreasureCard(playerID: playerID, cardIndex: cardIndex) != nil else {
            return false
        }

        if selectedHandLimitCard?.playerID == playerID,
           selectedHandLimitCard?.cardIndex == cardIndex {
            selectedHandLimitCard = nil
        }

        if let player = game.players.first(where: { $0.id == playerID }),
           player.hand.count > GameState.maximumHandSize {
            phase = .discardingHandLimit(playerID: playerID, continuation: continuation)
        } else {
            resumeAfterHandLimit(continuation)
        }
        return true
    }

    @discardableResult
    public func cancelSelection() -> Bool {
        guard canCancelSelection else {
            return false
        }

        log("Selection canceled.", symbol: "arrow.uturn.backward")
        if case .discardingHandLimit = phase,
           selectedHandLimitCard != nil {
            selectedHandLimitCard = nil
            return true
        }
        if let resumedPhase = suspendedPhases.popLast() {
            phase = resumedPhase
        } else {
            phase = activePlayerPhase()
        }
        return true
    }

    private func advanceAfterAction() {
        phase = nextPhaseAfterAction()
    }

    private func nextPhaseAfterAction() -> GamePhase {
        if let loss = game.lossReason() {
            logLoss(loss)
            return .gameOver(.lost(loss))
        }

        if game.hasWon() {
            log("The team escaped Forbidden Island.", symbol: "flag.checkered")
            return .gameOver(.won)
        }

        guard let player = activePlayer else {
            return .gameOver(.lost(.noPlayers))
        }

        if player.actionsRemaining <= 0 {
            return .drawingTreasure(playerID: player.id, drawnCount: 0)
        } else {
            return .playerAction(playerID: player.id)
        }
    }

    private func beginSpecialAction(for player: Player) -> Bool {
        guard player.actionsRemaining > 0 else {
            return false
        }

        switch player.role {
        case .pilot:
            let targets = game.pilotFlyTargets(for: player)
            guard !targets.isEmpty else {
                return false
            }
            phase = .selectingPilotFly(playerID: player.id, targets: targets)
            return true
        case .navigator:
            let targetPlayerIDs = navigatorTargetIDs(for: player)
            guard !targetPlayerIDs.isEmpty else {
                return false
            }
            phase = .selectingNavigatorTarget(playerID: player.id, targetPlayerIDs: targetPlayerIDs)
            return true
        default:
            return false
        }
    }

    private func finishNavigatorMove(playerID: Int) -> Bool {
        guard game.spendAction(playerID: playerID) else {
            return false
        }

        if let player = game.players.first(where: { $0.id == playerID }) {
            log("\(player.role.name) finished the navigator action.", symbol: "arrow.right.circle.fill")
        }
        advanceAfterAction()
        return true
    }

    private func beginReactionSelectionIfNeeded(for playerID: Int) {
        guard shouldSuspendCurrentPhase(for: playerID) else {
            return
        }
        suspendedPhases.append(phase)
    }

    private func completeReactionOrAdvance() {
        if let resumedPhase = suspendedPhases.popLast() {
            phase = resumedPhase
        } else {
            advanceAfterAction()
        }
    }

    private func beginTreasureDraw() {
        guard let player = activePlayer else {
            phase = .gameOver(.lost(.noPlayers))
            return
        }

        phase = .drawingTreasure(playerID: player.id, drawnCount: 0)
    }

    private func advanceAfterTreasureDraw(playerID: Int, drawnCount: Int) {
        if let loss = game.lossReason() {
            logLoss(loss)
            phase = .gameOver(.lost(loss))
            return
        }

        let continuation = treasureDrawContinuation(playerID: playerID, drawnCount: drawnCount)
        if let player = game.players.first(where: { $0.id == playerID }),
           player.hand.count > GameState.maximumHandSize {
            phase = .discardingHandLimit(playerID: playerID, continuation: continuation)
            return
        }

        resumeAfterHandLimit(continuation)
    }

    private func treasureDrawContinuation(playerID: Int, drawnCount: Int) -> HandLimitContinuation {
        if drawnCount >= 2 {
            .flooding
        } else {
            .drawingTreasure(playerID: playerID, drawnCount: drawnCount)
        }
    }

    private func shouldSuspendCurrentPhase(for playerID: Int) -> Bool {
        switch phase {
        case .playerAction(let activePlayerID):
            return activePlayerID != playerID
        case .choosePlayerCount,
             .chooseDifficulty,
             .gameOver:
            return false
        default:
            return true
        }
    }

    private func resumeAfterHandLimit(_ continuation: HandLimitContinuation) {
        switch continuation {
        case .drawingTreasure(let playerID, let drawnCount):
            phase = .drawingTreasure(playerID: playerID, drawnCount: drawnCount)
        case .flooding:
            phase = .flooding(remaining: game.floodDrawCount, lastFloodedLocation: nil)
        case .resume(let resume):
            switch resume {
            case .playerAction(let playerID):
                phase = .playerAction(playerID: playerID)
            case .drawingTreasure(let playerID, let drawnCount):
                phase = .drawingTreasure(playerID: playerID, drawnCount: drawnCount)
            case .flooding(let remaining, let lastFloodedLocation):
                phase = .flooding(remaining: remaining, lastFloodedLocation: lastFloodedLocation)
            }
        }
    }

    private func postActionResume() -> PostHandLimitResume {
        guard let player = activePlayer else {
            return .playerAction(playerID: 0)
        }

        if player.actionsRemaining <= 0 {
            return .drawingTreasure(playerID: player.id, drawnCount: 0)
        }
        return .playerAction(playerID: player.id)
    }

    private func resolvePlayersInWaterOrContinue(_ continuation: FloodContinuation) {
        if let nextSwimmer = game.players.first(where: { player in
            game.tilesByLocation[player.location]?.state == .sunk
        }) {
            let targets = game.swimTargets(for: nextSwimmer)
            if targets.isEmpty {
                log("\(nextSwimmer.role.name) drowned.", symbol: "xmark.octagon.fill")
                phase = .gameOver(.lost(.playerDrowned(nextSwimmer.id)))
            } else {
                phase = .swimmingToSafety(playerID: nextSwimmer.id, targets: targets, continuation: continuation)
            }
            return
        }

        continueAfterFlood(continuation)
    }

    private func continueAfterFlood(_ continuation: FloodContinuation) {
        if let loss = game.lossReason() {
            logLoss(loss)
            phase = .gameOver(.lost(loss))
            return
        }

        switch continuation {
        case .initialFlood(let remainingBeforeFlood, let lastFloodedLocation):
            let remaining = remainingBeforeFlood - 1
            phase = remaining > 0
                ? .initialFlood(remaining: remaining, lastFloodedLocation: lastFloodedLocation)
                : activePlayerPhase()
        case .flooding(let remainingBeforeFlood, let lastFloodedLocation):
            let remaining = remainingBeforeFlood - 1
            if remaining > 0 {
                phase = .flooding(remaining: remaining, lastFloodedLocation: lastFloodedLocation)
            } else {
                game.nextPlayer()
                phase = activePlayerPhase()
            }
        }
    }

    private func advanceAfterFlood(
        remainingBeforeFlood: Int,
        lastFloodedLocation: Int?,
        nextPhaseWhenDone: @autoclosure () -> GamePhase
    ) {
        advanceAfterFlood(
            remainingBeforeFlood: remainingBeforeFlood,
            lastFloodedLocation: lastFloodedLocation,
            nextPhaseWhenDone: nextPhaseWhenDone
        )
    }

    private func advanceAfterFlood(
        remainingBeforeFlood: Int,
        lastFloodedLocation: Int?,
        nextPhaseWhenDone: () -> GamePhase
    ) {
        if let loss = game.lossReason() {
            phase = .gameOver(.lost(loss))
            return
        }

        let remaining = remainingBeforeFlood - 1
        if remaining > 0 {
            switch phase {
            case .initialFlood:
                phase = .initialFlood(remaining: remaining, lastFloodedLocation: lastFloodedLocation)
            case .flooding:
                phase = .flooding(remaining: remaining, lastFloodedLocation: lastFloodedLocation)
            default:
                phase = nextPhaseWhenDone()
            }
        } else {
            phase = nextPhaseWhenDone()
        }
    }

    private func activePlayerPhase() -> GamePhase {
        guard let player = activePlayer else {
            return .gameOver(.lost(.noPlayers))
        }
        return .playerAction(playerID: player.id)
    }

    private func setActivePlayerActions(to value: Int) {
        guard game.players.indices.contains(game.activePlayerIndex) else {
            return
        }
        game.players[game.activePlayerIndex].actionsRemaining = value
    }

    private func direction(from start: Int, to destination: Int) -> Direction? {
        Direction.allCases.first { start + $0.offset == destination }
    }

    private func floodedTileLocations() -> [Int] {
        game.tilesByLocation
            .filter { $0.value.state == .flooded }
            .map(\.key)
            .sorted()
    }

    private func helicopterDestinations(excluding currentLocation: Int) -> [Int] {
        game.tilesByLocation
            .filter { $0.key != currentLocation && $0.value.state != .sunk }
            .map(\.key)
            .sorted()
    }

    private func helicopterSourceLocations() -> [Int] {
        game.tilesByLocation
            .filter { location, tile in
                tile.state != .sunk && game.players.contains(where: { $0.location == location })
            }
            .map(\.key)
            .sorted()
    }

    private func helicopterPassengerCandidates(at location: Int) -> [Int] {
        game.players
            .filter { $0.location == location }
            .map(\.id)
            .sorted()
    }

    private func treasureReceiverIDs(for player: Player) -> [Int] {
        game.players
            .filter { candidate in
                candidate.id != player.id &&
                    (player.role == .messenger || candidate.location == player.location)
            }
            .map(\.id)
    }

    private func navigatorTargetIDs(for player: Player) -> [Int] {
        guard player.role == .navigator else {
            return []
        }

        return game.players
            .filter { candidate in
                candidate.id != player.id && !game.navigatorMoveTargets(for: candidate).isEmpty
            }
            .map(\.id)
    }

    private func logAction(_ action: String, for player: Player) {
        log("\(player.role.name) \(action.lowercased()).", symbol: "person.fill")
    }

    private func logMovement(playerID: Int, destination: Int) {
        guard let player = game.players.first(where: { $0.id == playerID }) else {
            return
        }

        log("\(player.role.name) moved to \(game.tileName(at: destination)).", symbol: "arrow.right")
    }

    private func logFloodEvent(at location: Int?) {
        guard let location else {
            return
        }

        let tileName = game.tileName(at: location)
        if let tile = game.tilesByLocation[location], tile.state == .sunk {
            log("\(tileName) sank.", symbol: "water.waves")
        } else {
            log("\(tileName) flooded.", symbol: "drop.fill")
        }
    }

    private func logLoss(_ loss: GameLoss) {
        log("Lost: \(lossText(loss)).", symbol: "xmark.octagon.fill")
    }

    private func log(_ message: String, symbol: String) {
        eventLog.append(GameLogEntry(id: nextLogID, symbol: symbol, message: message))
        nextLogID += 1

        if eventLog.count > 40 {
            eventLog.removeFirst(eventLog.count - 40)
        }
    }

    private func treasureCardName(_ card: TreasureCard) -> String {
        switch card {
        case .treasure(let treasure):
            "\(treasure) card"
        case .helicopter:
            "Helicopter Lift"
        case .sandbag:
            "Sandbag"
        case .watersRise:
            "Waters Rise"
        }
    }

    private func lossText(_ loss: GameLoss) -> String {
        switch loss {
        case .foolsLandingSunk:
            "Fools' Landing sank"
        case .treasureUnavailable(let treasure):
            "\(treasure) treasure unavailable"
        case .waterLevelOverflow:
            "Water level overflow"
        case .playerDrowned(let playerID):
            "Player \(playerID) drowned"
        case .noPlayers:
            "No players remain"
        }
    }
}
