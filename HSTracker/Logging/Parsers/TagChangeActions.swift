//
//  TagChanceActions.swift
//  HSTracker
//
//  Created by Benjamin Michotte on 9/03/16.
//  Copyright © 2016 Benjamin Michotte. All rights reserved.
//

import Foundation

struct TagChangeActions {
    
    var powerGameStateParser: PowerGameStateParser?

    mutating func setPowerGameStateParser(parser: PowerGameStateParser) {
        self.powerGameStateParser = parser
    }
    
    func findAction(eventHandler: PowerEventHandler, tag: GameTag, id: Int, value: Int, prevValue: Int) -> (() -> Void)? {
        switch tag {
        case .zone: return { self.zoneChange(eventHandler: eventHandler, id: id, value: value, prevValue: prevValue) }
        case .playstate: return { self.playstateChange(eventHandler: eventHandler, id: id, value: value) }
        case .cardtype: return { self.cardTypeChange(eventHandler: eventHandler, id: id, value: value) }
        case .defending: return { self.defendingChange(eventHandler: eventHandler, id: id, value: value) }
        case .attacking: return { self.attackingChange(eventHandler: eventHandler, id: id, value: value) }
        case .proposed_defender: return { self.proposedDefenderChange(eventHandler: eventHandler, value: value) }
        case .proposed_attacker: return { self.proposedAttackerChange(eventHandler: eventHandler, value: value) }
        case .predamage: return { self.predamageChange(eventHandler: eventHandler, id: id, value: value) }
        case .num_turns_in_play: return { self.numTurnsInPlayChange(eventHandler: eventHandler, id: id, value: value) }
        case .num_attacks_this_turn: return { self.numAttacksThisTurnChange(eventHandler: eventHandler, id: id, value: value) }
        case .zone_position: return { self.zonePositionChange(eventHandler: eventHandler, id: id) }
        case .card_target: return { self.cardTargetChange(eventHandler: eventHandler, id: id, value: value) }
        //case .equipped_weapon: return { self.equippedWeaponChange(eventHandler: eventHandler, id: id, value: value) }
        case .exhausted: return {  self.exhaustedChange(eventHandler: eventHandler, id: id, value: value) }
        case .controller:
            return {
                self.controllerChange(eventHandler: eventHandler, id: id, prevValue: prevValue, value: value)
            }
        case .fatigue: return { self.fatigueChange(eventHandler: eventHandler, value: value, id: id) }
        case .step: return { self.stepChange(eventHandler: eventHandler, value: value) }
        case .turn: return { self.turnChange(eventHandler: eventHandler) }
        case .state: return { self.stateChange(eventHandler: eventHandler, value: value) }
        case .transformed_from_card:
            return {
                self.transformedFromCardChange(eventHandler: eventHandler,
                                               id: id,
                                               value: value)
            }
        case .creator, .displayed_creator:
            return { self.creatorChanged(eventHandler: eventHandler, id: id, value: value)}
        case .whizbang_deck_id:
            return { self.whizbangDeckIdChange(eventHandler: eventHandler, id: id, value: value)}
        case .mulligan_state: return { self.mulliganStateChange(eventHandler: eventHandler, id: id, value: value) }
        case .copied_from_entity_id: return { self.onCardCopy(eventHandler: eventHandler, id: id, value: value) }
        case .tag_script_data_num_1: return { self.tagScriptDataNum1(eventHandler: eventHandler, id: id, value: value) }
        case .reborn: return { self.rebornChange(eventHandler: eventHandler, id: id, value: value)}
        case .player_tech_level: return { self.playerTechLevel(eventHandler: eventHandler, id: id, value: value, previous: prevValue)}
        case .player_triples: return { self.playerTriples(eventHandler: eventHandler, id: id, value: value, previous: prevValue)}
        case .armor: return { self.armorChange(eventHandler: eventHandler, id: id, value: value, previous: prevValue)}
        case .lettuce_ability_tile_visual_all_visible, .lettuce_ability_tile_visual_self_only, .fake_zone, .fake_zone_position: return { self.mercenariesStateChange(eventHandler: eventHandler)}
        default: return nil
        }
    }
    
