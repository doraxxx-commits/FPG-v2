import 'dart:math';

import '../data/world_data.dart';

import '../models/club.dart';
import '../models/fixture.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/player_career.dart';
import '../models/player_contract.dart';

import '../simulation/fixture_generator.dart';
import '../simulation/league_engine.dart';
import '../simulation/match_engine.dart';
import '../simulation/world_engine.dart';
import '../simulation/career_world_bridge.dart';

import 'game_state.dart';
import 'training_engine.dart';
import '../database/world_save.dart';

class GameEngine {
  final GameState state;

  late final List<League> leagues;
  late final List<Club> clubs;
  late final List<Player> players;

  late final LeagueEngine leagueEngine;
  late final MatchEngine matchEngine;
  late final WorldEngine worldEngine;

  late final List<Fixture> fixtures;

  final TrainingEngine trainingEngine = TrainingEngine();
  final CareerWorldBridge careerWorldBridge = CareerWorldBridge();

  final Random _random = Random();

  PlayerCareer? careerPlayer;

  // career_home_screen.dart wywołuje `engine.gameState` (SaveManager),
  // a jedyne pole nazywało się `state` — alias, żeby nie trzeba było
  // przerabiać ekranu ani łamać reszty kodu, który używa `state`.
  GameState get gameState => state;

  // ==========================================================
  // KONSTRUKTOR
  // ==========================================================

  GameEngine({
    GameState? state,
  }) : state = state ?? GameState() {
    leagues = WorldData.leagues;
    clubs = WorldData.clubs;
    players = WorldData.players;

    final leagueClubs = clubs
        .where(
          (club) => club.leagueId == 'pol_ek',
        )
        .toList();

    leagueEngine = LeagueEngine(
      clubs: leagueClubs,
    );

    matchEngine = MatchEngine();

    worldEngine = WorldEngine(
      clubs: clubs,
      players: players,
      leagues: leagues,
    );

    fixtures = FixtureGenerator.generateSeasonFixtures(
      leagueClubs,
            seasonStartYear: state?.year ?? 2026,
    );
  }

  // ==========================================================
  // TWORZENIE ZAWODNIKA
  // ==========================================================

  void createPlayer({
    required String firstName,
    required String lastName,
    required String nationality,
    required int age,
    required int height,
    required PlayerPosition position,
    required int pace,
    required int shooting,
    required int passing,
    required int dribbling,
    required int defending,
    required int physical,
  }) {
    final player = PlayerCareer(
      id: 'career_player_001',
      firstName: firstName,
      lastName: lastName,
      nationality: nationality,
      age: age,
      height: height,
      position: position,
      overall: 1,
      potential: 85,
      pace: pace,
      shooting: shooting,
      passing: passing,
      dribbling: dribbling,
      defending: defending,
      physical: physical,
    );

    player.refreshOverall();

    careerPlayer = player;
    careerWorldBridge.attach(career: player, worldPlayers: players, clubs: clubs);
    careerWorldBridge.pushCareerState(player);
  }

  // ==========================================================
  // PEŁNY ZAPIS / ODCZYT OFFLINE
  // ==========================================================

  Future<bool> saveWorld() => WorldSave.save(this);

