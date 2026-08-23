import 'dart:math';

import '../models/club.dart';
import '../models/player.dart';
import '../models/world_event.dart';
import 'agent_engine.dart';
import 'transfer_interest_engine.dart';
import 'negotiation_engine.dart';
import 'dressing_room_engine.dart';
import 'national_team_engine.dart';
import 'academy_engine.dart';
import 'reputation_engine.dart';
import 'rivalry_engine.dart';
import 'player_decision_engine.dart';
import 'loan_negotiation_engine.dart';
import 'contract_negotiation_engine.dart';
import 'board_engine.dart';

/// Warstwa World Simulation 4.0. Nie zastępuje istniejących silników —
/// łączy nowe mechanizmy społeczne i pokoleniowe z obecnym światem.
class WorldSimulation4Engine {
  final Random _random;
  late final AcademyEngine academyEngine;
  late final ReputationEngine reputationEngine;
  late final RivalryEngine rivalryEngine;
  late final AgentEngine agentEngine;
  late final TransferInterestEngine transferInterestEngine;
  late final NegotiationEngine negotiationEngine;
  late final DressingRoomEngine dressingRoomEngine;
  late final NationalTeamEngine nationalTeamEngine;
  late final PlayerDecisionEngine playerDecisionEngine;
  late final LoanNegotiationEngine loanNegotiationEngine;
  late final ContractNegotiationEngine contractNegotiationEngine;
  late final BoardEngine boardEngine;
  final List<WorldEvent> recentEvents = [];

  WorldSimulation4Engine({Random? random}) : _random = random ?? Random() {
    academyEngine = AcademyEngine(random: _random);
    reputationEngine = ReputationEngine();
    rivalryEngine = RivalryEngine(random: _random);
    agentEngine = AgentEngine(random: _random);
    transferInterestEngine = TransferInterestEngine(random: _random);
    negotiationEngine = NegotiationEngine(random: _random);
    dressingRoomEngine = DressingRoomEngine(random: _random);
    nationalTeamEngine = NationalTeamEngine(random: _random);
    playerDecisionEngine = PlayerDecisionEngine(random: _random);
    loanNegotiationEngine = LoanNegotiationEngine(random: _random);
    contractNegotiationEngine = ContractNegotiationEngine(random: _random);
    boardEngine = BoardEngine(random: _random);
  }

  List<String> processDay({required List<Club> clubs, required List<Player> players, int absoluteDay = 0, int year = 0, int month = 0, int day = 0, bool transferWindow = false}) {
    agentEngine.ensureAgents(players);
    agentEngine.processClientGrowth(players);
    nationalTeamEngine.ensureTeams(clubs);
    reputationEngine.processDay(clubs: clubs, players: players);
    final logs = <String>[];
    logs.addAll(boardEngine.processDay(clubs: clubs, players: players));
    transferInterestEngine.processDay(clubs: clubs, players: players, absoluteDay: absoluteDay);
    logs.addAll(playerDecisionEngine.processDay(
      clubs: clubs,
      players: players,
      interests: transferInterestEngine.interests,
      agentEngine: agentEngine,
      absoluteDay: absoluteDay,
    ));
    logs.addAll(dressingRoomEngine.processDay(clubs: clubs, players: players));
    logs.addAll(loanNegotiationEngine.process(
      clubs: clubs, players: players, transferWindow: transferWindow,
    ));
    logs.addAll(negotiationEngine.process(
      clubs: clubs,
      players: players,
      interestEngine: transferInterestEngine,
      transferWindow: transferWindow,
      agentEngine: agentEngine,
    ));
    logs.addAll(contractNegotiationEngine.process(
      clubs: clubs,
      players: players,
      agentEngine: agentEngine,
    ));
    for (final log in logs) {
      recentEvents.add(WorldEvent(
        year: year, month: month, day: day, type: log.startsWith('NAPIĘCIE') ? 'dressing_room' : 'transfer_negotiation',
        title: log.split(':').first, description: log, importance: 2,
      ));
    }
    if (recentEvents.length > 300) recentEvents.removeRange(0, recentEvents.length - 300);
    return logs;
  }

  List<Player> processSeason({
    required List<Club> clubs,
    required List<Player> players,
    required int seasonYear,
  }) {
    final generated = academyEngine.generateSeasonTalents(
      clubs: clubs,
      players: players,
      seasonYear: seasonYear,
    );
    rivalryEngine.processSeason(clubs);
    agentEngine.ensureAgents(players);
    nationalTeamEngine.processSeason(clubs: clubs, players: players, seasonYear: seasonYear);
    reputationEngine.processDay(clubs: clubs, players: players);
    return generated;
  }
}
