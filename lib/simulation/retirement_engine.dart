import 'dart:math';

import '../models/club.dart';
import '../models/player.dart';

/// Kontroluje emerytury i regenerację świata. Maksymalny wiek zawodnika AI
/// to 50 lat.
class RetirementEngine {
  final Random _random;
  RetirementEngine({Random? random}) : _random = random ?? Random();

  List<Player> processSeason({required List<Player> players, required List<Club> clubs}) {
    final retired = <Player>[];
    for (final player in players) {
      if (player.age < 30) continue;
      var chance = 0.0;
      if (player.age >= 50) {
        chance = 1.0;
      } else if (player.age >= 45) {
        chance = 0.45;
      } else if (player.age >= 40) {
        chance = 0.22;
      } else if (player.age >= 36) {
        chance = player.overall >= 82 ? 0.05 : 0.12;
      } else if (player.age >= 32) {
        chance = player.overall < 60 ? 0.08 : 0.015;
      }
      if (_random.nextDouble() < chance) retired.add(player);
    }

    for (final player in retired) {
      players.remove(player);
      final regen = _generateReplacement(player);
      players.add(regen);
    }
    return retired;
  }

  Player _generateReplacement(Player retired) {
    final seed = 50 + _random.nextInt(21);
    final id = 'regen_${retired.id}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(99999)}';
    final potential = min(95, seed + 14 + _random.nextInt(16));
    return Player(
      id: id,
      name: '${_firstNames[_random.nextInt(_firstNames.length)]} ${_lastNames[_random.nextInt(_lastNames.length)]}',
      age: 17 + _random.nextInt(3),
      position: retired.position,
      overall: seed,
      potential: potential,
      pace: _stat(seed),
      shooting: _stat(seed),
      passing: _stat(seed),
      dribbling: _stat(seed),
      defending: _stat(seed),
      physical: _stat(seed),
      value: seed * seed * 1200.0,
      weeklyWage: max(150, seed * 120.0),
      clubId: retired.clubId,
    );
  }

  int _stat(int seed) => (seed - 5 + _random.nextInt(11)).clamp(1, 99);

  static const _firstNames = ['Mateo', 'Kacper', 'Szymon', 'Nico', 'Lucas', 'Julian', 'Marco', 'Leo', 'Jakub', 'Filip', 'Jan', 'Gabriel'];
  static const _lastNames = ['Nowak', 'Rossi', 'Silva', 'Müller', 'Kowalski', 'Garcia', 'Weber', 'Wiśniewski', 'Zieliński', 'Dubois', 'Martins'];
}