  Future<bool> loadWorld() async {
    final snapshot = await WorldSave.load();
    if (snapshot == null) return false;
    final rawState = snapshot['gameState'];
    if (rawState is Map) {
      final restored = GameState.fromJson(Map<String, dynamic>.from(rawState));
      state.year = restored.year;
      state.month = restored.month;
      state.day = restored.day;
      state.season = restored.season;
      state.transferWindowSummer = restored.transferWindowSummer;
      state.transferWindowWinter = restored.transferWindowWinter;
    }

    final rawPlayers = snapshot['players'];
    if (rawPlayers is List) {
      final byId = <String, Player>{};
      for (final p in rawPlayers) {
        if (p is Map) {
          final restored = Player.fromJson(Map<String, dynamic>.from(p));
          byId[restored.id] = restored;
        }
      }
      for (var i = 0; i < players.length; i++) {
        final restored = byId[players[i].id];
        if (restored == null) continue;
        final target = players[i];
        target.name = restored.name;
        target.age = restored.age;
        target.nationality = restored.nationality;
        target.overall = restored.overall;
        target.potential = restored.potential;
        target.pace = restored.pace;
        target.shooting = restored.shooting;
        target.passing = restored.passing;
        target.dribbling = restored.dribbling;
        target.defending = restored.defending;
        target.physical = restored.physical;
        target.value = restored.value;
        target.weeklyWage = restored.weeklyWage;
        target.clubId = restored.clubId;
        target.agentId = restored.agentId;
        target.agentInfluence = restored.agentInfluence;
        target.transferRequest = restored.transferRequest;
        target.happiness = restored.happiness;
        target.fatigue = restored.fatigue;
        target.fitness = restored.fitness;
        target.form = restored.form;
        target.morale = restored.morale;
        target.managerRelationship = restored.managerRelationship;
        target.squadStatus = restored.squadStatus;
        target.consecutiveBenchDays = restored.consecutiveBenchDays;
        target.consecutiveUnusedDays = restored.consecutiveUnusedDays;
        target.appearances = restored.appearances;
        target.starts = restored.starts;
        target.minutesPlayed = restored.minutesPlayed;
        target.goals = restored.goals;
        target.assists = restored.assists;
        target.injured = restored.injured;
        target.injuryDaysRemaining = restored.injuryDaysRemaining;
      }
    }

    final rawClubs = snapshot['clubs'];
    if (rawClubs is List) {
      final byId = <String, Club>{};
      for (final c in rawClubs) {
        if (c is Map) {
          final restored = Club.fromJson(Map<String, dynamic>.from(c));
          byId[restored.id] = restored;
        }
      }
      for (var i = 0; i < clubs.length; i++) {
        final restored = byId[clubs[i].id];
        if (restored == null) continue;
        final target = clubs[i];
        target.name = restored.name;
        target.overall = restored.overall;
        target.budget = restored.budget;
        target.reputation = restored.reputation;
        target.financialHealth = restored.financialHealth;
        target.academyQuality = restored.academyQuality;
        target.stability = restored.stability;
        target.managerId = restored.managerId;
        target.managerName = restored.managerName;
        target.managerReputation = restored.managerReputation;
        target.managerTenureDays = restored.managerTenureDays;
        target.boardConfidence = restored.boardConfidence;
        target.playerIds
          ..clear()
          ..addAll(restored.playerIds);
      }
    }

    final rawCareer = snapshot['careerPlayer'];
    if (rawCareer is Map) {
      careerPlayer = PlayerCareer.fromJson(Map<String, dynamic>.from(rawCareer));
      careerWorldBridge.attach(career: careerPlayer!, worldPlayers: players, clubs: clubs);
      careerWorldBridge.pushCareerState(careerPlayer!);
    }
    return true;
  }

  // ==========================================================
  // NASTĘPNY DZIEŃ / METODA COMPATIBILITY FOR UI
  // ==========================================================

  void nextDay() {
    advanceDay();
  }

  void advanceDay() {
    state.nextDay();

    recoverPlayer();

    updatePlayerForm();

    // Trener podejmuje decyzję o statusie zawodnika.
    updateCareerPlayerMatchStatus();

    playMatchesForToday();

    // Zawodnik gracza uczestniczy w tych samych systemach świata co AI.
    if (careerPlayer != null) {
      careerWorldBridge.attach(career: careerPlayer!, worldPlayers: players, clubs: clubs);
      careerWorldBridge.pushCareerState(careerPlayer!);
    }

    // Świat AI działa niezależnie od kariery gracza.
    worldEngine.processDay(
      year: state.year,
      month: state.month,
      day: state.day,
      summerTransferWindow: summerTransferWindow,
      winterTransferWindow: winterTransferWindow,
    );

    if (careerPlayer != null) {
      careerWorldBridge.pullWorldState(careerPlayer!, worldPlayers: players, clubs: clubs);
    }

    // Sprawdzenie zakończenia sezonu
    if (leagueEngine.isSeasonComplete()) {
      _advanceSeason();
    }
  }

  // ==========================================================
  // PRZEJŚCIE DO NOWEGO SEZONU
  // ==========================================================

