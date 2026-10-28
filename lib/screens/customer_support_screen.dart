import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/ld.dart';

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
    final l10n = AppLocalizations.of(context);
    final hasFb = facebookUrl.trim().isNotEmpty;
    final hasWa = whatsappLink.trim().isNotEmpty;

    final fbCard = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            const LdIconTile(Icons.facebook_rounded, background: Ld.infoWash, color: Ld.info),
            'Facebook',
          ),
          const SizedBox(height: 12),
          if (!hasFb)
            const Text(
              'Not configured. Ask staff to set the Facebook URL in Odoo (Customer support links).',
              style: Ld.label,
            )
          else ...[
            Text(
              facebookUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ld.small,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _openUrl(facebookUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              label: Text(l10n?.openFacebook ?? 'Open Facebook'),
            ),
          ],
        ],
      ),
    );

    final waCard = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            const LdIconTile(Icons.chat_outlined, background: Ld.successWash, color: Ld.success),
            'WhatsApp',
          ),
          const SizedBox(height: 12),
          if (!hasWa)
            const Text(
              'Not configured. Ask staff to set the WhatsApp number in Odoo (Customer support links).',
              style: Ld.label,
            )
          else ...[
            if (whatsappNumber.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  whatsappNumber,
                  style: Ld.price(18, color: Ld.ink),
                ),
              ),
            Text(
              whatsappLink,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ld.small,
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: Ld.card(radius: Ld.r),
                child: QrImageView(
                  data: whatsappLink,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openUrl(whatsappLink),
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: Text(l10n?.openInWhatsapp ?? 'Open in WhatsApp'),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.customerSupport ?? 'Customer support',
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + Ld.navInset(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 960 : 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n?.reachTheAdmin ?? 'Reach the admin',
                      style: Ld.title(22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.useTheOptionsYourStoreHas ?? 'Use the options your store has enabled in Odoo.',
                      style: Ld.label,
                    ),
                    const SizedBox(height: 18),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fbCard),
                          const SizedBox(width: 14),
                          Expanded(child: waCard),
                        ],
                      )
                    else ...[
                      fbCard,
                      const SizedBox(height: 14),
                      waCard,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cardTitle(Widget icon, String title) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Ld.ink, fontSize: 17),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}
