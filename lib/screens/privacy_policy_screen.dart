import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';
import '../utils/responsive_layout.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _policyData;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  Future<void> _loadPrivacyPolicy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchPrivacyPolicy();
      if (mounted) {
        setState(() {
          _policyData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load Privacy Policy. Please check your network connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: AppLocalizations.of(context)?.privacyPolicy ?? 'Privacy Policy',
        leading: LdNavIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Ld.navy,
          strokeWidth: 3,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: Ld.card(border: Ld.dangerLine),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LdIconTile(
                  Icons.error_outline_rounded,
                  size: 56,
                  background: Ld.dangerWash,
                  color: Ld.danger,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Ld.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadPrivacyPolicy,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sections = _policyData?['sections'] as List<dynamic>? ?? [];
    final lastUpdated = _policyData?['last_updated'] ?? 'June 10, 2026';

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.pageHorizontalPadding(context),
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: Ld.card(radius: Ld.rXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.ladolcePrivacy ?? 'LaDolce Privacy',
                      style: Ld.title(22),
                    ),
                    LdPill(
                      AppLocalizations.of(context)?.official ?? 'Official',
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Last Updated: $lastUpdated',
                  style: Ld.small,
                ),
                const Divider(height: 32, color: Ld.lineSoft),
                ...sections.map((section) {
                  final title = section['title']?.toString() ?? '';
                  final content = section['content']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Ld.navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: Ld.ink,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '© 2026 LaDolce. All rights reserved.',
            textAlign: TextAlign.center,
            style: Ld.small,
          ),
        ],
      ),
    );
  }
}