  void _advanceSeason() {
    // Świat ma własny cykl rozwoju, starzenia, kontraktów, finansów
    // i emerytur. GameEngine tylko go uruchamia.
    worldEngine.processEndOfSeason(nextSeasonStartYear: state.year);

    // Starzenie gracza kariery
    if (careerPlayer != null) {
      careerPlayer!.age += 1;
    }

    // 3. Reset tabeli i wygenerowanie nowego terminarza
    final leagueClubs = clubs
        .where(
          (club) => club.leagueId == 'pol_ek',
        )
        .toList();

    fixtures = FixtureGenerator.generateSeasonFixtures(
      leagueClubs,
      seasonStartYear: state.year,
    );
    leagueEngine.resetSeason();
  }

  // ==========================================================
  // INFORMACJE O UDZIALE ZAWODNIKA W MECZU
  // ==========================================================

  bool get careerPlayerCanPlay {
    if (careerPlayer == null) {
      return false;
    }

    final player = careerPlayer!;

    // Bez klubu nie można grać.
    if (player.clubId == null) {
      return false;
    }

    // Aktualizacja decyzji trenera.
    player.updateMatchStatus();

    return player.canPlayMatch;
  }

  // ==========================================================
  // CZY ZAWODNIK JEST W KADRZE MECZOWEJ
  // ==========================================================

  bool get careerPlayerInMatchSquad {
    if (careerPlayer == null) {
      return false;
    }

    return careerPlayer!.inMatchSquad;
  }

  // ==========================================================
  // CZY ZAWODNIK JEST W PODSTAWOWYM SKŁADZIE
  // ==========================================================

  bool get careerPlayerIsStarter {
    if (careerPlayer == null) {
      return false;
    }

    return careerPlayer!.isRegularStarter;
  }

  // ==========================================================
  // STATUS MECZOWY ZAWODNIKA
  // ==========================================================

  String get careerPlayerMatchStatus {
    if (careerPlayer == null) {
      return 'Brak zawodnika';
    }

    return careerPlayer!.squadStatus;
  }

  // ==========================================================
  // WYSTĘP ZAWODNIKA W MECZU
  // ==========================================================

  void processCareerPlayerMatch({
    required Fixture fixture,
    required MatchResult result,
  }) {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    // Zawodnik bez klubu nie może wystąpić.
    if (player.clubId == null) {
      return;
    }

    // Sprawdzamy, czy jego klub gra w tym meczu.
    final playerClubIsHome =
        fixture.homeClubId == player.clubId;

    final playerClubIsAway =
        fixture.awayClubId == player.clubId;

    if (!playerClubIsHome && !playerClubIsAway) {
      return;
    }

    // Aktualizacja decyzji trenera.
    player.updateMatchStatus();

    // Jeżeli zawodnik nie może zagrać, nie występuje w meczu.
    if (!player.canPlayMatch) {
      return;
    }

    bool started = false;
    int minutes = 0;

    // ========================================================
    // PODSTAWOWY ZAWODNIK
    // ========================================================

    if (player.isStarter) {
      started = true;

      // Podstawowy zawodnik zazwyczaj gra cały mecz,
      // ale czasami zostaje zmieniony.
      final chanceOfFullMatch = _random.nextInt(100);

      if (chanceOfFullMatch < 75) {
        minutes = 90;
      } else {
        minutes = 60 + _random.nextInt(25);
      }
    }

    // ========================================================
    // REZERWOWY / ROTACJA
    // ========================================================

    else if (player.inMatchSquad) {
      // Szansa wejścia z ławki.
      final substitutionChance = _random.nextInt(100);

      if (substitutionChance < 60) {
        started = false;

        // Wejście zazwyczaj między 55. a 80. minutą.
        final substitutionMinute =
            55 + _random.nextInt(26);

        minutes = 90 - substitutionMinute;

        // Minimum 10 minut.
        if (minutes < 10) {
          minutes = 10;
        }
      } else {
        // Został na ławce.
        minutes = 0;
      }
    }

    // ========================================================
    // BRAK WYSTĘPU
    // ========================================================

    if (minutes <= 0) {
      return;
    }

    // ========================================================
    // OCENA MECZOWA
    // ========================================================

    final rating = _calculateCareerPlayerMatchRating(
      player: player,
      result: result,
      playerClubIsHome: playerClubIsHome,
      started: started,
    );

    // ========================================================
    // GOLE
    // ========================================================

    final goals = _calculateCareerPlayerGoals(
      player: player,
      result: result,
      playerClubIsHome: playerClubIsHome,
      minutes: minutes,
    );

    // ========================================================
    // ASYSTY
    // ========================================================

    final assists = _calculateCareerPlayerAssists(
      player: player,
      result: result,
      playerClubIsHome: playerClubIsHome,
      minutes: minutes,
    );

    // ========================================================
    // STATYSTYKI KARIERY
    // ========================================================

    player.addCareerAppearance(
      minutes: minutes,
      started: started,
      rating: rating,
    );

    // Dodajemy gole.
    for (int i = 0; i < goals; i++) {
      player.addCareerGoal();
    }

    // Dodajemy asysty.
    for (int i = 0; i < assists; i++) {
      player.addCareerAssist();
    }

    // ========================================================
    // ZMĘCZENIE PO MECZU
    // ========================================================

    final matchFatigue =
        started
            ? 25 + ((minutes - 60) ~/ 6)
            : 8 + (minutes ~/ 5);

    player.fatigue = (
      player.fatigue + matchFatigue
    ).clamp(0, 100);

    player.fitness = (
      player.fitness - matchFatigue
    ).clamp(0, 100);

    // ========================================================
    // FORMA
    // ========================================================

    if (rating >= 7.5) {
      player.form = (
        player.form + 3
      ).clamp(0, 100);
    } else if (rating >= 7.0) {
      player.form = (
        player.form + 2
      ).clamp(0, 100);
    } else if (rating < 5.5) {
      player.form = (
        player.form - 2
      ).clamp(0, 100);
    } else if (rating < 6.0) {
      player.form = (
        player.form - 1
      ).clamp(0, 100);
    }

    player.refreshOverall();
  }

