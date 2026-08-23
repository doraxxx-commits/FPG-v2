import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../models/player.dart';
import '../models/club.dart';

/// Offline snapshot całego podstawowego świata. Nie korzysta z sieci ani bazy zewnętrznej.
class WorldSave {
  static const int schemaVersion = 2;
  static const String fileName = 'fpg_world_save.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<bool> save(GameEngine engine) async {
    try {
      final file = await _file();
      final payload = {
        'schemaVersion': schemaVersion,
        'savedAt': DateTime.now().toIso8601String(),
        'gameState': engine.state.toJson(),
        'players': engine.players.map((p) => p.toJson()).toList(),
        'clubs': engine.clubs.map((c) => c.toJson()).toList(),
        'careerPlayer': engine.careerPlayer == null ? null : _careerJson(engine.careerPlayer!),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final version = map['schemaVersion'] ?? 1;
      if (version > schemaVersion) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exists() async {
    final file = await _file();
    return file.exists();
  }

  static Map<String, dynamic> _careerJson(dynamic p) => {
    'id': p.id, 'firstName': p.firstName, 'lastName': p.lastName, 'nationality': p.nationality,
    'age': p.age, 'height': p.height, 'position': p.position.name, 'overall': p.overall,
    'potential': p.potential, 'pace': p.pace, 'shooting': p.shooting, 'passing': p.passing,
    'dribbling': p.dribbling, 'defending': p.defending, 'physical': p.physical, 'clubId': p.clubId,
    'shirtNumber': p.shirtNumber, 'fatigue': p.fatigue, 'fitness': p.fitness, 'form': p.form,
    'morale': p.morale, 'happiness': p.happiness, 'managerRelationship': p.managerRelationship,
    'teamRelationship': p.teamRelationship, 'agentId': p.agentId, 'agentInfluence': p.agentInfluence,
    'transferRequest': p.transferRequest, 'internationalCaps': p.internationalCaps,
    'internationalGoals': p.internationalGoals, 'internationalAssists': p.internationalAssists,
    'nationalCallUps': p.nationalCallUps, 'lastNationalCallUpYear': p.lastNationalCallUpYear,
    'wageExpectation': p.wageExpectation, 'appearanceBonus': p.appearanceBonus, 'goalBonus': p.goalBonus,
    'assistBonus': p.assistBonus, 'trophyBonus': p.trophyBonus, 'releaseClause': p.releaseClause,
    'contractYearsRemaining': p.contractYearsRemaining, 'inMatchSquad': p.inMatchSquad,
    'isStarter': p.isStarter, 'isRegularStarter': p.isRegularStarter, 'squadStatus': p.squadStatus,
    'careerAppearances': p.careerAppearances, 'careerGoals': p.careerGoals, 'careerAssists': p.careerAssists,
  };
}
