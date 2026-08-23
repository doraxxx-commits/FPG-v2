import 'dart:async';
import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../models/player.dart';
import '../models/match_2d.dart';
import '../simulation/match_2d_engine.dart';
import '../simulation/mini_game_engine.dart';

class MatchScreen extends StatefulWidget {
  final GameEngine engine;
  const MatchScreen({super.key, required this.engine});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late final Match2DEngine _match;
  late final MiniGameEngine _miniGames;
  Timer? _timer;
  Match2DState? _state;
  Match2DEvent? _lastEvent;
  MiniGameDefinition? _pendingMiniGame;
  bool _started = false;
  bool _finishedDay = false;

  @override
  void initState() {
    super.initState();
    _match = Match2DEngine();
    _miniGames = MiniGameEngine();
    _start();
  }

  void _start() {
    final player = widget.engine.careerPlayer;
    final clubId = player?.clubId;
    final worldPlayer = clubId == null ? null : widget.engine.players.where((p) => p.id == player!.id).firstOrNull;
    final homeClubId = clubId ?? widget.engine.clubs.first.id;
    final awayClub = widget.engine.clubs.firstWhere((c) => c.id != homeClubId);
    final homePlayers = widget.engine.players.where((p) => p.clubId == homeClubId).toList();
    final awayPlayers = widget.engine.players.where((p) => p.clubId == awayClub.id).toList();

    // Jeśli dane startowe są skromne, dokładamy najlepszych zawodników świata
    // tylko jako wizualny fallback. Docelowo terminarz wskaże konkretnego rywala.
    final home = worldPlayer == null ? homePlayers : homePlayers;
    final state = _match.create(
      home: home.isNotEmpty ? home : widget.engine.players,
      away: awayPlayers.isNotEmpty ? awayPlayers : widget.engine.players,
    );
    _state = state;
    _started = true;
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _state == null) return;
    final step = _match.tick();
    setState(() => _lastEvent = step.event);
    if (step.event?.isKeyMoment == true) {
      _tryOpenMiniGame(step.event!);
    }
    if (_state!.finished) {
      _timer?.cancel();
      _finishDayLater();
    }
  }

  void _tryOpenMiniGame(Match2DEvent event) {
    final career = widget.engine.careerPlayer;
    if (career == null || event.playerId != career.id) return;
    final games = _miniGames.forPosition(career.position);
    if (games.isEmpty) return;
    final game = games[event.minute % games.length];
    if (_pendingMiniGame != null) return;
    setState(() => _pendingMiniGame = game);
    _showMiniGame(game);
  }

  Future<void> _showMiniGame(MiniGameDefinition game) async {
    final career = widget.engine.careerPlayer;
    if (career == null || !mounted) return;
    final quality = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MiniGameDialog(game: game),
    );
    if (!mounted) return;
    final result = _miniGames.resolve(game, _worldPlayer(career), quality ?? 50);
    setState(() => _pendingMiniGame = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.message} Wynik mini-gry: ${result.executionScore.round()}/100.')),
    );
  }

  Player _worldPlayer(dynamic career) {
    return widget.engine.players.firstWhere(
      (p) => p.id == career.id,
      orElse: () => Player(
        id: career.id, name: career.fullName, age: career.age, position: career.position,
        nationality: career.nationality, overall: career.overall, potential: career.potential,
        pace: career.pace, shooting: career.shooting, passing: career.passing,
        dribbling: career.dribbling, defending: career.defending, physical: career.physical,
        value: 0, weeklyWage: 0,
      ),
    );
  }

  void _finishDayLater() {
    if (_finishedDay) return;
    _finishedDay = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      try { widget.engine.nextDay(); } catch (_) {}
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: const Color(0xFF07110A),
      appBar: AppBar(title: const Text('MECZ 2D — WIDOK Z GÓRY'), backgroundColor: const Color(0xFF07110A)),
      body: SafeArea(
        child: Column(
          children: [
            _scoreBar(s),
            Expanded(child: s == null ? const Center(child: CircularProgressIndicator()) : _Pitch(state: s)),
            _eventPanel(),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text('AI steruje wszystkimi 22 zawodnikami. Kluczowe momenty uruchamiają mini-grę zależną od pozycji.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(Match2DState? s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('GOSPODARZE', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('${s?.homeGoals ?? 0}  :  ${s?.awayGoals ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      Text('${s?.minute ?? 0}\'', style: const TextStyle(color: Colors.white70)),
    ]),
  );

  Widget _eventPanel() => Container(
    width: double.infinity,
    margin: const EdgeInsets.all(10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF111A14), borderRadius: BorderRadius.circular(12)),
    child: Text(_lastEvent == null ? (_started ? 'Trwa budowanie akcji...' : 'Przygotowanie meczu...') : '${_lastEvent!.minute}\'  ${_lastEvent!.description}', style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

class _Pitch extends StatelessWidget {
  final Match2DState state;
  const _Pitch({required this.state});
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.45,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFF1C6B3A), border: Border.all(color: Colors.white70, width: 2)),
      child: CustomPaint(painter: _PitchPainter(state)),
    ),
  );
}

class _PitchPainter extends CustomPainter {
  final Match2DState state;
  _PitchPainter(this.state);
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final fillHome = Paint()..color = Colors.blueAccent;
    final fillAway = Paint()..color = Colors.orangeAccent;
    canvas.drawRect(Offset.zero & size, line);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * .12, line);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .25, size.width * .13, size.height * .5), line);
    canvas.drawRect(Rect.fromLTWH(size.width * .87, size.height * .25, size.width * .13, size.height * .5), line);
    canvas.drawCircle(Offset(state.ballX / 100 * size.width, state.ballY / 100 * size.height), 5, Paint()..color = Colors.white);
    for (final p in state.players) {
      final paint = p.team == Match2DTeam.home ? fillHome : fillAway;
      final pos = Offset(p.x / 100 * size.width, p.y / 100 * size.height);
      canvas.drawCircle(pos, p.hasBall ? 8 : 6, paint);
      if (p.hasBall) canvas.drawCircle(pos, 10, line);
    }
  }
  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => true;
}

class _MiniGameDialog extends StatefulWidget {
  final MiniGameDefinition game;
  const _MiniGameDialog({required this.game});
  @override
  State<_MiniGameDialog> createState() => _MiniGameDialogState();
}

class _MiniGameDialogState extends State<_MiniGameDialog> {
  double quality = 50;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.game.title),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.game.instruction),
      const SizedBox(height: 18),
      Slider(value: quality, min: 0, max: 100, divisions: 20, label: quality.round().toString(), onChanged: (v) => setState(() => quality = v)),
      const Text('Wynik mini-gry wpływa na jakość wykonania, ale NIE gwarantuje skutecznej akcji.'),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(context, quality), child: const Text('WYKONAJ'))],
  );
}