    private func rebornChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if eventHandler.currentGameMode != GameMode.battlegrounds {
            return
        }
        if value != 1 {
            return
        }
    }
    
    private func tagScriptDataNum1(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if eventHandler.currentGameMode != .battlegrounds {
            return
        }
        let block = powerGameStateParser?.getCurrentBlock()
        
        if block == nil || block?.type != "TRIGGER" || block?.cardId != CardIds.NonCollectible.Neutral.Baconshop8playerenchantTavernBrawl || value != 1 {
            return
        }
        if let entity = eventHandler.entities[id] {
            if !entity.isHeroPower || !entity.isControlled(by: eventHandler.player.id) {
                return
            }
        }
    }
    
    private func onCardCopy(eventHandler: PowerEventHandler, id: Int, value: Int) {

        guard let entity = eventHandler.entities[id] else {
            return
        }
        if entity.isControlled(by: eventHandler.opponent.id) {
            return
        }
        guard let targetEntity = eventHandler.entities[value] else {
            return
        }

        if targetEntity.cardId == "" {
            targetEntity.cardId = entity.cardId
            targetEntity.info.guessedCardState = GuessedCardState.guessed

            if entity[.creator_dbid] == CardIds.keyMasterAlabasterDbfId {
                targetEntity.info.hidden = false
            }

            eventHandler.handleCardCopy()
        }
    }
    
    private func mulliganStateChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if value == 0 {
            return
        }
        guard let entity = eventHandler.entities[id] else {
            return
        }

        if entity.isPlayer(eventHandler: eventHandler) && Mulligan.done.rawValue == value {
            eventHandler.handlePlayerMulliganDone()
        }
    }

    private func whizbangDeckIdChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if value == 0 {
            return
        }
        guard let entity = eventHandler.entities[id] else {
            return
        }
        if entity.isControlled(by: eventHandler.player.id) {
            eventHandler.player.isPlayingWhizbang = true
        } else if entity.isControlled(by: eventHandler.opponent.id) {
            eventHandler.opponent.isPlayingWhizbang = true
        }
        if !entity.isPlayer(eventHandler: eventHandler) {
            return
        }
        //DeckManager.AutoSelectDeckById(game, value);
    }
    
    private func creatorChanged(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if value == 0 {
            return
        }
        
        if let entity = eventHandler.entities[id] {
            let displayedCreatorId = entity[.displayed_creator]
            if displayedCreatorId == id {
                // Some cards (e.g. Direhorn Hatchling) wrongfully set DISPLAYED_CREATOR
                // on themselves instead of the created entity.
                return
            }
            if let displayedCreator = eventHandler.entities[displayedCreatorId] {
                // For some reason Far Sight sets DISPLAYED_CREATOR on the entity
                if displayedCreator.cardId == CardIds.Collectible.Shaman.FarSight || displayedCreator.cardId == CardIds.Collectible.Shaman.FarSightVanilla {
                    return
                }
            }

            let creatorId = entity[.creator]
            if creatorId == id {
                // Same precaution as for Direhorn Hatching above.
                return
            }
            if creatorId == eventHandler.gameEntity?.id {
                return
            }
            // All cards created by Whizbang have a creator tag set
            if let creator = eventHandler.entities[creatorId] {
                if creator.cardId == CardIds.Collectible.Neutral.WhizbangTheWonderful {
                    return
                }
                let controller = creator[.controller]
                let usingWhizbang = controller == eventHandler.player?.id && eventHandler.player.isPlayingWhizbang
                                    || controller == eventHandler.opponent?.id && eventHandler.opponent.isPlayingWhizbang
                if usingWhizbang && creator.isInSetAside {
                    return
                }
            }
            entity.info.created = true
        }
    }
    private func transformedFromCardChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if value == 0 { return }
        guard let entity = eventHandler.entities[id] else { return }

        entity.info.set(originalCardId: value)
    }

    private func defendingChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        guard let entity = eventHandler.entities[id] else { return }
        eventHandler.defending(entity: value == 1 ? entity : nil)
    }

    private func attackingChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        guard let entity = eventHandler.entities[id] else { return }
        eventHandler.attacking(entity: value == 1 ? entity : nil)
    }

    private func proposedDefenderChange(eventHandler: PowerEventHandler, value: Int) {
        eventHandler.proposedDefenderEntityId = value
    }

    private func proposedAttackerChange(eventHandler: PowerEventHandler, value: Int) {
        eventHandler.proposedAttackerEntityId = value
        if value <= 0 {
            return
        }
        guard let entity = eventHandler.entities[value] else {
            return
        }
        if entity.isHero {
            logger.debug("Saw hero attack from \(entity.cardId)")
        }
        eventHandler.handleProposedAttackerChange(entity: entity)
    }

    private func predamageChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        guard value > 0 else { return }
        guard let playerEntity = eventHandler.playerEntity, let entity = eventHandler.entities[id] else { return }
        
        if playerEntity.isCurrentPlayer {
            eventHandler.opponentDamage(entity: entity, damage: value)
        }
    }
    
    private func armorChange(eventHandler: PowerEventHandler, id: Int, value: Int, previous: Int) {
        if value <= 0 {
            return
        }
        
        if let entity = eventHandler.entities[id] {
            eventHandler.handleEntityLostArmor(entity: entity, value: previous - value)
        }
    }
    
    private func mercenariesStateChange(eventHandler: PowerEventHandler) {
        eventHandler.handleMercenariesStateChange()
        
    }

    private func numTurnsInPlayChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        guard value > 0 else { return }
        guard let entity = eventHandler.entities[id] else { return }
        
        eventHandler.turnsInPlayChange(entity: entity, turn: eventHandler.turnNumber())
    }

    private func fatigueChange(eventHandler: PowerEventHandler, value: Int, id: Int) {
        guard let entity = eventHandler.entities[id] else { return }
        
        let controller = entity[.controller]
        if controller == eventHandler.player.id {
            eventHandler.playerFatigue(value: value)
        } else if controller == eventHandler.opponent.id {
            eventHandler.opponentFatigue(value: value)
        }
    }

    private func controllerChange(eventHandler: PowerEventHandler, id: Int, prevValue: Int, value: Int) {
        guard let entity = eventHandler.entities[id] else { return }
        if prevValue <= 0 {
            entity.info.originalController = value
            return
        }
        
        guard !entity.has(tag: .player_id) else { return }
        
        if value == eventHandler.player.id {
            if entity.isInZone(zone: .secret) {
                eventHandler.opponentStolen(entity: entity, cardId: entity.cardId, turn: eventHandler.turnNumber())
            } else if entity.isInZone(zone: .play) {
                eventHandler.opponentStolen(entity: entity, cardId: entity.cardId, turn: eventHandler.turnNumber())
            }
        } else if value == eventHandler.opponent.id && prevValue != value {
            if entity.isInZone(zone: .secret) {
                eventHandler.playerStolen(entity: entity, cardId: entity.cardId, turn: eventHandler.turnNumber())
            } else if entity.isInZone(zone: .play) {
                eventHandler.playerStolen(entity: entity, cardId: entity.cardId, turn: eventHandler.turnNumber())
            }
        }
    }

    private func exhaustedChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        guard value > 0 else { return }
        guard let entity = eventHandler.entities[id] else { return }
        guard entity[.cardtype] == CardType.hero_power.rawValue else { return }
    }

    private func equippedWeaponChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        
    }

    private func cardTargetChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        
    }

    private func zonePositionChange(eventHandler: PowerEventHandler, id: Int) {
        
    }

    private func numAttacksThisTurnChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        
    }

    private func stateChange(eventHandler: PowerEventHandler, value: Int) {
        if value != State.complete.rawValue {
            return
        }
        eventHandler.gameEnd()
        eventHandler.gameEnded = true
    }

    private func turnChange(eventHandler: PowerEventHandler) {
        guard eventHandler.setupDone && eventHandler.playerEntity != nil else { return }
        guard let playerEntity = eventHandler.playerEntity else { return }

        let activePlayer: PlayerType = playerEntity.has(tag: .current_player) ? .player : .opponent
        
        if activePlayer == .player {
            eventHandler.playerUsedHeroPower = false
        } else {
            eventHandler.opponentUsedHeroPower = false
        }
    }

    private func stepChange(eventHandler: PowerEventHandler, value: Int) {
        if value == Step.begin_mulligan.rawValue {
            eventHandler.handleBeginMulligan()
        }
        eventHandler.handleMercenariesStateChange()
        guard !eventHandler.setupDone && eventHandler.entities.first?.1.name == "GameEntity" else { return }

        logger.info("Game was already in progress.")
        eventHandler.wasInProgress = true
    }

    private func cardTypeChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if value == CardType.hero.rawValue {
            setHeroAsync(eventHandler: eventHandler, id: id)
        }
    }

    private func playstateChange(eventHandler: PowerEventHandler, id: Int, value: Int) {
        if value == PlayState.conceded.rawValue {
            eventHandler.concede()
        }

        guard !eventHandler.gameEnded else { return }

		if let entity = eventHandler.entities[id], !entity.isPlayer(eventHandler: eventHandler) {
            return
        }

        if let value = PlayState(rawValue: value) {
            switch value {
            case .won:
                eventHandler.win()
            case .lost:
                eventHandler.loss()
            case .tied:
                eventHandler.tied()
            default: break
            }
        }
    }

    private func zoneChange(eventHandler: PowerEventHandler, id: Int, value: Int, prevValue: Int) {
        guard id > 3 else { return }
        guard let entity = eventHandler.entities[id] else { return }
        
        if entity.info.originalZone == nil {
            if prevValue != Zone.invalid.rawValue && prevValue != Zone.setaside.rawValue {
                entity.info.originalZone = Zone(rawValue: prevValue)
            } else if value != Zone.invalid.rawValue && value != Zone.setaside.rawValue {
                entity.info.originalZone = Zone(rawValue: value)
            }
        }
        
        let controller = entity[.controller]
        guard let zoneValue = Zone(rawValue: prevValue) else { return }
        
        switch zoneValue {
        case .deck:
            zoneChangeFromDeck(eventHandler: eventHandler, id: id, value: value,
                               prevValue: prevValue,
                               controller: controller,
                               cardId: entity.cardId)
            
        case .hand:
            zoneChangeFromHand(eventHandler: eventHandler, id: id, value: value,
                               prevValue: prevValue, controller: controller,
                               cardId: entity.cardId)
            
        case .play:
            zoneChangeFromPlay(eventHandler: eventHandler, id: id, value: value,
                               prevValue: prevValue, controller: controller,
                               cardId: entity.cardId)
            
        case .secret:
            zoneChangeFromSecret(eventHandler: eventHandler, id: id, value: value,
                                 prevValue: prevValue, controller: controller,
                                 cardId: entity.cardId)
            
        case .invalid:
            let maxId = getMaxHeroPowerId(eventHandler: eventHandler)
            if !eventHandler.setupDone
                && (id <= maxId || eventHandler.gameEntity?[.step] == Step.invalid.rawValue
                    && entity[.zone_position] < 5) {
                entity.info.originalZone = .deck
                simulateZoneChangesFromDeck(eventHandler: eventHandler, id: id, value: value,
                                            cardId: entity.cardId, maxId: maxId)
            } else {
                zoneChangeFromOther(eventHandler: eventHandler, id: id, rawValue: value,
                                    prevValue: prevValue, controller: controller,
                                    cardId: entity.cardId)
            }
            
        case .graveyard, .setaside, .removedfromgame:
            zoneChangeFromOther(eventHandler: eventHandler, id: id, rawValue: value, prevValue: prevValue,
                                controller: controller, cardId: entity.cardId)
        }
    }

    // The last heropower is created after the last hero, therefore +1
    private func getMaxHeroPowerId(eventHandler: PowerEventHandler) -> Int {
        return max(eventHandler.playerEntity?[.hero_entity] ?? 66,
                   eventHandler.opponentEntity?[.hero_entity] ?? 66) + 1
    }

    private func simulateZoneChangesFromDeck(eventHandler: PowerEventHandler, id: Int,
                                             value: Int, cardId: String?, maxId: Int) {
        if value == Zone.deck.rawValue {
            return
        }
        
        guard let entity = eventHandler.entities[id] else { return }
        
        if value == Zone.setaside.rawValue {
            entity.info.created = true
            return
        }
        
        if entity.isHero && !entity.isPlayableHero || entity.isHeroPower
            || entity.has(tag: .player_id) || entity[.cardtype] == CardType.game.rawValue
            || entity.has(tag: .creator) {
            return
        }
        
        zoneChangeFromDeck(eventHandler: eventHandler, id: id, value: Zone.hand.rawValue,
                           prevValue: Zone.deck.rawValue,
                           controller: entity[.controller], cardId: cardId)
        if value == Zone.hand.rawValue {
            return
        }
        zoneChangeFromHand(eventHandler: eventHandler, id: id, value: Zone.play.rawValue,
                           prevValue: Zone.hand.rawValue,
                           controller: entity[.controller], cardId: cardId)
        if value == Zone.play.rawValue {
            return
        }
        zoneChangeFromPlay(eventHandler: eventHandler, id: id, value: value, prevValue: Zone.play.rawValue,
                           controller: entity[.controller], cardId: cardId)
    }

    private func zoneChangeFromOther(eventHandler: PowerEventHandler, id: Int, rawValue: Int,
                                     prevValue: Int, controller: Int, cardId: String?) {
        guard let value = Zone(rawValue: rawValue), let entity = eventHandler.entities[id] else { return }

        if entity.info.originalZone == .deck  && rawValue != Zone.deck.rawValue {
            // This entity was moved from DECK to SETASIDE to HAND, e.g. by Tracking
            entity.info.discarded = false
            zoneChangeFromDeck(eventHandler: eventHandler, id: id, value: rawValue, prevValue: prevValue,
                               controller: controller, cardId: cardId)
            return
        }
        entity.info.created = true
        
        switch value {
        case .play:
            if controller == eventHandler.player.id {
                eventHandler.playerCreateInPlay(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentCreateInPlay(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            }
            
        case .deck:
            if controller == eventHandler.player.id {
                if eventHandler.joustReveals > 0 {
                    break
                }
                eventHandler.playerGetToDeck(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                
                if eventHandler.joustReveals > 0 {
                    break
                }
                eventHandler.opponentGetToDeck(entity: entity, turn: eventHandler.turnNumber())
            }
            
        case .hand:
            if controller == eventHandler.player.id {
                eventHandler.playerGet(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentGet(entity: entity, turn: eventHandler.turnNumber(), id: id)
            }
            
        case .secret:
            if controller == eventHandler.player.id {
                if let prevZone = Zone(rawValue: prevValue) {
                    eventHandler.playerSecretPlayed(entity: entity, cardId: cardId,
                                            turn: eventHandler.turnNumber(), fromZone: prevZone)
                }
            } else if controller == eventHandler.opponent.id {
                if let prevZone = Zone(rawValue: prevValue) {
                    eventHandler.opponentSecretPlayed(entity: entity, cardId: cardId, from: -1,
                                              turn: eventHandler.turnNumber(),
                                              fromZone: prevZone, otherId: id)
                }
            }
            
        case .setaside:
            if controller == eventHandler.player.id {
                eventHandler.playerCreateInSetAside(entity: entity, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentCreateInSetAside(entity: entity, turn: eventHandler.turnNumber())
            }
            
        default:
            break
        }
    }

    private func zoneChangeFromSecret(eventHandler: PowerEventHandler, id: Int, value: Int,
                                      prevValue: Int, controller: Int, cardId: String?) {
        guard let zoneValue = Zone(rawValue: value), let entity = eventHandler.entities[id] else { return }
        
        switch zoneValue {
        case .secret, .graveyard:
            if controller == eventHandler.opponent.id {
                eventHandler.opponentSecretTrigger(entity: entity, cardId: cardId,
                                           turn: eventHandler.turnNumber(), otherId: id)
            }
            
        default:
            break
        }
    }

    private func zoneChangeFromPlay(eventHandler: PowerEventHandler, id: Int, value: Int,
                                    prevValue: Int, controller: Int, cardId: String?) {
        guard let zoneValue = Zone(rawValue: value), let entity = eventHandler.entities[id] else { return }
        
        switch zoneValue {
        case .hand:
            if controller == eventHandler.player.id {
                eventHandler.playerBackToHand(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentPlayToHand(entity: entity, cardId: cardId,
                                        turn: eventHandler.turnNumber(), id: id)
            }
            
        case .deck:
            if controller == eventHandler.player.id {
                eventHandler.playerPlayToDeck(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentPlayToDeck(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            }
            
        case .graveyard:
            if controller == eventHandler.player.id {
                eventHandler.playerPlayToGraveyard(entity: entity, cardId: cardId, turn: eventHandler.turnNumber(), playersTurn: eventHandler.playerEntity?.isCurrentPlayer ?? false)
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentPlayToGraveyard(entity: entity, cardId: cardId,
                                                     turn: eventHandler.turnNumber(),
                                                     playersTurn: eventHandler.playerEntity?.isCurrentPlayer ?? false)
            }
            
        case .removedfromgame, .setaside:
            if controller == eventHandler.player.id {
                eventHandler.playerRemoveFromPlay(entity: entity, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentRemoveFromPlay(entity: entity, turn: eventHandler.turnNumber())
            }
            
        case .play:
            break
            
        default:
            break
        }
    }

    private func zoneChangeFromHand(eventHandler: PowerEventHandler, id: Int, value: Int,
                                    prevValue: Int, controller: Int, cardId: String?) {
        guard let zoneValue = Zone(rawValue: value), let entity = eventHandler.entities[id] else { return }
        
        switch zoneValue {
        case .play:
            eventHandler.lastCardPlayed = id
            if controller == eventHandler.player.id {
                eventHandler.playerPlay(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
                var magnetic = false
                if entity.isMinion {
                    if entity.has(tag: .modular) && (eventHandler.playerEntity?.isCurrentPlayer ?? false) {
                        let pos = entity[.zone_position]
                        let neighbour = eventHandler.player?.board.first { x in x[.zone_position] == pos + 1 }
                        magnetic = neighbour?.card.race == .mechanical
                    }
                    if !magnetic {
                        eventHandler.playerMinionPlayed(entity: entity)
                    }
                }
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentPlay(entity: entity, cardId: cardId, from: entity[.zone_position],
                                  turn: eventHandler.turnNumber())
            }
            
        case .removedfromgame, .setaside, .graveyard:
            if controller == eventHandler.player.id {
                eventHandler.playerHandDiscard(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentHandDiscard(entity: entity, cardId: cardId,
                                         from: entity[.zone_position],
                                         turn: eventHandler.turnNumber())
            }
            
        case .secret:
            if controller == eventHandler.player.id {
                if let prevZone = Zone(rawValue: prevValue) {
                    eventHandler.playerSecretPlayed(entity: entity, cardId: cardId,
                                            turn: eventHandler.turnNumber(), fromZone: prevZone)
                }
            } else if controller == eventHandler.opponent.id {
                if let prevZone = Zone(rawValue: prevValue) {
                    eventHandler.opponentSecretPlayed(entity: entity, cardId: cardId,
                                              from: entity[.zone_position],
                                              turn: eventHandler.turnNumber(),
                                              fromZone: prevZone, otherId: id)
                }
            }
            
        case .deck:
            if controller == eventHandler.player.id {
                eventHandler.playerMulligan(entity: entity, cardId: cardId)
            } else if controller == eventHandler.opponent.id {
                if cardId != nil && cardId != "" {
                    eventHandler.opponentHandToDeck(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
                }
                if eventHandler.opponentEntity?[.mulligan_state] ?? 0 == Mulligan.dealing.rawValue {
                    eventHandler.opponentMulligan(entity: entity, from: entity[.zone_position])
                }
            }
            
        default:
            break
        }
    }

    private func zoneChangeFromDeck(eventHandler: PowerEventHandler, id: Int, value: Int,
                                    prevValue: Int, controller: Int, cardId: String?) {
        guard let zoneValue = Zone(rawValue: value), let entity = eventHandler.entities[id] else { return }
        
        switch zoneValue {
        case .hand:
            if controller == eventHandler.player.id {
                eventHandler.playerDraw(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                let drawerCardId = powerGameStateParser?.getCurrentBlock()?.cardId ?? ""
                var drawerId: Int?
                if drawerCardId != "" {
                    drawerId = eventHandler.entities.first { x in x.value.cardId == drawerCardId }?.value.id
                }
                eventHandler.opponentDraw(entity: entity, turn: eventHandler.turnNumber(), cardId: cardId ?? "", drawerId: drawerId)
            }
            
        case .setaside, .removedfromgame:
            if !eventHandler.setupDone {
                entity.info.created = true
                return
            }
            if controller == eventHandler.player.id {
                if eventHandler.joustReveals > 0 {
                    eventHandler.joustReveals -= 1
                    break
                }
                eventHandler.playerRemoveFromDeck(entity: entity, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                if eventHandler.joustReveals > 0 {
                    eventHandler.joustReveals -= 1
                    break
                }
                eventHandler.opponentRemoveFromDeck(entity: entity, turn: eventHandler.turnNumber())
            }
            
        case .graveyard:
            if controller == eventHandler.player.id {
                eventHandler.playerDeckDiscard(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentDeckDiscard(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            }
            
        case .play:
            if controller == eventHandler.player.id {
                eventHandler.playerDeckToPlay(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            } else if controller == eventHandler.opponent.id {
                eventHandler.opponentDeckToPlay(entity: entity, cardId: cardId, turn: eventHandler.turnNumber())
            }
            
        case .secret:
            if controller == eventHandler.player.id {
                if let prevZone = Zone(rawValue: prevValue) {
                    eventHandler.playerSecretPlayed(entity: entity, cardId: cardId,
                                            turn: eventHandler.turnNumber(), fromZone: prevZone)
                }
            } else if controller == eventHandler.opponent.id {
                if let prevZone = Zone(rawValue: prevValue) {
                    eventHandler.opponentSecretPlayed(entity: entity, cardId: cardId,
                                              from: -1, turn: eventHandler.turnNumber(),
                                              fromZone: prevZone, otherId: id)
                }
            }
            
        default:
            break
        }
    }

    // TODO: this is essentially blocking the global queue!
    private func setHeroAsync(eventHandler: PowerEventHandler, id: Int) {
        logger.info("Found hero with id \(id) ")
        DispatchQueue.global().async {
            if eventHandler.playerEntity == nil {
                logger.info("Waiting for playerEntity")
                while eventHandler.playerEntity == nil {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }

            if let playerEntity = eventHandler.playerEntity,
                let entity = eventHandler.entities[id] {
                logger.info("playerEntity found playerClass : "
                    + "\(String(describing: eventHandler.player.playerClass)), "
                    + "\(id) -> \(playerEntity[.hero_entity]) -> \(entity) ")
                if id == playerEntity[.hero_entity] {
                    let cardId = entity.cardId
                    DispatchQueue.main.async {
                        eventHandler.set(playerHero: cardId)
                    }
                    return
                }
            }

            if eventHandler.opponentEntity == nil {
                logger.info("Waiting for opponentEntity")
                while eventHandler.opponentEntity == nil {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            if let opponentEntity = eventHandler.opponentEntity,
                let entity = eventHandler.entities[id] {
                logger.info("opponentEntity found playerClass : "
                    + "\(String(describing: eventHandler.opponent.playerClass)),"
                    + " \(id) -> \(opponentEntity[.hero_entity]) -> \(entity) ")

                if id == opponentEntity[.hero_entity] {
                    let cardId = entity.cardId
                    DispatchQueue.main.async {
                        eventHandler.set(opponentHero: cardId)
                    }
                    return
                }
            }
        }
    }
    
    private func playerTechLevel(eventHandler: PowerEventHandler, id: Int, value: Int, previous: Int) {
        if value != 0 && value > previous {
            if let entity = eventHandler.entities[id] {
                eventHandler.handlePlayerTechLevel(entity: entity, techLevel: value)
            }
        }
    }
    
    private func playerTriples(eventHandler: PowerEventHandler, id: Int, value: Int, previous: Int) {
        if value != 0 && value > previous {
            if let entity = eventHandler.entities[id] {
                eventHandler.handlePlayerTriples(entity: entity, triples: value - previous)
            }
        }
    }
}
