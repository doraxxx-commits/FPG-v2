import 'package:flutter/material.dart';
import '../core/game_engine.dart';

class PlayerDevelopmentScreen extends StatelessWidget {
  final GameEngine engine;

  const PlayerDevelopmentScreen({
    super.key,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final player = engine.careerPlayer;

    if (player == null) {
      return const Scaffold(
        body: Center(child: Text('Brak danych zawodnika.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        title: const Text('Rozwój i Perki'),
        backgroundColor: const Color(0xFF080A0F),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // PODSUMOWANIE OVR I POTENCJAŁU
            Card(
              color: const Color(0xFF1E2638),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn('OVR', '${player.overall}', Colors.greenAccent),
                    Container(height: 40, width: 1, color: Colors.white24),
                    _statColumn('POTENCJAŁ', '${player.potential}', Colors.blueAccent),
                    Container(height: 40, width: 1, color: Colors.white24),
                    _statColumn('WIEK', '${player.age}', Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // SZCZEGÓŁOWE ATRYBUTY
            const Text(
              'ATRYBUTY ZAWODNIKA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _attributeBar('Szybkość / Tempo (PAC)', player.pace),
            _attributeBar('Strzały (SHO)', player.shooting),
            _attributeBar('Podania (PAS)', player.passing),
            _attributeBar('Drybling (DRI)', player.dribbling),
            _attributeBar('Obrona (DEF)', player.defending),
            _attributeBar('Fizyczność (PHY)', player.physical),

            const SizedBox(height: 24),

            // PERKI KARIERY
            const Text(
              'PERKI KARIERY',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _perkTile(
              title: '🔥 Snajper',
              subtitle: '+5% do celności wykończenia w polach karnych',
              isUnlocked: player.overall >= 70,
              unlockCondition: 'Wymagany OVR 70+',
            ),
            _perkTile(
              title: '⚡ Sprinter',
              subtitle: 'Mniejsze zmęczenie podczas szybkich kontrataków',
              isUnlocked: player.pace >= 75,
              unlockCondition: 'Wymagana Szybkość 75+',
            ),
            _perkTile(
              title: '🧊 Clutch Player',
              subtitle: 'Wzrost statystyk po 80. minucie przy remisie lub przegranej',
              isUnlocked: player.overall >= 80,
              unlockCondition: 'Wymagany OVR 80+',
            ),
            _perkTile(
              title: '🧠 Lider Szatni',
              subtitle: 'Zwiększa morale całej drużyny przed ważnym meczem',
              isUnlocked: player.overall >= 85,
              unlockCondition: 'Wymagany OVR 85+',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _attributeBar(String name, int val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(color: Colors.white.withOpacity(0.87))),
              Text('$val', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (val.clamp(0, 99)) / 99.0,
            backgroundColor: Colors.white10,
            color: val >= 80 ? Colors.greenAccent : (val >= 70 ? Colors.blueAccent : Colors.orangeAccent),
          ),
        ],
      ),
    );
  }

  Widget _perkTile({
    required String title,
    required String subtitle,
    required bool isUnlocked,
    required String unlockCondition,
  }) {
    return Card(
      color: isUnlocked ? const Color(0xFF1E2638) : Colors.white.withValues(alpha: 0.03),
      child: ListTile(
        leading: Icon(
          isUnlocked ? Icons.verified : Icons.lock,
          color: isUnlocked ? Colors.greenAccent : Colors.white30,
          size: 30,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isUnlocked ? Colors.white : Colors.white38,
          ),
        ),
        subtitle: Text(
          isUnlocked ? subtitle : 'Zablokowano: $unlockCondition',
          style: TextStyle(
            color: isUnlocked ? Colors.white70 : Colors.white30,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
