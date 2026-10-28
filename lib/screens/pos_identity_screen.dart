import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';
import 'pin_screen.dart';

class PosIdentityScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const PosIdentityScreen({super.key, required this.user});

  @override
  State<PosIdentityScreen> createState() => _PosIdentityScreenState();
}

class _PosIdentityScreenState extends State<PosIdentityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _posNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefillPosName();
  }

  Future<void> _prefillPosName() async {
    final cachedPos = await ApiService().getCachedPosName();
    if (!mounted) return;
    if (cachedPos != null && cachedPos.isNotEmpty) {
      _posNameController.text = cachedPos;
      _posNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _posNameController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _posNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final api = ApiService();
    final posName = _posNameController.text.trim();
    final branchId = await api.getCachedBranchId();
    final branchName = await api.getCachedBranchName();
    bool okToNavigate = true;

    try {
      await api.setCachedPosName(posName);

      final userId = (widget.user['user_id'] is int)
          ? widget.user['user_id'] as int
          : int.tryParse(widget.user['user_id']?.toString() ?? '') ?? 0;
      final cashierName = (widget.user['name'] ?? (AppLocalizations.of(context)?.roleCashier ?? 'Cashier')).toString();

      // Mark this login's POS-name prompt as completed so app resume won't ask again.
      await api.clearPosIdentityRequiredFlag();

      // Best-effort: do not block cashier if backend is offline.
      await api.registerPosDevice(
        userId: userId,
        cashierName: cashierName,
        posName: posName,
        branchId: branchId,
        branchName: branchName,
      );
    } catch (_) {
      // ignore; registration retries during syncAllData()
      // Still clear the flag so cashier can proceed; pending payload will retry.
      try {
        await api.clearPosIdentityRequiredFlag();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    if (!mounted || !okToNavigate) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PinScreen(cachedUser: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tablet = Ld.isTablet(context);
    final short = MediaQuery.sizeOf(context).height < 700;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Ld.r),
          borderSide: BorderSide(color: c, width: w),
        );

    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: tablet
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 26, 24, 20 + (tablet ? 4 : Ld.navInset(context))),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const LdIconTile(Icons.point_of_sale_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n?.setPosName ?? 'Set POS Name',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ld.title(22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.thisHelpsTrackWhichDeviceWas ??
                  'This helps track which device was used when something happens.',
              style: Ld.label,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _posNameController,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveAndContinue(),
              style: Ld.body,
              decoration: InputDecoration(
                labelText: l10n?.posNameExCounter1Ipad ??
                    'POS name (ex: Counter-1, iPad-Bar, Android-Front)',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.store_mall_directory_outlined,
                  color: Ld.muted,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                border: border(Ld.line),
                enabledBorder: border(Ld.line),
                focusedBorder: border(Ld.navy, 1.5),
                errorBorder: border(Ld.danger),
                focusedErrorBorder: border(Ld.danger, 1.5),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return (l10n?.pleaseEnterAPosName ?? 'Please enter a POS name');
                if (s.length < 2) return (l10n?.posNameIsTooShort ?? 'POS name is too short');
                if (s.length > 40) return (l10n?.posNameIsTooLong ?? 'POS name is too long');
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Ld.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Ld.navy.withValues(alpha: 0.75),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Ld.rMd),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'Saving…' : (l10n?.continueLabel ?? 'Continue')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline_rounded, size: 16, color: Ld.muted),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'We will also send device info (Android/iOS + model) to the backend for auditing.',
                    style: Ld.small.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Ld.navy,
      body: SafeArea(
        bottom: tablet,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/ladolce_bear_logo.png',
                              width: short ? 64 : 88,
                              height: short ? 64 : 88,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.pets_rounded,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('LaDolce', style: Ld.title(short ? 28 : 34, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (tablet)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: card,
                      ),
                    )
                  else
                    card,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

