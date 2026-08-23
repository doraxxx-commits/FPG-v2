import 'dart:math';

import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import 'injury_engine.dart';
import 'global_match_engine.dart';
import 'fixture_generator.dart';
import '../models/fixture.dart';
import '../models/standing.dart';
import 'squad_ai_engine.dart';
import 'development_engine.dart';
import 'finance_engine.dart';
import 'contract_engine.dart';
import 'retirement_engine.dart';
import 'club_ai_engine.dart';
import 'transfer_engine.dart';
import 'world_event_engine.dart';
import 'manager_world_engine.dart';
import 'world_history_engine.dart';
import 'world_simulation_4_engine.dart';

/// Główny koordynator symulacji świata FPG.
///
/// Ten silnik nie steruje UI ani karierą gracza. Jego zadaniem jest
/// sprawić, aby świat AI rozwijał się niezależnie od tego, co robi gracz.
class WorldEngine {
  final List<Club> clubs;
  final List<Player> players;
  final List<League> leagues;
  final Random _random;
  late final SquadAIEngine squadAI;
  late final InjuryEngine injuryEngine;
  late final GlobalMatchEngine globalMatchEngine;
  late final DevelopmentEngine developmentEngine;
  late final FinanceEngine financeEngine;
  late final ContractEngine contractEngine;
  late final RetirementEngine retirementEngine;
  late final ClubAIEngine clubAIEngine;
  late final TransferEngine transferEngine;
  late final WorldEventEngine worldEventEngine;
  late final ManagerWorldEngine managerWorldEngine;
  late final WorldHistoryEngine worldHistoryEngine;
  late final WorldSimulation4Engine worldSimulation4Engine;
  final Map<String, List<Fixture>> fixturesByLeague = {};
  final Map<String, Map<String, Standing>> standingsByLeague = {};

  WorldEngine({
    required this.clubs,
    required this.players,
    required this.leagues,
    Random? random,
  }) : _random = random ?? Random() {
    squadAI = SquadAIEngine(random: _random);
    injuryEngine = InjuryEngine(random: _random);
    globalMatchEngine = GlobalMatchEngine(random: _random);
    developmentEngine = DevelopmentEngine(random: _random);
    financeEngine = FinanceEngine();
    contractEngine = ContractEngine(random: _random);
    retirementEngine = RetirementEngine(random: _random);
    clubAIEngine = ClubAIEngine(random: _random);
    transferEngine = TransferEngine(random: _random);
    worldEventEngine = WorldEventEngine(random: _random);
    managerWorldEngine = ManagerWorldEngine(random: _random);
    worldHistoryEngine = WorldHistoryEngine(random: _random);
    worldSimulation4Engine = WorldSimulation4Engine(random: _random);
    _initializeGlobalLeagues();
  }

  /// Uruchamiane raz na każdy dzień świata.
  void processDay({
    required int year,
    required int month,
    required int day,
    required bool summerTransferWindow,
    required bool winterTransferWindow,
  }) {
    _syncClubRosters();
    _simulateGlobalMatches(year, month, day);
    final absoluteDay = _absoluteDay(year, month, day);
    _processPlayerDailyState();
    injuryEngine.processDay(players);
    _processSquadAI(absoluteDay);
    managerWorldEngine.processDay(clubs);
    _processWeeklyClubEconomy(year, month, day);
    // Powroty z wypożyczeń i codzienny obieg rynku są częścią świata,
    // nawet gdy nie trwa okno transferowe.
    transferEngine.processWindow(
      clubs: clubs, players: players, summer: false, winter: false,
    );
    _processLivingClubDynamics();
    worldSimulation4Engine.processDay(
      clubs: clubs,
      players: players,
      absoluteDay: absoluteDay,
      year: year,
      month: month,
      day: day,
      transferWindow: summerTransferWindow || winterTransferWindow,
    );
    _recalculateClubStrength();
    worldEventEngine.absorbExternalEvents(worldSimulation4Engine.recentEvents);
    worldSimulation4Engine.recentEvents.clear();
    worldEventEngine.processDay(
      year: year,
      month: month,
      day: day,
      clubs: clubs,
      players: players,
    );

    if (summerTransferWindow || winterTransferWindow) {
      _processTransferMarket(
        isSummer: summerTransferWindow,
        isWinter: winterTransferWindow,
      );
    }
  }


