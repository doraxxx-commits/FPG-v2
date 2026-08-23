class Fixture {
  final int round;
  final String homeClubId;
  final String awayClubId;

  final int year;
  final int month;
  final int day;

  bool played;
  int? homeGoals;
  int? awayGoals;

  Fixture({
    required this.round,
    required this.homeClubId,
    required this.awayClubId,
    required this.year,
    required this.month,
    required this.day,
    this.played = false,
    this.homeGoals,
    this.awayGoals,
  });
}
