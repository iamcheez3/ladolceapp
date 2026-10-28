import 'dart:convert';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';

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

  final Map<String, MemoryImage> _avatarCache = {};

  MemoryImage? _mem(String? b64) {
    if (b64 == null || b64.trim().isEmpty) return null;
    final clean = b64.trim();
    if (_avatarCache.containsKey(clean)) return _avatarCache[clean];
    try {
      final img = MemoryImage(base64Decode(clean));
      _avatarCache[clean] = img;
      return img;
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
        backgroundColor: Ld.ground,
        backgroundImage: img,
        child: img == null
            ? Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: TextStyle(
                  fontFamily: Ld.serif,
                  fontWeight: FontWeight.w700,
                  fontSize: r * 0.6,
                  color: Ld.navy,
                ),
              )
            : null,
      ),
    );
  }

  /// Points with a star; [onNavy] uses the gold accent allowed on navy.
  Widget _pointsPill(int points, {bool onNavy = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onNavy ? Ld.navyRaised : Ld.goldWash,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onNavy ? Ld.navyLine : Ld.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16, color: onNavy ? Ld.gold : Ld.goldInk),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$points',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ld.price(14, color: onNavy ? Ld.gold : Ld.goldWashInk),
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
          if (crown)
            const Icon(Icons.emoji_events_rounded, color: Ld.gold, size: 26)
          else
            const SizedBox(height: 26),
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 3),
                ),
                child: _avatar(name: name, base64: data?['image_base64']?.toString(), r: radius),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: place == 1 ? Ld.navy : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: place == 1 ? Ld.navy : Ld.line),
                  ),
                  child: Text(
                    '$place',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: place == 1 ? Ld.gold : Ld.navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name.isEmpty ? '-' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Ld.ink),
          ),
          const SizedBox(height: 6),
          _pointsPill(points),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
      decoration: Ld.card(radius: Ld.rXl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: slot(
              place: 2,
              data: second,
              radius: 32,
              ring: Ld.navyLine,
            ),
          ),
          Expanded(
            child: slot(
              place: 1,
              data: first,
              radius: 42,
              ring: Ld.gold,
              crown: true,
            ),
          ),
          Expanded(
            child: slot(
              place: 3,
              data: third,
              radius: 32,
              ring: Ld.faint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final rest = _top.length > 3 ? _top.sublist(3) : const <Map<String, dynamic>>[];
    if (rest.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rest.length; i++) _row(rest[i], i),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> item, int i) {
    final rank = int.tryParse((item['rank'] ?? item['reward_rank'] ?? (i + 4)).toString()) ?? (i + 4);
    final name = (item['name'] ?? '').toString();
    final points = int.tryParse((item['reward_points'] ?? 0).toString()) ?? 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: i == 0 ? null : const Border(top: BorderSide(color: Ld.lineSoft)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Ld.muted),
            ),
          ),
          const SizedBox(width: 6),
          _avatar(name: name, base64: item['image_base64']?.toString(), r: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name.isEmpty ? '-' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Ld.ink),
            ),
          ),
          const SizedBox(width: 8),
          _pointsPill(points),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myRank = widget.myRank;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.ranking ?? 'Ranking',
        subtitle: l10n?.climbTheAdventureLadder ?? 'Climb the adventure ladder!',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: Ld.navy,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 18 + Ld.navInset(context)),
              children: [
                // Your own rank, on navy like the header.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ld.navy,
                    borderRadius: BorderRadius.circular(Ld.rXl),
                  ),
                  child: Row(
                    children: [
                      _avatar(name: widget.myName, base64: widget.myImageBase64, r: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myRank == null || myRank <= 0
                                  ? (l10n?.yourRank ?? 'Your rank: -')
                                  : 'Your rank: $myRank',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.myName.trim().isNotEmpty)
                              Text(
                                widget.myName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Ld.onNavyMuted, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pointsPill(widget.myPoints, onNavy: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: CircularProgressIndicator(color: Ld.navy),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: Ld.card(border: Ld.dangerLine),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Ld.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n?.cannotLoadRanking ?? 'Cannot load ranking',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Ld.ink),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_error!, style: Ld.label),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: Text(l10n?.retry ?? 'Retry'),
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
      ),
    );
  }
}

