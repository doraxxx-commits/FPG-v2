import 'dart:math';

import '../models/club.dart';
import '../models/player.dart';

/// Autonomiczny rynek transferowy.
///
/// Transfer nie jest losowym "przenieś zawodnika A do B". Klub najpierw musi
/// mieć potrzebę, budżet, dopasowanie zawodnika i zgodę sprzedającego.
class TransferEngine {
  final Random _random;
  TransferEngine({Random? random}) : _random = random ?? Random();

  List<String> processWindow({
    required List<Club> clubs,
    required List<Player> players,
    required bool summer,
    required bool winter,
  }) {
    final logs = <String>[];
    _processLoanReturns(players, logs);
    if (!summer && !winter) return logs;
    final attempts = summer ? max(1, clubs.length ~/ 8) : max(1, clubs.length ~/ 16);

    final buyers = [...clubs]..sort((a, b) => b.transferActivity.compareTo(a.transferActivity));
    for (final buyer in buyers.take(attempts)) {
      if (_random.nextDouble() > (summer ? .34 : .18)) continue;
      final need = _findNeed(buyer, players);
      if (need == null) continue;

      final candidates = players.where((p) {
        if (p.clubId == null || p.clubId == buyer.id || p.injured) return false;
        if (p.position != need) return false;
        if (p.overall < buyer.minimumSigningOverall - 8) return false;
        if (p.age < buyer.preferredMinAge - 2 || p.age > buyer.preferredMaxAge + 3) return false;
        return true;
      }).toList();
      if (candidates.isEmpty) continue;

      candidates.sort((a, b) => _score(buyer, b).compareTo(_score(buyer, a)));
      final target = candidates.first;
      final seller = clubs.where((c) => c.id == target.clubId).firstOrNull;
      if (seller == null) continue;
      if (_random.nextDouble() > _acceptanceProbability(seller, target, buyer)) continue;

      // Wypożyczenie jest częstsze dla młodych zawodników, rezerwowych i
      // klubów o ograniczonym budżecie. To daje światu naturalny obieg kadr.
      final canLoan = target.age <= 24 &&
          (target.squadStatus == 'reserves' || target.squadStatus == 'outOfSquad');
      if (canLoan && _random.nextDouble() < (winter ? .38 : .25)) {
        final loanDays = winter ? 150 : 330;
        target.loanFromClubId = seller.id;
        target.loanUntilDay = loanDays;
        target.clubId = buyer.id;
        target.morale = min(100, target.morale + 4);
        target.managerRelationship = 55;
        logs.add('WYPOŻYCZENIE: ${target.name} → ${buyer.name}');
        continue;
      }

      final fee = _fee(target, buyer, seller, winter: winter);
      if (buyer.budget < fee) continue;
      if (_wouldDestroySeller(seller, target, players)) continue;

      buyer.budget -= fee;
      seller.budget += fee;
      target.clubId = buyer.id;
      target.loanFromClubId = null;
      target.loanUntilDay = 0;
      target.contractYearsRemaining = max(1, 2 + _random.nextInt(4));
      target.releaseClause = target.value * (2.0 + buyer.reputation / 100.0);
      target.morale = min(100, target.morale + 6);
      target.managerRelationship = 55;
      logs.add('TRANSFER: ${target.name} → ${buyer.name} (€${fee.toStringAsFixed(0)})');
    }
    return logs;
  }

  void _processLoanReturns(List<Player> players, List<String> logs) {
    for (final player in players) {
      if (player.loanFromClubId == null || player.loanUntilDay <= 0) continue;
      // TransferEngine dostaje kolejne wywołania przez dni; po okresie
      // wypożyczenia zawodnik wraca do macierzystego klubu.
      player.loanUntilDay--;
      if (player.loanUntilDay <= 0) {
        final parent = player.loanFromClubId;
        player.clubId = parent;
        player.loanFromClubId = null;
        player.loanUntilDay = 0;
        logs.add('POWRÓT Z WYPOŻYCZENIA: ${player.name}');
      }
    }
  }

  PlayerPosition? _findNeed(Club club, List<Player> players) {
    final squad = players.where((p) => p.clubId == club.id).toList();
    final minimum = <PlayerPosition, int>{
      PlayerPosition.goalkeeper: 2,
      PlayerPosition.defender: 5,
      PlayerPosition.midfielder: 5,
      PlayerPosition.winger: 3,
      PlayerPosition.striker: 2,
    };
    final deficits = <PlayerPosition, double>{};
    for (final pos in PlayerPosition.values) {
      final list = squad.where((p) => p.position == pos).toList();
      final countPenalty = max(0, minimum[pos]! - list.length) * 20.0;
      final avg = list.isEmpty ? 0 : list.fold<double>(0, (s, p) => s + p.overall) / list.length;
      deficits[pos] = countPenalty + max(0, club.overall - avg);
    }
    return deficits.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _score(Club buyer, Player p) {
    final potential = max(0, p.potential - p.overall) * (buyer.youthFocus / 100);
    final age = (p.age - ((buyer.preferredMinAge + buyer.preferredMaxAge) / 2)).abs();
    return p.overall * 2.4 + potential - age * 2 + p.form * .15 + p.morale * .05;
  }

  double _acceptanceProbability(Club seller, Player p, Club buyer) {
    var chance = .55;
    if (p.squadStatus == 'outOfSquad') chance += .25;
    if (p.squadStatus == 'reserves') chance += .12;
    if (p.age >= 30) chance += .10;
    if (seller.financialHealth < 35) chance += .18;
    if (buyer.reputation > seller.reputation) chance += .05;
    return chance.clamp(.08, .95);
  }

  int _fee(Player p, Club buyer, Club seller, {required bool winter}) {
    var multiplier = 1.0 + (buyer.reputation - seller.reputation) / 500.0;
    if (p.age <= 23) multiplier += .15;
    if (p.potential - p.overall >= 12) multiplier += .20;
    if (winter) multiplier += .08;
    return max(150000, (p.value * multiplier).round());
  }

  bool _wouldDestroySeller(Club seller, Player target, List<Player> players) {
    final count = players.where((p) => p.clubId == seller.id).length;
    return count <= 19 || (target.squadStatus == 'startingXI' && count <= 22);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
