import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RankingScreen extends StatefulWidget {
  final int? myRank;
  final int myPoints;
  final String myName;
  final String? myImageBase64;

  const RankingScreen({
    super.key,
    required this.myRank,
    required this.myPoints,
    required this.myName,
    required this.myImageBase64,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const Color _brandNavy = Color(0xFF0D1565);
  static const Color _brandNavy2 = Color(0xFF142B8C);
  static const Color _surface = Color(0xFFF6F7FB);

  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _top = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchRankingTop50();
      if (!mounted) return;
      setState(() {
        _top = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  MemoryImage? _mem(String? b64) {
    if (b64 == null || b64.trim().isEmpty) return null;
    try {
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  Widget _avatar({required String name, String? base64, double r = 34}) {
    final img = _mem(base64);
    return CircleAvatar(
      radius: r,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: r - 3,
        backgroundColor: const Color(0xFFF2F5FF),
        backgroundImage: img,
        child: img == null
            ? Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: r * 0.6,
                  color: _brandNavy,
                ),
              )
            : null,
      ),
    );
  }

  Widget _pointsPill(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Text(
            '$points',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF7C2D12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _podium() {
    final first = _top.isNotEmpty ? _top[0] : null;
    final second = _top.length > 1 ? _top[1] : null;
    final third = _top.length > 2 ? _top[2] : null;

    Widget slot({
      required int place,
      required Map<String, dynamic>? data,
      required double radius,
      required Color ring,
      bool crown = false,
    }) {
      final name = (data?['name'] ?? '').toString();
      final points = int.tryParse((data?['reward_points'] ?? 0).toString()) ?? 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(height: crown ? 18 : 0),
              if (crown)
                const Positioned(
                  top: 0,
                  child: Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B)),
                ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 3),
                ),
                child: _avatar(name: name, base64: data?['image_base64']?.toString(), r: radius),
              ),
              Positioned(
                bottom: -8,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '$place',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? '-' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          _pointsPill(points),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: slot(
              place: 2,
              data: second,
              radius: 34,
              ring: const Color(0xFF60A5FA),
            ),
          ),
          Expanded(
            child: slot(
              place: 1,
              data: first,
              radius: 44,
              ring: const Color(0xFFF59E0B),
              crown: true,
            ),
          ),
          Expanded(
            child: slot(
              place: 3,
              data: third,
              radius: 34,
              ring: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final rest = _top.length > 3 ? _top.sublist(3) : const <Map<String, dynamic>>[];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rest.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final item = rest[i];
          final rank = int.tryParse((item['rank'] ?? item['reward_rank'] ?? (i + 4)).toString()) ?? (i + 4);
          final name = (item['name'] ?? '').toString();
          final points = int.tryParse((item['reward_points'] ?? 0).toString()) ?? 0;
          return ListTile(
            leading: SizedBox(
              width: 42,
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            title: Row(
              children: [
                _avatar(name: name, base64: item['image_base64']?.toString(), r: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name.isEmpty ? '-' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            trailing: _pointsPill(points),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myRank = widget.myRank;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        foregroundColor: Colors.white,
        title: const Text('Ranking'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brandNavy, _brandNavy2, _surface],
            stops: [0.0, 0.22, 0.22],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              Text(
                'Ranking',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Climb the adventure ladder!',
                style: TextStyle(
                  color: Color(0xFFDCE5FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    _avatar(name: widget.myName, base64: widget.myImageBase64, r: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        myRank == null || myRank <= 0
                            ? 'Your rank: -'
                            : 'Your rank: $myRank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _pointsPill(widget.myPoints),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cannot load ranking',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(_error!),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                _podium(),
                const SizedBox(height: 14),
                _list(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

