import XCTest
@testable import ForbiddenIslandRules

final class ForbiddenIslandRulesTests: XCTestCase {
    func testNewGameCreatesTwentyFourTilesAndTwentyEightTreasureCards() {
        var rng = SeededGenerator(seed: 42)
        let game = GameState.newGame(using: &rng)

        XCTAssertEqual(game.tilesByLocation.count, 24)
        XCTAssertEqual(Set(game.tilesByLocation.keys), Set(GameState.validSquares))
        XCTAssertEqual(game.floodDeck.count, 24)
        XCTAssertEqual(game.treasureDeck.count, 28)
    }

    func testCreatePlayersPlacesRolesOnMatchingGateTiles() {
        var rng = SeededGenerator(seed: 1)
        var game = fixedGame()

        game.createPlayers(count: 4, using: &rng)

        for player in game.players {
            let tile = game.tilesByLocation[player.location]
            XCTAssertEqual(tile?.kind.startingRole, player.role)
        }
    }

    func testTileDisplayNamesAreHumanReadable() {
        let game = fixedGame()

        XCTAssertEqual(TileKind.foolsLanding.name, "Fools' Landing")
        XCTAssertEqual(TileKind.caveOfEmbers.name, "Cave of Embers")
        XCTAssertEqual(game.tileName(at: 2), "Bronze Gate (2)")
        XCTAssertEqual(game.tileName(at: 99), "Location 99")
    }

