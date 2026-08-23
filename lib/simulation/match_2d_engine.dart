import 'dart:math';
import '../models/player.dart';
import '../models/match_2d.dart';

class Match2DStep {
  final Match2DEvent? event;
  final bool keyMoment;
  const Match2DStep({this.event, this.keyMoment = false});
}

/// Prosta, prowizoryczna symulacja rzutu z góry.
/// 22 zawodników i piłka są sterowane przez AI. To warstwa wizualna nad
/// MatchSimulationCore, a nie drugi silnik wyniku meczu.
class Match2DEngine {
  final Random random;
  final List<Match2DEvent> _events = [];
  Match2DState? state;

  Match2DEngine({Random? random}) : random = random ?? Random();

  Match2DState create({required List<Player> home, required List<Player> away}) {
    final homeXI = _pickXI(home);
    final awayXI = _pickXI(away);
    final players = <Match2DPlayer>[];
    for (var i = 0; i < homeXI.length; i++) players.add(make2DPlayer(homeXI[i], Match2DTeam.home, i));
    for (var i = 0; i < awayXI.length; i++) players.add(make2DPlayer(awayXI[i], Match2DTeam.away, i));
    final owner = players.firstWhere((p) => p.position == PlayerPosition.midfielder && p.team == Match2DTeam.home, orElse: () => players.first);
    owner.hasBall = true;
    state = Match2DState(players: players, ballX: owner.x, ballY: owner.y, ballOwnerId: owner.id);
    _events.clear();
    return state!;
  }

  Match2DStep tick() {
    final s = state;
    if (s == null || s.finished) return const Match2DStep();
    s.minute++;
    _movePlayers(s);
    final event = _maybeAction(s);
    if (s.minute >= 90) s.finished = true;
    return Match2DStep(event: event, keyMoment: event?.isKeyMoment ?? false);
  }

  List<Match2DEvent> get events => List.unmodifiable(_events);

  List<Player> _pickXI(List<Player> source) {
    final sorted = [...source]..sort((a, b) => b.overall.compareTo(a.overall));
    final result = <Player>[];
    void add(PlayerPosition p, int count) {
      for (final player in sorted.where((x) => x.position == p)) {
        if (result.length >= 11 || count == 0) break;
        result.add(player); count--;
      }
    }
    add(PlayerPosition.goalkeeper, 1);
    add(PlayerPosition.defender, 4);
    add(PlayerPosition.midfielder, 3);
    add(PlayerPosition.winger, 2);
    add(PlayerPosition.striker, 1);
    for (final p in sorted) {
      if (result.length >= 11) break;
      if (!result.contains(p)) result.add(p);
    }
    return result.take(11).toList();
  }

  void _movePlayers(Match2DState s) {
    final owner = s.players.firstWhere((p) => p.id == s.ballOwnerId, orElse: () => s.players.first);
    final targetX = owner.team == Match2DTeam.home ? min(94, owner.x + 2.5) : max(6, owner.x - 2.5);
    s.ballX += (targetX - s.ballX) * .18;
    s.ballY += (owner.y - s.ballY) * .18;
    for (final p in s.players) {
      final attraction = p.id == owner.id ? .30 : .06;
      final dx = s.ballX - p.x;
      final dy = s.ballY - p.y;
      p.x += dx * attraction + (random.nextDouble() - .5) * .7;
      p.y += dy * attraction + (random.nextDouble() - .5) * .7;
      p.x = p.x.clamp(3, 97);
      p.y = p.y.clamp(3, 97);
      p.stamina = max(0, p.stamina - (random.nextDouble() < .08 ? 1 : 0));
    }
  }

  Match2DEvent? _maybeAction(Match2DState s) {
    if (random.nextDouble() > .25) return null;
    final owner = s.players.firstWhere((p) => p.id == s.ballOwnerId, orElse: () => s.players.first);
    final nearbyOpponent = s.players.where((p) => p.team != owner.team).reduce((a, b) => _distance(a, s) < _distance(b, s) ? a : b);
    final distanceToGoal = owner.team == Match2DTeam.home ? 100 - owner.x : owner.x;
    final roll = random.nextDouble();
    Match2DEventType type;
    String text;
    if (distanceToGoal < 25 && roll < .34) {
      type = Match2DEventType.shot;
      text = '${owner.name} oddaje strzał';
    } else if (_distance(nearbyOpponent, s) < 14 && roll < .62) {
      type = owner.position == PlayerPosition.defender ? Match2DEventType.tackle : Match2DEventType.dribble;
      text = type == Match2DEventType.tackle ? '${nearbyOpponent.name} próbuje odbioru' : '${owner.name} podejmuje próbę dryblingu';
    } else {
      type = roll < .15 ? Match2DEventType.cross : Match2DEventType.pass;
      text = type == Match2DEventType.cross ? '${owner.name} zagrywa dośrodkowanie' : '${owner.name} zagrywa piłkę';
    }
    final key = (type == Match2DEventType.shot || random.nextDouble() < .20);
    if (type == Match2DEventType.shot && random.nextDouble() < .16) {
      final goal = owner.team == Match2DTeam.home;
      if (goal) s.homeGoals++; else s.awayGoals++;
      type = Match2DEventType.goal;
      text = 'GOOOL! ${owner.name} trafia do siatki';
    } else if (type == Match2DEventType.pass || type == Match2DEventType.dribble || type == Match2DEventType.cross) {
      _transferBall(s, owner);
    } else if (type == Match2DEventType.tackle) {
      _transferBall(s, owner);
    }
    final e = Match2DEvent(type: type, playerId: owner.id, secondaryPlayerId: nearbyOpponent.id, description: text, minute: s.minute, x: s.ballX, y: s.ballY, isKeyMoment: key);
    _events.add(e);
    return e;
  }

  void _transferBall(Match2DState s, Match2DPlayer owner) {
    final candidates = s.players.where((p) => p.team == owner.team && p.id != owner.id).toList();
    if (candidates.isEmpty) return;
    final target = candidates[random.nextInt(candidates.length)];
    owner.hasBall = false;
    target.hasBall = true;
    s.ballOwnerId = target.id;
    s.ballX = target.x;
    s.ballY = target.y;
  }

  double _distance(Match2DPlayer p, Match2DState s) => sqrt(pow(p.x - s.ballX, 2) + pow(p.y - s.ballY, 2));
}
