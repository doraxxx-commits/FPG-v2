import '../models/club.dart';
import '../models/player.dart';
import '../models/player_career.dart';

/// Most pomiędzy karierą użytkownika a tym samym światem, w którym działają
/// zawodnicy AI. Dzięki temu zawodnik gracza nie jest osobnym "wyjątkiem".
class CareerWorldBridge {
  Player? _projection;
  String? _lastClubId;

  Player? get projection => _projection;

  void attach({required PlayerCareer career, required List<Player> worldPlayers, required List<Club> clubs}) {
    final existing = worldPlayers.where((p) => p.id == career.id).firstOrNull;
    if (existing != null) {
      _projection = existing;
    } else {
      _projection = _toWorldPlayer(career);
      worldPlayers.add(_projection!);
    }
    _lastClubId = _projection!.clubId;
    _syncRoster(worldPlayers: worldPlayers, clubs: clubs);
  }

  void pushCareerState(PlayerCareer career) {
    final p = _projection;
    if (p == null) return;
    p.name = career.fullName;
    p.age = career.age;
    p.nationality = career.nationality;
    p.overall = career.overall;
    p.potential = career.potential;
    p.pace = career.pace;
    p.shooting = career.shooting;
    p.passing = career.passing;
    p.dribbling = career.dribbling;
    p.defending = career.defending;
    p.physical = career.physical;
    p.clubId = career.clubId;
    p.agentId = career.agentId;
    p.agentInfluence = career.agentInfluence;
    p.transferRequest = career.transferRequest;
    p.happiness = career.happiness;
    p.morale = career.morale;
    p.managerRelationship = career.managerRelationship;
    p.fatigue = career.fatigue;
    p.fitness = career.fitness;
    p.form = career.form;
    p.contractYearsRemaining = career.contractYearsRemaining;
    p.releaseClause = career.releaseClause;
    p.wageExpectation = career.wageExpectation;
    p.appearanceBonus = career.appearanceBonus;
    p.goalBonus = career.goalBonus;
    p.assistBonus = career.assistBonus;
    p.trophyBonus = career.trophyBonus;
  }

  void pullWorldState(PlayerCareer career, {required List<Player> worldPlayers, required List<Club> clubs}) {
    final p = worldPlayers.where((x) => x.id == career.id).firstOrNull ?? _projection;
    if (p == null) return;
    career.clubId = p.clubId;
    career.agentId = p.agentId;
    career.agentInfluence = p.agentInfluence;
    career.transferRequest = p.transferRequest;
    career.happiness = p.happiness;
    career.morale = p.morale;
    career.managerRelationship = p.managerRelationship;
    career.fatigue = p.fatigue;
    career.fitness = p.fitness;
    career.form = p.form;
    career.internationalCaps = p.internationalCaps;
    career.internationalGoals = p.internationalGoals;
    career.internationalAssists = p.internationalAssists;
    career.nationalCallUps = p.nationalCallUps;
    career.lastNationalCallUpYear = p.lastNationalCallUpYear;
    career.wageExpectation = p.wageExpectation;
    career.appearanceBonus = p.appearanceBonus;
    career.goalBonus = p.goalBonus;
    career.assistBonus = p.assistBonus;
    career.trophyBonus = p.trophyBonus;
    career.releaseClause = p.releaseClause;
    career.contractYearsRemaining = p.contractYearsRemaining;
    _syncRoster(worldPlayers: worldPlayers, clubs: clubs);
  }

  void _syncRoster({required List<Player> worldPlayers, required List<Club> clubs}) {
    final p = _projection;
    if (p == null) return;
    if (_lastClubId != null && _lastClubId != p.clubId) {
      clubs.where((c) => c.id == _lastClubId).forEach((c) => c.removePlayer(p.id));
    }
    for (final club in clubs) {
      club.removePlayer(p.id);
    }
    if (p.clubId != null) {
      clubs.where((c) => c.id == p.clubId).forEach((c) => c.addPlayer(p.id));
    }
    _lastClubId = p.clubId;
  }

  Player _toWorldPlayer(PlayerCareer c) => Player(
    id: c.id,
    name: c.fullName,
    age: c.age,
    position: c.position,
    nationality: c.nationality,
    overall: c.overall,
    potential: c.potential,
    pace: c.pace,
    shooting: c.shooting,
    passing: c.passing,
    dribbling: c.dribbling,
    defending: c.defending,
    physical: c.physical,
    value: 0,
    weeklyWage: 0,
    clubId: c.clubId,
    agentId: c.agentId,
    agentInfluence: c.agentInfluence,
    transferRequest: c.transferRequest,
    happiness: c.happiness,
    internationalCaps: c.internationalCaps,
    internationalGoals: c.internationalGoals,
    internationalAssists: c.internationalAssists,
    nationalCallUps: c.nationalCallUps,
    lastNationalCallUpYear: c.lastNationalCallUpYear,
    wageExpectation: c.wageExpectation,
    appearanceBonus: c.appearanceBonus,
    goalBonus: c.goalBonus,
    assistBonus: c.assistBonus,
    trophyBonus: c.trophyBonus,
    releaseClause: c.releaseClause,
    contractYearsRemaining: c.contractYearsRemaining,
    fatigue: c.fatigue,
    fitness: c.fitness,
    form: c.form,
    morale: c.morale,
    managerRelationship: c.managerRelationship,
  );
}
