import 'dart:math';
import '../models/club.dart';
import '../models/player.dart';
import '../models/transfer_interest.dart';

/// Buduje pamięć zainteresowania klubów zawodnikami. Zainteresowanie może
/// rosnąć przez formę, potencjał, brak minut i profil strategiczny klubu.
class TransferInterestEngine {
  final Random _random;
  final Map<String, TransferInterest> interests = {};

  TransferInterestEngine({Random? random}) : _random = random ?? Random();

  void processDay({required List<Club> clubs, required List<Player> players, required int absoluteDay}) {
    final candidates = players.where((p) => p.clubId != null && !p.injured).toList();
    for (final buyer in clubs) {
      final pool = candidates.where((p) => p.clubId != buyer.id && _fits(buyer, p)).toList();
      pool.sort((a, b) => _score(buyer, b).compareTo(_score(buyer, a)));
      for (final player in pool.take(2)) {
        final score = _score(buyer, player);
        if (score < 62 || _random.nextDouble() > .035) continue;
        final id = '${buyer.id}::${player.id}';
        final interest = interests.putIfAbsent(id, () => TransferInterest(
          id: id, clubId: buyer.id, playerId: player.id, score: score.round(), lastContactDay: absoluteDay,
        ));
        interest.score = max(1, min(100, ((interest.score * .8) + score * .2).round()));
        interest.daysActive++;
        interest.lastContactDay = absoluteDay;
        if (interest.score >= 82) interest.stage = 'serious';
      }
    }
    interests.removeWhere((_, i) => absoluteDay - i.lastContactDay > 120);
  }

  bool _fits(Club c, Player p) => p.overall >= c.minimumSigningOverall - 10 &&
      p.age >= c.preferredMinAge - 3 && p.age <= c.preferredMaxAge + 4;

  double _score(Club c, Player p) {
    final age = ((c.preferredMinAge + c.preferredMaxAge) / 2 - p.age).abs();
    final potential = max(0, p.potential - p.overall) * c.youthFocus / 100;
    final minutes = p.consecutiveBenchDays >= 14 ? 8 : 0;
    final role = p.squadStatus == 'outOfSquad' ? 10 : p.squadStatus == 'reserves' ? 5 : 0;
    return p.overall * 1.45 + potential * 1.4 + p.form * .18 + minutes + role - age * 2;
  }
}
