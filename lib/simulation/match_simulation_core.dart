import 'dart:math';

/// Wspólny, UI-niezależny rdzeń symulacji meczu.
/// GlobalMatchEngine i MatchEngine korzystają z tych samych zasad wyliczania
/// siły zespołu i oczekiwanych goli; różnią się tylko warstwą danych oraz prezentacją.
class MatchSimulationTeamInput {
  final double playerAverage;
  final double formAverage;
  final double fitnessAverage;
  final double moraleAverage;
  final int clubOverall;
  final int financialHealth;
  final int reputation;

  const MatchSimulationTeamInput({
    required this.playerAverage,
    required this.formAverage,
    required this.fitnessAverage,
    required this.moraleAverage,
    required this.clubOverall,
    required this.financialHealth,
    required this.reputation,
  });
}

class MatchSimulationCoreResult {
  final int homeGoals;
  final int awayGoals;
  final double homeStrength;
  final double awayStrength;
  final double homeXg;
  final double awayXg;

  const MatchSimulationCoreResult({
    required this.homeGoals,
    required this.awayGoals,
    required this.homeStrength,
    required this.awayStrength,
    required this.homeXg,
    required this.awayXg,
  });
}

class MatchSimulationCore {
  final Random random;

  MatchSimulationCore({Random? random}) : random = random ?? Random();

  MatchSimulationCoreResult simulate({
    required MatchSimulationTeamInput home,
    required MatchSimulationTeamInput away,
    int rivalryIntensity = 0,
  }) {
    var homeStrength = _strength(home, homeAdvantage: true);
    var awayStrength = _strength(away, homeAdvantage: false);

    if (rivalryIntensity >= 60) {
      final chaos = rivalryIntensity * .06;
      homeStrength += (random.nextDouble() - .5) * chaos;
      awayStrength += (random.nextDouble() - .5) * chaos;
    }

    final homeXg = _expectedGoals(homeStrength, awayStrength, true);
    final awayXg = _expectedGoals(homeStrength, awayStrength, false);

    return MatchSimulationCoreResult(
      homeGoals: _poissonLikeGoals(homeXg),
      awayGoals: _poissonLikeGoals(awayXg),
      homeStrength: homeStrength,
      awayStrength: awayStrength,
      homeXg: homeXg,
      awayXg: awayXg,
    );
  }

  double _strength(MatchSimulationTeamInput team, {required bool homeAdvantage}) {
    var strength = team.playerAverage * .64 +
        team.clubOverall * .20 +
        team.formAverage * .08 +
        team.fitnessAverage * .04 +
        team.moraleAverage * .02;
    strength += team.financialHealth * .012;
    strength += team.reputation * .008;
    if (homeAdvantage) strength += 2.5;
    return strength;
  }

  double _expectedGoals(double home, double away, bool isHome) {
    final diff = isHome ? home - away : away - home;
    final base = isHome ? 1.42 : 1.15;
    return (base + diff * .028).clamp(.20, 4.0);
  }

  int _poissonLikeGoals(double lambda) {
    final chance = random.nextDouble();
    var cumulative = exp(-lambda);
    if (chance <= cumulative) return 0;
    var probability = cumulative;
    for (var k = 1; k <= 8; k++) {
      probability *= lambda / k;
      cumulative += probability;
      if (chance <= cumulative) return k;
    }
    return 8;
  }
}