  // ==========================================================
  // OCENA ZAWODNIKA
  // ==========================================================

  double _calculateCareerPlayerMatchRating({
    required PlayerCareer player,
    required MatchResult result,
    required bool playerClubIsHome,
    required bool started,
  }) {
    double rating = 6.0;

    final playerClubGoals =
        playerClubIsHome
            ? result.homeGoals
            : result.awayGoals;

    final opponentGoals =
        playerClubIsHome
            ? result.awayGoals
            : result.homeGoals;

    // Wynik meczu.
    if (playerClubGoals > opponentGoals) {
      rating += 0.7;
    } else if (playerClubGoals < opponentGoals) {
      rating -= 0.6;
    }

    // Podstawowy zawodnik dostaje większy wpływ wyniku.
    if (started) {
      rating += 0.2;
    } else {
      rating -= 0.1;
    }

    // Mały losowy element.
    rating += (
      _random.nextDouble() * 1.2
    ) - 0.6;

    return rating.clamp(4.0, 9.5);
  }

  // ==========================================================
  // GOLE ZAWODNIKA
  // ==========================================================

  int _calculateCareerPlayerGoals({
    required PlayerCareer player,
    required MatchResult result,
    required bool playerClubIsHome,
    required int minutes,
  }) {
    final teamGoals =
        playerClubIsHome
            ? result.homeGoals
            : result.awayGoals;

    if (teamGoals <= 0 || minutes < 10) {
      return 0;
    }

    // Im wyższe strzelanie zawodnika, tym większa szansa na gola.
    double chance =
        0.025 +
        (player.shooting * 0.0012);

    // Napastnicy i skrzydłowi mają większą szansę.
    switch (player.position) {
      case PlayerPosition.striker:
        chance += 0.025;
        break;

      case PlayerPosition.winger:
        chance += 0.015;
        break;

      case PlayerPosition.midfielder:
        chance += 0.005;
        break;

      case PlayerPosition.defender:
      case PlayerPosition.goalkeeper:
        chance -= 0.005;
        break;
    }

    final opportunities =
        max(1, teamGoals);

    int goals = 0;

    for (int i = 0; i < opportunities; i++) {
      if (_random.nextDouble() < chance) {
        goals++;
      }
    }

    return goals.clamp(0, 3);
  }

  // ==========================================================
  // ASYSTY ZAWODNIKA
  // ==========================================================

