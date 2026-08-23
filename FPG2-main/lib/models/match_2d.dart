import 'dart:math';
import 'player.dart';

enum Match2DTeam { home, away }
enum Match2DEventType { pass, dribble, shot, tackle, save, cross, clearance, interception, goal, card, injury, substitution }

class Match2DPlayer {
  final String id;
  final String name;
  final PlayerPosition position;
  final Match2DTeam team;
  double x;
  double y;
  bool hasBall;
  bool controlledByAI;
  int stamina;

  Match2DPlayer({
    required this.id,
    required this.name,
    required this.position,
    required this.team,
    required this.x,
    required this.y,
    this.hasBall = false,
    this.controlledByAI = true,
    this.stamina = 100,
  });
}

class Match2DEvent {
  final Match2DEventType type;
  final String playerId;
  final String? secondaryPlayerId;
  final String description;
  final int minute;
  final double x;
  final double y;
  final bool isKeyMoment;

  const Match2DEvent({
    required this.type,
    required this.playerId,
    this.secondaryPlayerId,
    required this.description,
    required this.minute,
    required this.x,
    required this.y,
    this.isKeyMoment = false,
  });
}

class Match2DState {
  final List<Match2DPlayer> players;
  final List<Match2DEvent> events;
  double ballX;
  double ballY;
  String? ballOwnerId;
  int minute;
  int homeGoals;
  int awayGoals;
  bool finished;

  Match2DState({
    required this.players,
    this.events = const [],
    this.ballX = 50,
    this.ballY = 50,
    this.ballOwnerId,
    this.minute = 0,
    this.homeGoals = 0,
    this.awayGoals = 0,
    this.finished = false,
  });
}

Match2DPlayer make2DPlayer(Player p, Match2DTeam team, int index) {
  final home = team == Match2DTeam.home;
  final normalized = _startingPosition(p.position, index, home);
  return Match2DPlayer(
    id: p.id,
    name: p.name,
    position: p.position,
    team: team,
    x: normalized.$1,
    y: normalized.$2,
  );
}

(double, double) _startingPosition(PlayerPosition position, int index, bool home) {
  final side = home ? 1.0 : -1.0;
  switch (position) {
    case PlayerPosition.goalkeeper:
      return (home ? 8 : 92, 50);
    case PlayerPosition.defender:
      return (home ? 27 : 73, 20 + (index % 4) * 20);
    case PlayerPosition.midfielder:
      return (home ? 45 : 55, 18 + (index % 5) * 16);
    case PlayerPosition.winger:
      return (home ? 58 : 42, index.isEven ? 16 : 84);
    case PlayerPosition.striker:
      return (home ? 68 : 32, 50);
  }
}
