import 'dart:math';

import '../models/club.dart';
import '../models/match_result.dart';
import '../models/player_career.dart';
import 'match_simulation_core.dart';

class MatchEngine {
  final Random _random;
  late final MatchSimulationCore core;

  MatchEngine({
    Random? random,
  }) : _random = random ?? Random() {
    core = MatchSimulationCore(random: _random);
  }

  // ==========================================================
  // SYMULACJA MECZU
  // ==========================================================

  MatchResult simulate({
    required Club home,
    required Club away,

    // Opcjonalne składy zawodników.
    List<PlayerCareer> homePlayers = const [],
    List<PlayerCareer> awayPlayers = const [],
  }) {
    final coreResult = core.simulate(
      home: _teamInput(home, homePlayers),
      away: _teamInput(away, awayPlayers),
    );

    final homeGoals = coreResult.homeGoals;
    final awayGoals = coreResult.awayGoals;

    // ==========================================================
    // STATYSTYKI INDYWIDUALNE
    // ==========================================================

    final playerPerformances =
        <PlayerMatchPerformance>[];

    final events =
        <PlayerMatchEvent>[];

    // ----------------------------------------------------------
    // WYSTĘPY GOSPODARZY
    // ----------------------------------------------------------

    playerPerformances.addAll(
      _generatePlayerPerformances(
        players: homePlayers,
        teamGoals: homeGoals,
        teamWon: homeGoals > awayGoals,
        teamDraw: homeGoals == awayGoals,
        events: events,
      ),
    );

    // ----------------------------------------------------------
    // WYSTĘPY GOŚCI
    // ----------------------------------------------------------

    playerPerformances.addAll(
      _generatePlayerPerformances(
        players: awayPlayers,
        teamGoals: awayGoals,
        teamWon: awayGoals > homeGoals,
        teamDraw: homeGoals == awayGoals,
        events: events,
      ),
    );

    // ==========================================================
    // WYNIK MECZU
    // ==========================================================

    return MatchResult(
      homeClubId: home.id,
      awayClubId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: events,
      playerPerformances: playerPerformances,
    );
  }

  MatchSimulationTeamInput _teamInput(Club club, List<PlayerCareer> players) {
    double avg(List<double> values, double fallback) => values.isEmpty ? fallback : values.reduce((a, b) => a + b) / values.length;
    return MatchSimulationTeamInput(
      playerAverage: avg(players.map((p) => p.overall.toDouble()).toList(), club.overall.toDouble()),
      formAverage: avg(players.map((p) => p.form.toDouble()).toList(), 70),
      fitnessAverage: avg(players.map((p) => p.fitness.toDouble()).toList(), 75),
      moraleAverage: avg(players.map((p) => p.morale.toDouble()).toList(), 70),
      clubOverall: club.overall,
      financialHealth: club.financialHealth,
      reputation: club.reputation,
    );
  }

  // ==========================================================
  // GENEROWANIE WYSTĘPÓW ZAWODNIKÓW
  // ==========================================================

