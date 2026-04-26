import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/coffee_luxury_background.dart';
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
    final cached = await ApiService().getCachedPosName();
    if (!mounted) return;
    if (cached != null && cached.isNotEmpty) {
      _posNameController.text = cached;
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
    bool okToNavigate = true;

    try {
      await api.setCachedPosName(posName);

      final userId = (widget.user['user_id'] is int)
          ? widget.user['user_id'] as int
          : int.tryParse(widget.user['user_id']?.toString() ?? '') ?? 0;
      final cashierName = (widget.user['name'] ?? 'Cashier').toString();

      // Mark this login's POS-name prompt as completed so app resume won't ask again.
      await api.clearPosIdentityRequiredFlag();

      // Best-effort: do not block cashier if backend is offline.
      await api.registerPosDevice(
        userId: userId,
        cashierName: cashierName,
        posName: posName,
      );
    } catch (_) {
      // ignore; registration retries during syncAllData()
      // Still clear the flag so cashier can proceed; pending payload will retry.
      try {
        await api.clearPosIdentityRequiredFlag();
      } catch (_) {}
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }

    if (!mounted || !okToNavigate) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PinScreen(cachedUser: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCoffeeBrandNavy,
      body: PinStyleBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Set POS Name',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This helps track which device was used when something happens.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _posNameController,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _saveAndContinue(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'POS name (ex: Counter-1, iPad-Bar, Android-Front)',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.10),
                            prefixIcon: Icon(
                              Icons.store_mall_directory_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: kCoffeeGold,
                                width: 1.6,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Please enter a POS name';
                            if (s.length < 2) return 'POS name is too short';
                            if (s.length > 40) return 'POS name is too long';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveAndContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kCoffeeGold,
                              foregroundColor: kCoffeeBrandNavy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kCoffeeBrandNavy,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(_isSaving ? 'Saving…' : 'Continue'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We will also send device info (Android/iOS + model) to the backend for auditing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

