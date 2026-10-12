import 'package:flutter/material.dart';

import '../theme/ladolce_pos_ui.dart';
import '../utils/l10n_ext.dart';

/// "Custom name" / "Rename" dialog for an open ticket. Returns the trimmed
/// name, or null on Cancel.
Future<String?> showTicketNameDialog(
  BuildContext context, {
  required String title,
  required String help,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => TicketNameDialog(title: title, help: help, initial: initial),
);

class TicketNameDialog extends StatefulWidget {
  final String title;
  final String help;
  final String initial;

  const TicketNameDialog({
    super.key,
    required this.title,
    required this.help,
    this.initial = '',
  });

  @override
  State<TicketNameDialog> createState() => _TicketNameDialogState();
}

class _TicketNameDialogState extends State<TicketNameDialog> {
  // Owned by the dialog, so it is only disposed once the dialog has finished
  // closing.
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: LaDolcePosUi.text,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.help,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: LaDolcePosUi.mutedText,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration:
                  LaDolcePosUi.input(
                    hintText: l10n.ticketNameHint,
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ).copyWith(
                    labelText: l10n.ticketNameLabel,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: Text(l10n.cancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, _) => ElevatedButton(
            onPressed: value.text.trim().isEmpty ? null : _save,
            style: LaDolcePosUi.primaryButtonStyle(),
            child: Text(l10n.save),
          ),
        ),
      ],
    );
  }
}
