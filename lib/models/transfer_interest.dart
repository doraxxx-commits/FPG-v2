/// Trwałe zainteresowanie klubu zawodnikiem. Nie jest jeszcze transferem —
/// przechodzi przez scouting, ofertę i negocjacje.
class TransferInterest {
  final String id;
  final String clubId;
  final String playerId;
  int score;
  String stage; // scouting, serious, offer, negotiation, cooling
  int daysActive;
  int lastContactDay;
  bool playerAware;
  int awarenessDay;
  String playerDecision;

  TransferInterest({
    required this.id,
    required this.clubId,
    required this.playerId,
    this.score = 25,
    this.stage = 'scouting',
    this.daysActive = 0,
    this.lastContactDay = 0,
    this.playerAware = false,
    this.awarenessDay = 0,
    this.playerDecision = 'pending',
  });
}