  int _calculateCareerPlayerAssists({
    required PlayerCareer player,
    required MatchResult result,
    required bool playerClubIsHome,
    required int minutes,
  }) {
    final teamGoals =
        playerClubIsHome
            ? result.homeGoals
            : result.awayGoals;

    if (teamGoals <= 0 || minutes < 10) {
      return 0;
    }

    double chance =
        0.015 +
        (player.passing * 0.0009);

    // Pomocnicy i skrzydłowi częściej asystują.
    switch (player.position) {
      case PlayerPosition.midfielder:
        chance += 0.025;
        break;

      case PlayerPosition.winger:
        chance += 0.020;
        break;

      case PlayerPosition.striker:
        chance += 0.010;
        break;

      case PlayerPosition.defender:
        chance += 0.005;
        break;

      case PlayerPosition.goalkeeper:
        chance -= 0.005;
        break;
    }

    int assists = 0;

    for (int i = 0; i < teamGoals; i++) {
      if (_random.nextDouble() < chance) {
        assists++;
      }
    }

    return assists.clamp(0, 3);
  }

  // ==========================================================
  // MECZE
  // ==========================================================

  void playMatchesForToday() {
    for (final fixture in fixtures) {
      if (fixture.played) {
        continue;
      }

      if (fixture.year == state.year &&
          fixture.month == state.month &&
          fixture.day == state.day) {
        playFixture(fixture);
      }
    }
  }

  MatchResult playFixture(
    Fixture fixture,
  ) {
    final home = clubs.firstWhere(
      (club) => club.id == fixture.homeClubId,
    );

    final away = clubs.firstWhere(
      (club) => club.id == fixture.awayClubId,
    );

    final result = matchEngine.simulate(
      home: home,
      away: away,
    );

    fixture.played = true;

    fixture.homeGoals = result.homeGoals;
    fixture.awayGoals = result.awayGoals;

    leagueEngine.recordMatch(
      homeClubId: result.homeClubId,
      awayClubId: result.awayClubId,
      homeGoals: result.homeGoals,
      awayGoals: result.awayGoals,
    );

    processCareerPlayerMatch(
      fixture: fixture,
      result: result,
    );

    return result;
  }

  // ==========================================================
  // TRENING
  // ==========================================================

  TrainingResult trainPlayer(
    TrainingType type,
  ) {
    if (careerPlayer == null) {
      throw StateError(
        'Brak aktywnego zawodnika.',
      );
    }

    final player = careerPlayer!;

    if (player.fatigue >= 90) {
      throw StateError(
        'Zawodnik jest zbyt zmęczony na kolejny trening.',
      );
    }

    final result = trainingEngine.train(
      player,
      type,
    );

    player.fatigue = (
      player.fatigue + result.fatigue
    ).clamp(0, 100);

    player.fitness = (
      player.fitness - result.fatigue
    ).clamp(0, 100);

    player.refreshOverall();

    // Dobry trening wpływa na zaufanie trenera.
    player.rewardTrainingTrust();

    return result;
  }

  // ==========================================================
  // REGENERACJA
  // ==========================================================

  void recoverPlayer() {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    final recovery = player.fatigue >= 70
        ? 5
        : player.fatigue >= 40
            ? 8
            : 10;

    player.fatigue = (
      player.fatigue - recovery
    ).clamp(0, 100);

    player.fitness = (
      player.fitness + recovery
    ).clamp(0, 100);
  }

  // ==========================================================
  // FORMA ZAWODNIKA
  // ==========================================================

  void updatePlayerForm() {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    if (player.fatigue >= 80) {
      player.form = (
        player.form - 2
      ).clamp(0, 100);
    } else if (player.fatigue >= 60) {
      player.form = (
        player.form - 1
      ).clamp(0, 100);
    } else if (player.fatigue <= 25) {
      player.form = (
        player.form + 1
      ).clamp(0, 100);
    }
  }

  // ==========================================================
  // DECYZJA TRENERA O STATUSIE ZAWODNIKA
  // ==========================================================

  void updateCareerPlayerMatchStatus() {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    // Jeżeli zawodnik nie ma klubu, nie może być wybierany do kadry.
    if (player.clubId == null) {
      player.inMatchSquad = false;
      player.isStarter = false;
      player.squadStatus = 'Bez klubu';
      return;
    }

    player.updateMatchStatus();

    if (!player.canPlayMatch) {
      player.isStarter = false;
    }
  }

  // ==========================================================
  // PRZYPISANIE DO KLUBU
  // ==========================================================

