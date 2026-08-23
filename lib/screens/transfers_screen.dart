import 'dart:math';
import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../models/club.dart';

class TransferOffer {
  final String id;
  final Club club;
  final int offeredSalary;
  final int contractYears;
  final String transferType; // 'TRANSFER' lub 'LOAN'

  TransferOffer({
    required this.id,
    required this.club,
    required this.offeredSalary,
    required this.contractYears,
    required this.transferType,
  });
}

class TransfersScreen extends StatefulWidget {
  final GameEngine engine;

  const TransfersScreen({
    super.key,
    required this.engine,
  });

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  late List<TransferOffer> _offers;

  @override
  void initState() {
    super.initState();
    _generateOffers();
  }

  void _generateOffers() {
    final player = widget.engine.careerPlayer;
    if (player == null) {
      _offers = [];
      return;
    }

    final rnd = Random();
    final allClubs = widget.engine.clubs.where((c) => c.id != player.clubId).toList();

    if (allClubs.isEmpty) {
      _offers = [];
      return;
    }

    // Generujemy 1-3 losowe oferty od rywali zależnie od OVR i statusu
    final offerCount = rnd.nextInt(3) + 1;
    _offers = List.generate(offerCount, (index) {
      final club = allClubs[rnd.nextInt(allClubs.length)];
      final baseSalary = (player.contract?.weeklySalary ?? 1000) * (0.9 + rnd.nextDouble() * 0.4);
      final isLoan = player.age < 21 && rnd.nextBool();

      return TransferOffer(
        id: 'offer_$index',
        club: club,
        offeredSalary: baseSalary.round(),
        contractYears: rnd.nextInt(3) + 2,
        transferType: isLoan ? 'LOAN' : 'TRANSFER',
      );
    });
  }

  void _acceptOffer(TransferOffer offer) {
    final player = widget.engine.careerPlayer;
    if (player == null || player.contract == null) return;

    setState(() {
      player.clubId = offer.club.id;
      player.contract!.weeklySalary = offer.offeredSalary.toDouble();
      player.contract!.yearsRemaining = offer.contractYears;
      _offers.removeWhere((o) => o.id == offer.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Oficjalnie dołączono do ${offer.club.name}! Gratulacje! 🎉'),
        backgroundColor: Colors.green[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.engine.careerPlayer;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        title: const Text('Rynek Transferowy'),
        backgroundColor: const Color(0xFF080A0F),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _generateOffers();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // PODSUMOWANIE WARTOŚCI
            Card(
              color: const Color(0xFF131722),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wartość Rynkowa', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${player?.contract?.marketValue.toStringAsFixed(0) ?? "0"} €',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Obecna Pensja', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${player?.contract?.weeklySalary.toStringAsFixed(0) ?? "0"} € / tyg',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'OTRZYMANE OFERTY',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_offers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'Brak aktywnych ofert transferowych.\nGraj lepiej i podnoś swój OVR, by zwrócić uwagę skautów!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                  ),
                ),
              )
            else
              ..._offers.map((offer) {
                return Card(
                  color: const Color(0xFF1E2638),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              offer.club.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: offer.transferType == 'LOAN' ? Colors.orangeAccent : Colors.blueAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                offer.transferType == 'LOAN' ? 'WYPOŻYCZENIE' : 'TRANSFER',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Oferowana pensja: ${offer.offeredSalary} € / tydzień', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('Długość kontraktu: ${offer.contractYears} lata', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _acceptOffer(offer),
                            child: const Text('AKCEPTUJ OFERTĘ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