  List<PlayerMatchPerformance>
      _generatePlayerPerformances({
    required List<PlayerCareer> players,
    required int teamGoals,
    required bool teamWon,
    required bool teamDraw,
    required List<PlayerMatchEvent> events,
  }) {
    if (players.isEmpty) {
      return [];
    }

    final performances =
        <PlayerMatchPerformance>[];

    final availablePlayers =
        List<PlayerCareer>.from(players);

    availablePlayers.shuffle(_random);

    final starters =
        availablePlayers.take(11).toList();

    // ========================================================
    // PODSTAWOWY SKŁAD
    // ========================================================

    for (final player in starters) {
      final minutes =
          _generateStarterMinutes(player);

      final rating =
          _generatePlayerRating(
        player,
        teamWon: teamWon,
        teamDraw: teamDraw,
        minutes: minutes,
      );

      final performance =
          PlayerMatchPerformance(
        playerId: player.id,
        minutes: minutes,
        started: true,
        rating: rating,
      );

      performances.add(performance);

      events.add(
        PlayerMatchEvent(
          playerId: player.id,
          minute: 1,
          type: 'start',
          rating: rating,
        ),
      );
    }

    // ========================================================
    // REZERWOWY
    // ========================================================

    final substitutes =
        availablePlayers
            .skip(11)
            .take(5)
            .toList();

    for (final player in substitutes) {
      final enters =
          _random.nextDouble() < 0.45;

      if (!enters) {
        continue;
      }

      final minutes =
          randomInt(10, 35);

      final entryMinute =
          randomInt(46, 80);

      final rating =
          _generatePlayerRating(
        player,
        teamWon: teamWon,
        teamDraw: teamDraw,
        minutes: minutes,
      );

      final performance =
          PlayerMatchPerformance(
        playerId: player.id,
        minutes: minutes,
        started: false,
        rating: rating,
      );

      performances.add(performance);

      events.add(
        PlayerMatchEvent(
          playerId: player.id,
          minute: entryMinute,
          type: 'substitution_in',
          rating: rating,
        ),
      );
    }

    // ========================================================
    // ROZDZIELENIE GOLI
    // ========================================================

    _assignGoals(
      performances: performances,
      goals: teamGoals,
      events: events,
    );

    // ========================================================
    // ASYSTY
    // ========================================================

    _assignAssists(
      performances: performances,
      goals: teamGoals,
    );

    // ========================================================
    // DODATKOWE STATYSTYKI
    // ========================================================

    for (final performance in performances) {
      _generateAdditionalStats(
        performance,
      );
    }

    return performances;
  }

  // ==========================================================
  // MINUTY PODSTAWOWEGO ZAWODNIKA
  // ==========================================================

  int _generateStarterMinutes(
    PlayerCareer player,
  ) {
    if (player.fatigue >= 80) {
      return randomInt(55, 80);
    }

    if (player.fitness <= 50) {
      return randomInt(60, 85);
    }

    return randomInt(80, 95);
  }

  // ==========================================================
  // OCENA ZAWODNIKA
  // ==========================================================

  double _generatePlayerRating(
    PlayerCareer player, {
    required bool teamWon,
    required bool teamDraw,
    required int minutes,
  }) {
    double rating = 6.0;

    rating +=
        (player.overall - 60) * 0.025;

    rating +=
        (player.form - 70) * 0.015;

    rating +=
        (player.fitness - 70) * 0.01;

    if (teamWon) {
      rating += 0.45;
    } else if (teamDraw) {
      rating += 0.10;
    } else {
      rating -= 0.30;
    }

    rating +=
        randomDouble(-0.65, 0.65);

    if (minutes < 30) {
      rating -= 0.15;
    }

    return rating.clamp(4.0, 10.0);
  }

  // ==========================================================
  // PRZYPISANIE GOLI
  // ==========================================================

  void _assignGoals({
    required List<PlayerMatchPerformance> performances,
    required int goals,
    required List<PlayerMatchEvent> events,
  }) {
    if (goals <= 0 || performances.isEmpty) {
      return;
    }

    for (int i = 0; i < goals; i++) {
      final player =
          _selectGoalScorer(performances);

      if (player == null) {
        continue;
      }

      final index =
          performances.indexOf(player);

      final updated =
          PlayerMatchPerformance(
        playerId: player.playerId,
        minutes: player.minutes,
        started: player.started,
        rating: (player.rating + 0.20)
            .clamp(0.0, 10.0),
        goals: player.goals + 1,
        assists: player.assists,
        shots: player.shots + 1,
        shotsOnTarget:
            player.shotsOnTarget + 1,
        keyPasses: player.keyPasses,
        successfulDribbles:
            player.successfulDribbles,
        yellowCards:
            player.yellowCards,
        redCards:
            player.redCards,
      );

      performances[index] = updated;

      events.add(
        PlayerMatchEvent(
          playerId: player.playerId,
          minute: randomInt(5, 90),
          type: 'goal',
          rating: updated.rating,
        ),
      );
    }
  }

  // ==========================================================
  // WYBÓR STRZELCA
  // ==========================================================

  PlayerMatchPerformance?
      _selectGoalScorer(
    List<PlayerMatchPerformance> performances,
  ) {
    if (performances.isEmpty) {
      return null;
    }

    final weightedPlayers =
        <PlayerMatchPerformance>[];

    for (final performance in performances) {
      final weight =
          performance.started ? 3 : 1;

      for (int i = 0; i < weight; i++) {
        weightedPlayers.add(performance);
      }
    }

    return weightedPlayers[
        _random.nextInt(weightedPlayers.length)];
  }