    func testDealInitialTreasureCardsGivesTwoCardsToEachPlayer() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9),
            Player(id: 1, role: .engineer, location: 2)
        ]
        game.treasureDeck = [
            .treasure(.earth),
            .sandbag,
            .helicopter,
            .treasure(.fire)
        ]

        game.dealInitialTreasureCards()

        XCTAssertEqual(game.players[0].hand, [.treasure(.fire), .sandbag])
        XCTAssertEqual(game.players[1].hand, [.helicopter, .treasure(.earth)])
        XCTAssertTrue(game.treasureDeck.isEmpty)
    }

    func testInitialTreasureDealDoesNotDealWatersRiseBeforeGameStarts() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9)
        ]
        game.treasureDeck = [.treasure(.earth), .treasure(.water), .treasure(.fire), .watersRise]

        game.dealInitialTreasureCards(cardsPerPlayer: 1)

        XCTAssertNotEqual(game.players[0].hand, [.watersRise])
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.waterLevel, 1)
        XCTAssertTrue(game.treasureDiscard.isEmpty)
    }

    func testExplorerCanMoveDiagonallyButNormalPlayerCannot() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .explorer, location: 14),
            Player(id: 1, role: .engineer, location: 14)
        ]

        XCTAssertTrue(game.movePlayer(id: 0, direction: .upRight))
        XCTAssertEqual(game.players[0].location, 9)

        XCTAssertFalse(game.movePlayer(id: 1, direction: .upRight))
        XCTAssertEqual(game.players[1].location, 14)
    }

    func testDiverTraversesFloodedAndSunkTilesForFree() {
        var game = fixedGame()
        game.tilesByLocation[15]?.state = .flooded
        game.tilesByLocation[16]?.state = .sunk
        game.players = [Player(id: 0, role: .diver, location: 14)]

        XCTAssertTrue(game.movePlayer(id: 0, direction: .right))
        XCTAssertEqual(game.players[0].location, 15)
        XCTAssertEqual(game.players[0].actionsRemaining, 3)

        XCTAssertTrue(game.movePlayer(id: 0, direction: .right))
        XCTAssertEqual(game.players[0].location, 16)
        XCTAssertEqual(game.players[0].actionsRemaining, 3)
    }

    func testEngineerGetsTwoShoreUpsForOneAction() {
        var game = fixedGame()
        game.tilesByLocation[13]?.state = .flooded
        game.tilesByLocation[15]?.state = .flooded
        game.players = [Player(id: 0, role: .engineer, location: 14)]

        XCTAssertTrue(game.shoreUp(playerID: 0, location: 13))
        XCTAssertEqual(game.tilesByLocation[13]?.state, .dry)
        XCTAssertEqual(game.players[0].actionsRemaining, 3)
        XCTAssertTrue(game.engineerHasPendingShoreUp)

        XCTAssertTrue(game.shoreUp(playerID: 0, location: 15))
        XCTAssertEqual(game.tilesByLocation[15]?.state, .dry)
        XCTAssertEqual(game.players[0].actionsRemaining, 2)
        XCTAssertFalse(game.engineerHasPendingShoreUp)
    }

    func testFloodingFirstFloodsThenSinksTile() {
        var game = fixedGame()
        game.floodDeck = [.bronzeGate, .bronzeGate]

        let firstLocation = game.floodNextTile()
        XCTAssertEqual(firstLocation, 2)
        XCTAssertEqual(game.tilesByLocation[2]?.state, .flooded)
        XCTAssertEqual(game.floodDiscard, [.bronzeGate])

        let secondLocation = game.floodNextTile()
        XCTAssertEqual(secondLocation, 2)
        XCTAssertEqual(game.tilesByLocation[2]?.state, .sunk)
        XCTAssertEqual(game.floodOut, [.bronzeGate])
    }

    func testWatersRiseRaisesWaterAndMovesDiscardToTopOfFloodDeck() {
        var game = fixedGame()
        game.waterLevel = 2
        game.floodDeck = [.bronzeGate]
        game.floodDiscard = [.goldGate, .ironGate]

        game.watersRise()

        XCTAssertEqual(game.waterLevel, 3)
        XCTAssertTrue(game.floodDiscard.isEmpty)
        XCTAssertEqual(game.floodDeck.count, 3)
        XCTAssertTrue(game.floodDeck.contains(.goldGate))
        XCTAssertTrue(game.floodDeck.contains(.ironGate))
    }

    func testCollectTreasureRequiresFourMatchingCardsAndTreasureTile() {
        var game = fixedGame()
        game.players = [
            Player(
                id: 0,
                role: .pilot,
                location: 7,
                hand: [.treasure(.fire), .treasure(.fire), .treasure(.fire), .treasure(.fire), .sandbag]
            )
        ]

        XCTAssertEqual(game.collectableTreasure(for: game.players[0]), .fire)
        XCTAssertEqual(game.collectTreasure(playerID: 0), .fire)
        XCTAssertTrue(game.collectedTreasures.contains(.fire))
        XCTAssertEqual(game.players[0].hand, [.sandbag])
        XCTAssertEqual(game.players[0].actionsRemaining, 2)
    }

    func testMessengerCanTransferTreasureAcrossIsland() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .messenger, location: 2, hand: [.treasure(.water)]),
            Player(id: 1, role: .pilot, location: 33)
        ]

        XCTAssertTrue(game.transferTreasure(from: 0, to: 1, cardIndex: 0))
        XCTAssertTrue(game.players[0].hand.isEmpty)
        XCTAssertEqual(game.players[1].hand, [.treasure(.water)])
        XCTAssertEqual(game.players[0].actionsRemaining, 2)
    }

    func testNonMessengerCanOnlyTransferOnSameTile() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 2, hand: [.treasure(.water)]),
            Player(id: 1, role: .pilot, location: 33)
        ]

        XCTAssertFalse(game.transferTreasure(from: 0, to: 1, cardIndex: 0))

        game.players[1].location = 2
        XCTAssertTrue(game.transferTreasure(from: 0, to: 1, cardIndex: 0))
    }

    func testSandbagAndHelicopterCardsDoNotSpendActions() {
        var game = fixedGame()
        game.tilesByLocation[8]?.state = .flooded
        game.players = [
            Player(id: 0, role: .engineer, location: 2, hand: [.sandbag, .helicopter]),
            Player(id: 1, role: .pilot, location: 3)
        ]

        XCTAssertTrue(game.playSandbag(playerID: 0, cardIndex: 0, location: 8))
        XCTAssertEqual(game.tilesByLocation[8]?.state, .dry)
        XCTAssertEqual(game.players[0].actionsRemaining, 3)

        XCTAssertTrue(game.playHelicopter(playerID: 0, cardIndex: 0, movingPlayerIDs: [0, 1], destination: 14))
        XCTAssertEqual(game.players[0].location, 14)
        XCTAssertEqual(game.players[1].location, 14)
        XCTAssertEqual(game.players[0].actionsRemaining, 3)
    }

    func testSwimTargetsRespectRoleMovementRules() {
        var game = fixedGame()
        game.tilesByLocation[9]?.state = .sunk
        game.tilesByLocation[3]?.state = .sunk
        game.tilesByLocation[10]?.state = .sunk
        let normalPlayer = Player(id: 0, role: .engineer, location: 9)
        let explorer = Player(id: 1, role: .explorer, location: 9)
        let pilot = Player(id: 2, role: .pilot, location: 9)

        XCTAssertEqual(game.swimTargets(for: normalPlayer), [15, 8])
        XCTAssertEqual(game.swimTargets(for: explorer), [16, 15, 14, 8, 2])
        XCTAssertFalse(game.swimTargets(for: pilot).contains(9))
        XCTAssertTrue(game.swimTargets(for: pilot).contains(2))
    }

    func testMovePlayerToSafetyDoesNotSpendAction() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 9)
        ]
        game.tilesByLocation[9]?.state = .sunk

        XCTAssertTrue(game.movePlayerToSafety(id: 0, location: 15))
        XCTAssertEqual(game.players[0].location, 15)
        XCTAssertEqual(game.players[0].actionsRemaining, 3)
        XCTAssertFalse(game.movePlayerToSafety(id: 0, location: 9))
    }

    func testPilotFlySpendsOneActionAndResetsNextTurn() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9),
            Player(id: 1, role: .engineer, location: 2)
        ]
        game.activePlayerIndex = 0
        game.tilesByLocation[8]?.state = .sunk

        XCTAssertFalse(game.pilotFlyTargets(for: game.players[0]).contains(8))
        XCTAssertTrue(game.pilotFly(playerID: 0, destination: 14))
        XCTAssertEqual(game.players[0].location, 14)
        XCTAssertEqual(game.players[0].actionsRemaining, 2)
        XCTAssertTrue(game.pilotHasFlownThisTurn)
        XCTAssertTrue(game.pilotFlyTargets(for: game.players[0]).isEmpty)

        game.nextPlayer()
        XCTAssertFalse(game.pilotHasFlownThisTurn)
    }

    func testNavigatorMovesOtherPlayerWithoutSpendingTargetAction() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .navigator, location: 9),
            Player(id: 1, role: .engineer, location: 14, actionsRemaining: 2)
        ]

        XCTAssertEqual(game.navigatorMoveTargets(for: game.players[1]), [8, 15, 20, 13])
        XCTAssertTrue(game.navigatorMovePlayer(targetID: 1, destination: 15))
        XCTAssertEqual(game.players[1].location, 15)
        XCTAssertEqual(game.players[1].actionsRemaining, 2)
        XCTAssertFalse(game.navigatorMovePlayer(targetID: 1, destination: 33))
    }

    func testDiscardTreasureCardRemovesFromHandAndAddsToDiscard() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 2, hand: [.treasure(.fire), .sandbag])
        ]

        XCTAssertEqual(game.discardTreasureCard(playerID: 0, cardIndex: 1), .sandbag)
        XCTAssertEqual(game.players[0].hand, [.treasure(.fire)])
        XCTAssertEqual(game.treasureDiscard, [.sandbag])
        XCTAssertNil(game.discardTreasureCard(playerID: 0, cardIndex: 8))
    }

    func testLossWhenFoolsLandingSinksOrUnclaimedTreasureIsGone() {
        var game = fixedGame()
        game.tilesByLocation[9]?.state = .sunk
        XCTAssertEqual(game.lossReason(), .foolsLandingSunk)

        game = fixedGame()
        game.tilesByLocation[7]?.state = .sunk
        game.tilesByLocation[8]?.state = .sunk
        XCTAssertEqual(game.lossReason(), .treasureUnavailable(.fire))
    }

    func testWinRequiresHelicopterLiftAfterAllTreasuresAndEveryoneOnFoolsLanding() {
        var game = fixedGame()
        game.collectedTreasures = Set(Treasure.allCases)
        game.players = [
            Player(id: 0, role: .pilot, location: 9),
            Player(id: 1, role: .engineer, location: 9)
        ]

        XCTAssertFalse(game.hasWon())
        game.helicopterLiftPlayed = true
        XCTAssertTrue(game.hasWon())
        game.players[1].location = 13
        XCTAssertFalse(game.hasWon())
    }

    private func fixedGame() -> GameState {
        let orderedLocations = GameState.validSquares
        let orderedKinds: [TileKind] = [
            .bronzeGate, .copperGate, .caveOfEmbers, .caveOfShadows,
            .foolsLanding, .goldGate, .ironGate, .silverGate,
            .coralPalace, .tidalPalace, .howlingGarden, .whisperingGarden,
            .templeOfTheMoon, .templeOfTheSun, .breakersBridge, .cliffsOfAbandon,
            .crimsonForest, .dunesOfDeception, .lostLagoon, .mistyMarsh,
            .observatory, .phantomRock, .twilightHollow, .watchtower
        ]

        let tiles = Dictionary(
            uniqueKeysWithValues: zip(orderedLocations, orderedKinds).map {
                ($0.0, IslandTile(kind: $0.1))
            }
        )

        return GameState(
            tilesByLocation: tiles,
            floodDeck: orderedKinds,
            treasureDeck: GameState.makeTreasureDeck(),
            players: [Player(id: 0, role: .pilot, location: 12)]
        )
    }
}
