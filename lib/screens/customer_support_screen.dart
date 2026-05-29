import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSupportScreen extends StatelessWidget {
  final String facebookUrl;
  final String whatsappNumber;
  final String whatsappLink;

  const CustomerSupportScreen({
    super.key,
    this.facebookUrl = '',
    this.whatsappNumber = '',
    this.whatsappLink = '',
  });

  static const Color _brandNavy = Color(0xFF001460);
  static const Color _brandNavy2 = Color(0xFF142B8C);

  Future<void> _openUrl(String? raw) async {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return;
    var uri = Uri.tryParse(t);
    if (uri == null || !uri.hasScheme) {
      uri = Uri.tryParse('https://$t');
    }
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasFb = facebookUrl.trim().isNotEmpty;
    final hasWa = whatsappLink.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer support'),
        backgroundColor: _brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brandNavy, _brandNavy2, Color(0xFFF6F7FB)],
            stops: [0.0, 0.22, 0.22],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Reach the admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use the options your store has enabled in Odoo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'f',
                            style: TextStyle(
                              color: Color(0xFF1877F2),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Facebook',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _brandNavy,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!hasFb)
                      const Text(
                        'Not configured. Ask staff to set the Facebook URL in Odoo (Customer support links).',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else ...[
                      Text(
                        facebookUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openUrl(facebookUrl),
                        icon: const Icon(Icons.open_in_new, size: 20),
                        label: const Text('Open Facebook'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandNavy,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat, color: Color(0xFF25D366), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _brandNavy,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!hasWa)
                      const Text(
                        'Not configured. Ask staff to set the WhatsApp number in Odoo (Customer support links).',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else ...[
                      if (whatsappNumber.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            whatsappNumber,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Text(
                        whatsappLink,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: QrImageView(
                              data: whatsappLink,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openUrl(whatsappLink),
                        icon: const Icon(Icons.chat, size: 20),
                        label: const Text('Open in WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: child,
      ),
    );
  }
}