  // ==========================================================
  // PRZYPISANIE ASYST
  // ==========================================================

  void _assignAssists({
    required List<PlayerMatchPerformance> performances,
    required int goals,
  }) {
    if (goals <= 0 ||
        performances.length < 2) {
      return;
    }

    for (int i = 0; i < goals; i++) {
      if (_random.nextDouble() > 0.75) {
        continue;
      }

      final candidates =
          List<PlayerMatchPerformance>.from(
        performances,
      );

      candidates.shuffle(_random);

      final assister =
          candidates.first;

      final index =
          performances.indexOf(assister);

      final updated =
          PlayerMatchPerformance(
        playerId: assister.playerId,
        minutes: assister.minutes,
        started: assister.started,
        rating: (assister.rating + 0.10)
            .clamp(0.0, 10.0),
        goals: assister.goals,
        assists: assister.assists + 1,
        shots: assister.shots,
        shotsOnTarget:
            assister.shotsOnTarget,
        keyPasses:
            assister.keyPasses + 1,
        successfulDribbles:
            assister.successfulDribbles,
        yellowCards:
            assister.yellowCards,
        redCards:
            assister.redCards,
      );

      performances[index] = updated;
    }
  }

  // ==========================================================
  // DODATKOWE STATYSTYKI
  // ==========================================================

  void _generateAdditionalStats(
    PlayerMatchPerformance performance,
  ) {
    final minutes =
        performance.minutes;

    final shots =
        minutes <= 0
            ? 0
            : randomInt(
                0,
                max(
                  1,
                  (minutes / 20).round(),
                ),
              );

    final shotsOnTarget =
        shots <= 0
            ? 0
            : randomInt(
                0,
                shots,
              );

    final keyPasses =
        randomInt(
      0,
      max(
        1,
        (minutes / 25).round(),
      ),
    );

    final successfulDribbles =
        randomInt(
      0,
      max(
        1,
        (minutes / 30).round(),
      ),
    );

    final yellow =
        _random.nextDouble() < 0.12
            ? 1
            : 0;

    final red =
        _random.nextDouble() < 0.015
            ? 1
            : 0;

    if (shots < 0 ||
        shotsOnTarget < 0 ||
        keyPasses < 0 ||
        successfulDribbles < 0 ||
        yellow < 0 ||
        red < 0) {
      return;
    }
  }

  // ==========================================================
  // SIŁA DRUŻYNY
  // ==========================================================

  double _calculateStrength(
    Club club,
    bool home,
  ) {
    double strength =
        club.overall.toDouble();

    if (home) {
      strength += 3;
    }

    strength +=
        club.financialHealth * 0.02;

    strength +=
        club.reputation * 0.01;

    strength +=
        _random.nextDouble() * 8 - 4;

    return strength;
  }

  // ==========================================================
  // GENEROWANIE GOLI
  // ==========================================================

  int _generateGoals(
    double strength,
  ) {
    final normalized =
        ((strength - 55) / 20)
            .clamp(0.2, 2.8);

    final chance =
        _random.nextDouble();

    if (chance < 0.10) {
      return 0;
    }

    if (chance < 0.35) {
      return normalized > 1.5 ? 1 : 0;
    }

    if (chance < 0.75) {
      return normalized
          .round()
          .clamp(0, 3);
    }

    if (chance < 0.95) {
      return (normalized + 1)
          .round()
          .clamp(0, 4);
    }

    return (normalized + 2)
        .round()
        .clamp(0, 5);
  }

  // ==========================================================
  // LOSOWA LICZBA
  // ==========================================================

  int randomInt(
    int min,
    int max,
  ) {
    if (max < min) {
      throw ArgumentError(
        'max nie może być mniejsze od min.',
      );
    }

    return min +
        _random.nextInt(
          max - min + 1,
        );
  }

  // ==========================================================
  // LOSOWA LICZBA ZMIENNOPRZECINKOWA
  // ==========================================================

  double randomDouble(
    double min,
    double max,
  ) {
    if (max < min) {
      throw ArgumentError(
        'max nie może być mniejsze od min.',
      );
    }

    return min +
        _random.nextDouble() *
            (max - min);
  }
}
