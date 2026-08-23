// ==========================================================
// WYDARZENIE ZAWODNIKA W MECZU
// ==========================================================

class PlayerMatchEvent {
  final String playerId;

  final int minute;

  final String type;

  final double? rating;

  PlayerMatchEvent({
    required this.playerId,
    required this.minute,
    required this.type,
    this.rating,
  });
}

// ==========================================================
// STATYSTYKI ZAWODNIKA W MECZU
// ==========================================================

class PlayerMatchPerformance {
  final String playerId;

  final int minutes;
  final bool started;

  final double rating;

  final int goals;
  final int assists;

  final int shots;
  final int shotsOnTarget;

  final int keyPasses;
  final int successfulDribbles;

  final int yellowCards;
  final int redCards;

  PlayerMatchPerformance({
    required this.playerId,
    required this.minutes,
    required this.started,
    required this.rating,
    this.goals = 0,
    this.assists = 0,
    this.shots = 0,
    this.shotsOnTarget = 0,
    this.keyPasses = 0,
    this.successfulDribbles = 0,
    this.yellowCards = 0,
    this.redCards = 0,
  });
}

// ==========================================================
// WYNIK MECZU
// ==========================================================

class MatchResult {
  final String homeClubId;
  final String awayClubId;

  final int homeGoals;
  final int awayGoals;

  // ==========================================================
  // WYDARZENIA MECZOWE
  // ==========================================================

  final List<PlayerMatchEvent> events;

  // ==========================================================
  // STATYSTYKI ZAWODNIKÓW
  // ==========================================================

  final List<PlayerMatchPerformance> playerPerformances;

  // ==========================================================
  // KONSTRUKTOR
  // ==========================================================

  MatchResult({
    required this.homeClubId,
    required this.awayClubId,
    required this.homeGoals,
    required this.awayGoals,
    this.events = const [],
    this.playerPerformances = const [],
  });

  // ==========================================================
  // CZY BYŁ REMIS
  // ==========================================================

  bool get isDraw {
    return homeGoals == awayGoals;
  }

  // ==========================================================
  // CZY WYGRAŁ GOSPODARZ
  // ==========================================================

  bool get homeWon {
    return homeGoals > awayGoals;
  }

  // ==========================================================
  // CZY WYGRAŁ GOŚĆ
  // ==========================================================

  bool get awayWon {
    return awayGoals > homeGoals;
  }

  // ==========================================================
  // ŁĄCZNA LICZBA GOLI
  // ==========================================================

  int get totalGoals {
    return homeGoals + awayGoals;
  }

  // ==========================================================
  // WYSZUKIWANIE WYSTĘPU ZAWODNIKA
  // ==========================================================

  PlayerMatchPerformance? performanceForPlayer(
    String playerId,
  ) {
    for (final performance
        in playerPerformances) {
      if (performance.playerId == playerId) {
        return performance;
      }
    }

    return null;
  }

  // ==========================================================
  // CZY ZAWODNIK ZDOBYŁ GOLA
  // ==========================================================

  bool playerScored(
    String playerId,
  ) {
    final performance =
        performanceForPlayer(playerId);

    if (performance == null) {
      return false;
    }

    return performance.goals > 0;
  }

  // ==========================================================
  // CZY ZAWODNIK ZALICZYŁ ASYSTĘ
  // ==========================================================

  bool playerAssisted(
    String playerId,
  ) {
    final performance =
        performanceForPlayer(playerId);

    if (performance == null) {
      return false;
    }

    return performance.assists > 0;
  }

  // ==========================================================
  // CZY ZAWODNIK WYSTĄPIŁ
  // ==========================================================

  bool playerAppeared(
    String playerId,
  ) {
    final performance =
        performanceForPlayer(playerId);

    if (performance == null) {
      return false;
    }

    return performance.minutes > 0;
  }
}
