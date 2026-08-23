import 'dart:math';
import '../models/agent.dart';
import '../models/player.dart';


/// Zarządza portfelami agentów i ich wpływem na decyzje zawodników.
class AgentEngine {
  final Random _random;
  final List<Agent> agents = [];
  final Map<String, List<String>> clients = {};

  AgentEngine({Random? random}) : _random = random ?? Random();

  void ensureAgents(List<Player> players) {
    for (final player in players) {
      if (player.agentId != null) {
        _attach(player.agentId!, player.id);
        continue;
      }
      // Nie każdy zawodnik musi mieć agenta. Więksi i młodzi z wysokim POT
      // mają większą szansę wejścia do profesjonalnego portfela.
      final chance = player.overall >= 72 ? .85 : player.potential >= 82 ? .72 : .28;
      if (_random.nextDouble() > chance) continue;
      final agent = _createAgent(player);
      player.agentId = agent.id;
      player.agentInfluence = agent.marketInfluence;
      _attach(agent.id, player.id);
    }
  }

  Agent _createAgent(Player player) {
    final index = agents.length + 1;
    final agent = Agent(
      id: 'agent_$index',
      name: '${_first[_random.nextInt(_first.length)]} ${_last[_random.nextInt(_last.length)]}',
      reputation: (45 + player.overall ~/ 3 + _random.nextInt(20)).clamp(30, 95).toInt(),
      negotiationSkill: (45 + player.potential ~/ 4 + _random.nextInt(20)).clamp(30, 95).toInt(),
      marketInfluence: (35 + player.overall ~/ 3 + _random.nextInt(25)).clamp(25, 95).toInt(),
      loyalty: (35 + _random.nextInt(60)).clamp(20, 95),
      wageDemand: 5 + _random.nextInt(20),
      aggressiveInNegotiations: _random.nextDouble() < .35,
    );
    agents.add(agent);
    clients[agent.id] = [];
    return agent;
  }

  Agent? agentById(String id) {
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  void changeAgent(Player player, Agent newAgent) {
    if (player.agentId == newAgent.id) return;
    if (player.agentId != null) {
      clients[player.agentId!]?.remove(player.id);
    }
    player.agentId = newAgent.id;
    player.agentInfluence = newAgent.marketInfluence;
    _attach(newAgent.id, player.id);
  }

  Agent? findBestAlternative(Player player) {
    if (agents.isEmpty) return null;
    final candidates = agents.where((a) => a.id != player.agentId).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final ascore = a.reputation + a.negotiationSkill + a.marketInfluence + a.loyalty;
      final bscore = b.reputation + b.negotiationSkill + b.marketInfluence + b.loyalty;
      return bscore.compareTo(ascore);
    });
    return candidates.first;
  }

  void processClientGrowth(List<Player> players) {
    for (final agent in agents) {
      final clientIds = clients[agent.id] ?? const <String>[];
      final activeClients = players.where((p) => clientIds.contains(p.id)).length;
      if (activeClients >= 5) agent.marketInfluence = min(95, agent.marketInfluence + 1);
      if (activeClients == 0) agent.reputation = max(20, agent.reputation - 1);
    }
  }

  void _attach(String agentId, String playerId) {
    clients.putIfAbsent(agentId, () => <String>[]);
    if (!clients[agentId]!.contains(playerId)) clients[agentId]!.add(playerId);
  }

  static const _first = ['Marco', 'Luca', 'Adrian', 'Daniel', 'Michał', 'Thomas', 'Victor', 'Alex'];
  static const _last = ['Rossi', 'Silva', 'Kowalski', 'Weber', 'Costa', 'Müller', 'Nowak', 'Santos'];
}