  void assignPlayerToClub(
    String clubId,
  ) {
    if (careerPlayer == null) {
      throw StateError(
        'Najpierw utwórz zawodnika.',
      );
    }

    final club = clubs.firstWhere(
      (club) => club.id == clubId,
    );

    final player = careerPlayer!;

    player.clubId = clubId;

    player.shirtNumber = 27;

    player.managerRelationship = 50;

    player.updateMatchStatus();

    final marketValue =
        calculateStartingMarketValue(
      player,
      club,
    );

    final salary =
        calculateStartingSalary(
      player,
      club,
    );

    player.contract = PlayerContract(
      clubId: club.id,
      yearsRemaining: 3,
      weeklySalary: salary,
      marketValue: marketValue,
      squadNumber: player.shirtNumber,
      squadStatus: player.squadStatus,
      managerTrust: player.managerRelationship,
    );
  }

  // ==========================================================
  // WARTOŚĆ POCZĄTKOWA ZAWODNIKA
  // ==========================================================

  double calculateStartingMarketValue(
    PlayerCareer player,
    Club club,
  ) {
    final ageFactor = player.age <= 21
        ? 1.25
        : player.age <= 25
            ? 1.10
            : 0.90;

    final potentialFactor =
        player.potential / 70;

    final clubFactor =
        club.overall / 70;

    return 250000 *
        player.overall *
        ageFactor *
        potentialFactor *
        clubFactor;
  }

  // ==========================================================
  // PENSJA POCZĄTKOWA
  // ==========================================================

  double calculateStartingSalary(
    PlayerCareer player,
    Club club,
  ) {
    const baseSalary = 150.0;

    final overallFactor =
        player.overall / 50;

    final clubFactor =
        club.overall / 70;

    return baseSalary *
        overallFactor *
        clubFactor;
  }

  // ==========================================================
  // TERMINARZ
  // ==========================================================

  List<Fixture> get todayFixtures {
    return fixtures.where(
      (fixture) =>
          fixture.year == state.year &&
          fixture.month == state.month &&
          fixture.day == state.day,
    ).toList();
  }

  List<Fixture> get playedFixtures {
    return fixtures.where(
      (fixture) => fixture.played,
    ).toList();
  }

  List<Fixture> get upcomingFixtures {
    return fixtures.where(
      (fixture) => !fixture.played,
    ).toList();
  }

  // ==========================================================
  // DATA
  // ==========================================================

  String get currentDate {
    return state.dateString;
  }

  // ==========================================================
  // SEZON
  // ==========================================================

  int get currentSeason {
    return state.season;
  }

  // ==========================================================
  // OKNO TRANSFEROWE - LATO
  // ==========================================================

  bool get summerTransferWindow {
    return state.transferWindowSummer;
  }

  // ==========================================================
  // OKNO TRANSFEROWE - ZIMA
  // ==========================================================

  bool get winterTransferWindow {
    return state.transferWindowWinter;
  }

  // ==========================================================
  // KLUBY EKSTRAKLASY
  // ==========================================================

  List<Club> get leagueClubs {
    return clubs
        .where(
          (club) => club.leagueId == 'pol_ek',
        )
        .toList();
  }

  // ==========================================================
  // KLUBY DOSTĘPNE NA START KARIERY
  // ==========================================================

  List<Club> get careerStartClubs {
    return clubs
        .where(
          (club) => club.leagueId == 'pol_ek',
        )
        .toList();
  }

  // ==========================================================
  // WYBÓR KLUBU NA START KARIERY
  // ==========================================================

  void startCareerAtClub(
    String clubId,
  ) {
    if (careerPlayer == null) {
      throw StateError(
        'Najpierw utwórz zawodnika.',
      );
    }

    assignPlayerToClub(clubId);
  }

  // ==========================================================
  // AKTUALNY KLUB ZAWODNIKA
  // ==========================================================

  Club? get careerClub {
    if (careerPlayer == null) {
      return null;
    }

    final clubId = careerPlayer!.clubId;

    if (clubId == null) {
      return null;
    }

    for (final club in clubs) {
      if (club.id == clubId) {
        return club;
      }
    }

    return null;
  }

  // ==========================================================
  // CZY ZAWODNIK MA KLUB
  // ==========================================================

  bool get hasCareerClub {
    return careerPlayer?.clubId != null;
  }
}