  void _initializeGlobalLeagues() {
    final grouped = <String, List<Club>>{};
    for (final club in clubs) {
      grouped.putIfAbsent(club.leagueId, () => []).add(club);
    }
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;
      final leagueId = entry.key;
      fixturesByLeague[leagueId] = FixtureGenerator.generateSeasonFixtures(
        entry.value,
        seasonStartYear: 2026,
      );
      standingsByLeague[leagueId] = {
        for (final club in entry.value) club.id: Standing(clubId: club.id),
      };
    }
  }

  void _simulateGlobalMatches(int year, int month, int day) {
    for (final entry in fixturesByLeague.entries) {
      // The career league is currently simulated by GameEngine so the
      // player's interactive match can consume its exact result.
      if (entry.key == 'pol_ek') continue;
      final standings = standingsByLeague[entry.key];
      if (standings == null) continue;

      for (final fixture in entry.value) {
        if (fixture.played || fixture.year != year || fixture.month != month || fixture.day != day) continue;
        final home = _findClub(fixture.homeClubId);
        final away = _findClub(fixture.awayClubId);
        if (home == null || away == null) continue;
        final homePlayers = _playersOfClub(home.id);
        final awayPlayers = _playersOfClub(away.id);
        final result = globalMatchEngine.simulate(
          home: home, away: away,
          homePlayers: homePlayers, awayPlayers: awayPlayers,
          rivalryIntensity: worldSimulation4Engine.rivalryEngine.intensityBetween(home.id, away.id),
        );
        fixture.played = true;
        fixture.homeGoals = result.homeGoals;
        fixture.awayGoals = result.awayGoals;
        _recordStanding(standings, result);
        _applyMatchConsequences(
          home: home,
          away: away,
          result: result,
          absoluteDay: _absoluteDay(year, month, day),
        );
      }
    }
  }

  void _applyMatchConsequences({
    required Club home,
    required Club away,
    required dynamic result,
    required int absoluteDay,
  }) {
    final homeWin = result.homeGoals > result.awayGoals;
    final awayWin = result.awayGoals > result.homeGoals;
    final draw = result.homeGoals == result.awayGoals;

    _updateClubMatchMemory(home, result.homeGoals, result.awayGoals,
        win: homeWin, draw: draw, absoluteDay: absoluteDay);
    _updateClubMatchMemory(away, result.awayGoals, result.homeGoals,
        win: awayWin, draw: draw, absoluteDay: absoluteDay);

    final allPerformances = result.playerPerformances as List;
    for (final raw in allPerformances) {
      final performance = raw;
      final player = players.where((p) => p.id == performance.playerId).firstOrNull;
      if (player == null) continue;

      // Dobry występ buduje pewność siebie, słaby ją zabiera. Reakcja jest
      // mała, bo forma ma wynikać z wielu meczów, nie z jednego rzutu kością.
      if (performance.rating >= 8.0) {
        player.morale = min(100, player.morale + 2);
        player.managerRelationship = min(100, player.managerRelationship + 1);
      } else if (performance.rating < 5.7) {
        player.morale = max(20, player.morale - 2);
      }

      if (performance.minutes >= 75 && player.fatigue >= 75) {
        player.fitness = max(0, player.fitness - 2);
      }
    }

    // Seria wyników wpływa na całą atmosferę. Dodatni momentum daje mały
    // bonus, kryzys działa odwrotnie. Nie zmieniamy OVR — zmieniamy warunki,
    // w których OVR jest wykorzystywany przez następne mecze.
    for (final club in [home, away]) {
      final pressure = club.lossesStreak >= 4 ? 2 : club.winsStreak >= 4 ? -2 : 0;
      club.boardPressure = (club.boardPressure + pressure).clamp(10, 100);
      if (club.lossesStreak >= 5) {
        club.stability = max(10, club.stability - 2);
        club.fanSupport = max(10, club.fanSupport - 2);
      } else if (club.winsStreak >= 5) {
        club.stability = min(100, club.stability + 1);
        club.fanSupport = min(100, club.fanSupport + 2);
      }
    }
  }

  void _updateClubMatchMemory(
    Club club,
    int goalsFor,
    int goalsAgainst, {
    required bool win,
    required bool draw,
    required int absoluteDay,
  }) {
    club.matchesPlayedThisSeason++;
    club.goalsForThisSeason += goalsFor;
    club.goalsAgainstThisSeason += goalsAgainst;
    club.lastMatchAbsoluteDay = absoluteDay;

    if (goalsAgainst == 0) club.cleanSheetsThisSeason++;

    if (draw) {
      club.lastResult = 'draw';
      club.winsStreak = 0;
      club.lossesStreak = 0;
      club.unbeatenStreak++;
    } else if (win) {
      club.lastResult = 'win';
      club.winsStreak++;
      club.lossesStreak = 0;
      club.unbeatenStreak++;
    } else {
      club.lastResult = 'loss';
      club.winsStreak = 0;
      club.lossesStreak++;
      club.unbeatenStreak = 0;
    }
  }

  void _recordStanding(Map<String, Standing> standings, dynamic result) {
    final home = standings[result.homeClubId];
    final away = standings[result.awayClubId];
    if (home == null || away == null) return;
    home.played++; away.played++;
    home.goalsFor = (home.goalsFor + result.homeGoals).toInt();
    home.goalsAgainst = (home.goalsAgainst + result.awayGoals).toInt();
    away.goalsFor = (away.goalsFor + result.awayGoals).toInt();
    away.goalsAgainst = (away.goalsAgainst + result.homeGoals).toInt();

    if (result.homeGoals > result.awayGoals) { home.wins++; away.losses++; }
    else if (result.homeGoals < result.awayGoals) { away.wins++; home.losses++; }
    else { home.draws++; away.draws++; }
  }

  List<Standing> tableForLeague(String leagueId) {
    final table = [...(standingsByLeague[leagueId]?.values ?? const <Standing>[])];
    table.sort((a, b) {
      final points = b.points.compareTo(a.points);
      if (points != 0) return points;
      final gd = b.goalDifference.compareTo(a.goalDifference);
      if (gd != 0) return gd;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return table;
  }

  /// Uruchamiane na koniec sezonu, zanim świat rozpocznie kolejny rok.
  void processEndOfSeason({required int nextSeasonStartYear}) {
    _syncClubRosters();

    // Najpierw cały świat starzeje się o jeden sezon.
    for (final player in players) {
      player.age++;
    }

    // Kolejność jest celowa: najpierw rozwój, następnie finanse i kontrakty,
    // potem emerytury/regeneracja. Dzięki temu nowe pokolenie wchodzi do
    // świata dopiero po zakończeniu pełnego sezonu.
    developmentEngine.processSeason(players);
    financeEngine.processSeason(clubs);
    contractEngine.processSeason(clubs, players);
    retirementEngine.processSeason(players: players, clubs: clubs);
    worldSimulation4Engine.processSeason(
      clubs: clubs,
      players: players,
      seasonYear: nextSeasonStartYear,
    );

    _syncClubRosters();
    _applySeasonFinancialMovement();

    // Zapamiętujemy sezon przed zmianą poziomów lig. Historia ma opisywać
    // to, co klub faktycznie osiągnął, a nie jego nową ligę.
    final seasonPositions = <String, int>{};
    for (final league in leagues) {
      final table = tableForLeague(league.id);
      for (var i = 0; i < table.length; i++) {
        seasonPositions[table[i].clubId] = i + 1;
      }
    }
    worldHistoryEngine.processSeason(clubs: clubs, positions: seasonPositions);

    _applyPromotionAndRelegation();
    _syncClubRosters();
    _recalculateClubStrength();

    for (final club in clubs) {
      club.winsStreak = 0;
      club.unbeatenStreak = 0;
      club.lossesStreak = 0;
      club.matchesPlayedThisSeason = 0;
      club.goalsForThisSeason = 0;
      club.goalsAgainstThisSeason = 0;
      club.cleanSheetsThisSeason = 0;
      club.lastResult = 'none';
      club.lastMatchAbsoluteDay = 0;
    }

    // Reset autonomicznych rozgrywek na nowy sezon.
    fixturesByLeague.clear();
    standingsByLeague.clear();
    final grouped = <String, List<Club>>{};
    for (final club in clubs) {
      grouped.putIfAbsent(club.leagueId, () => []).add(club);
    }
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;
      fixturesByLeague[entry.key] = FixtureGenerator.generateSeasonFixtures(
        entry.value,
        seasonStartYear: nextSeasonStartYear,
      );
      standingsByLeague[entry.key] = {
        for (final club in entry.value) club.id: Standing(clubId: club.id),
      };
    }
  }

  void _applyPromotionAndRelegation() {
    // Każdy kraj może posiadać kilka poziomów. Zamieniamy tylko kluby, które
    // faktycznie należą do sąsiadujących poziomów tego samego kraju.
    for (final country in leagues.map((l) => l.country).toSet()) {
      final countryLeagues = leagues.where((l) => l.country == country).toList()
        ..sort((a, b) => a.level.compareTo(b.level));

      for (var i = 0; i < countryLeagues.length - 1; i++) {
        final upper = countryLeagues[i];
        final lower = countryLeagues[i + 1];
        final upperTable = tableForLeague(upper.id);
        final lowerTable = tableForLeague(lower.id);
        if (upperTable.length < 2 || lowerTable.length < 2) continue;

        final relegatedCount = min(2, upperTable.length);
        final promotedCount = min(2, lowerTable.length);
        final relegated = upperTable.reversed.take(relegatedCount).map((s) => _findClub(s.clubId)).whereType<Club>().toList();
        final promoted = lowerTable.take(promotedCount).map((s) => _findClub(s.clubId)).whereType<Club>().toList();

        for (final club in relegated) club.leagueId = lower.id;
        for (final club in promoted) club.leagueId = upper.id;
      }
    }
  }

  void _applySeasonFinancialMovement() {
    for (final club in clubs) {
      // Nagrody i przychody sezonowe rosną wraz z poziomem klubu.
      final seasonIncome =
          250000 + (club.overall * 18000) + (club.reputation * 6000);

      // Słaba kondycja finansowa zwiększa presję na zarząd.
      final financialPenalty = (100 - club.financialHealth) * 5000;

      club.budget = max(0, club.budget + seasonIncome - financialPenalty);

      if (club.budget < 1000000) {
        club.financialHealth = max(10, club.financialHealth - 3);
      } else if (club.budget > 50000000) {
        club.financialHealth = min(100, club.financialHealth + 2);
      }
    }
  }

  void _syncClubRosters() {
    for (final club in clubs) {
      club.playerIds.clear();
    }

    for (final player in players) {
      final clubId = player.clubId;
      if (clubId == null) continue;

      final club = _findClub(clubId);
      club?.addPlayer(player.id);
    }
  }

  void _processPlayerDailyState() {
    for (final player in players) {
      // Świat AI regeneruje się także wtedy, gdy gracz niczego nie robi.
      if (player.fatigue > 0) {
        final recovery = player.fatigue >= 75 ? 3 : 5;
        player.fatigue = max(0, player.fatigue - recovery);
      }

      if (player.fitness < 100 && player.fatigue < 45) {
        player.fitness = min(100, player.fitness + 1);
      }

      // Forma nie skacze losowo o kilkanaście punktów. Powoli wraca do
      // poziomu neutralnego, a zmęczenie przesuwa ją w dół.
      if (player.form > 70) {
        player.form--;
      } else if (player.form < 70) {
        player.form++;
      }

      if (player.injured) {
        player.form = max(0, player.form - 1);
      }

      if (player.fatigue >= 75) {
        player.form = max(0, player.form - 1);
        player.morale = max(0, player.morale - 1);
      }
    }
  }


  void _processSquadAI(int absoluteDay) {
    for (final club in clubs) {
      squadAI.processClub(
        club: club,
        players: players,
        absoluteDay: absoluteDay,
      );
    }
  }

  void _processWeeklyClubEconomy(int year, int month, int day) {
    final absoluteDay = _absoluteDay(year, month, day);
    if (absoluteDay % 7 != 0) return;
    financeEngine.processWeekly(clubs, players);
  }

  void _recalculateClubStrength() {
    for (final club in clubs) {
      final squad = _playersOfClub(club.id);
      if (squad.isEmpty) continue;

      final sorted = [...squad]
        ..sort((a, b) => b.overall.compareTo(a.overall));

      final relevant = sorted.take(18).toList();
      double weightedSum = 0;
      double weights = 0;

      for (var i = 0; i < relevant.length; i++) {
        final weight = i < 11 ? 1.0 : 0.45;
        weightedSum += relevant[i].overall * weight;
        weights += weight;
      }

      if (weights == 0) continue;

      final squadStrength = weightedSum / weights;
      final financialModifier = (club.financialHealth - 70) * 0.025;
      final target = (squadStrength + financialModifier).clamp(1.0, 99.0);

      // OVR klubu zmienia się stopniowo. Jeden transfer nie powinien nagle
      // przeskoczyć klubu z 70 do 85.
      final delta = target - club.overall;
      final step = delta.clamp(-2.0, 2.0);
      club.overall = (club.overall + step).round().clamp(1, 99).toInt();
    }
  }

  void _processLivingClubDynamics() {
    for (final club in clubs) {
      final squad = _playersOfClub(club.id);
      if (squad.isEmpty) continue;

      final avgForm = squad.fold<double>(0, (sum, p) => sum + p.form) / squad.length;
      final avgMorale = squad.fold<double>(0, (sum, p) => sum + p.morale) / squad.length;
      final avgFitness = squad.fold<double>(0, (sum, p) => sum + p.fitness) / squad.length;

      // Wyniki i atmosfera wpływają na kibiców, zarząd i stabilność.
      if (avgForm >= 76 && avgMorale >= 70) {
        club.fanSupport = min(100, club.fanSupport + 1);
        club.stability = min(100, club.stability + 1);
        club.boardPressure = max(20, club.boardPressure - 1);
      } else if (avgForm <= 58 || avgMorale <= 45) {
        club.fanSupport = max(10, club.fanSupport - 1);
        club.stability = max(10, club.stability - 1);
        club.boardPressure = min(100, club.boardPressure + 1);
      }

      // Silny trener i akademia mają znaczenie w długim okresie, ale nie
      // powinny magicznie zmieniać klub z dnia na dzień.
      if (club.financialHealth >= 70 && club.academyQuality >= 70) {
        club.stability = min(100, club.stability + 1);
      }
      if (avgFitness < 55) {
        club.stability = max(10, club.stability - 1);
      }

      // Presja zarządu rośnie również wtedy, gdy klub jest drogi w utrzymaniu.
      final wageBill = squad.fold<double>(0, (sum, p) => sum + p.weeklyWage);
      if (club.budget < wageBill * 4) {
        club.boardPressure = min(100, club.boardPressure + 1);
      }
    }
  }

  void _processTransferMarket({
    required bool isSummer,
    required bool isWinter,
  }) {
    transferEngine.processWindow(
      clubs: clubs,
      players: players,
      summer: isSummer,
      winter: isWinter,
    );
    _syncClubRosters();
    _recalculateClubStrength();
  }

  double _transferScore(Club buyer, Player player) {
    final ageDistance = player.age < buyer.preferredMinAge
        ? buyer.preferredMinAge - player.age
        : player.age > buyer.preferredMaxAge
            ? player.age - buyer.preferredMaxAge
            : 0;

    final potentialBonus = max(0, player.potential - player.overall) *
        (buyer.youthFocus / 100.0);
    final reputationBonus = buyer.reputation * 0.03;

    return player.overall * 2.2 +
        potentialBonus -
        ageDistance * 2.5 +
        reputationBonus;
  }

  int _calculateTransferFee(Player player, Club buyer) {
    final ageFactor = player.age <= 23
        ? 1.25
        : player.age <= 28
            ? 1.05
            : 0.75;

    final clubFactor = 0.85 + buyer.reputation / 300.0;
    return max(
      250000,
      (player.value * ageFactor * clubFactor).round(),
    );
  }

  List<Player> _playersOfClub(String clubId) =>
      players.where((player) => player.clubId == clubId).toList();

  Club? _findClub(String id) {
    for (final club in clubs) {
      if (club.id == id) return club;
    }
    return null;
  }

  int _absoluteDay(int year, int month, int day) {
    var total = 0;
    for (var y = 1; y < year; y++) {
      total += _isLeapYear(y) ? 366 : 365;
    }

    const monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    for (var m = 1; m < month; m++) {
      total += monthDays[m - 1];
      if (m == 2 && _isLeapYear(year)) total++;
    }

    return total + day;
  }

  bool _isLeapYear(int year) {
    return year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
  }
}


extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
