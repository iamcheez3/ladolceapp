import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import 'topping_edit_screen.dart';
import '../utils/l10n_ext.dart';

class ManageToppingsScreen extends StatefulWidget {
  const ManageToppingsScreen({super.key});

  @override
  State<ManageToppingsScreen> createState() => _ManageToppingsScreenState();
}

class _ManageToppingsScreenState extends State<ManageToppingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Topping> _toppings = [];

  static const Color _accent = Colors.green;

  @override
  void initState() {
    super.initState();
    _fetchToppings();
  }

  Future<void> _fetchToppings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchToppings();
      if (mounted) {
        setState(() {
          _toppings = data.map((json) => Topping.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _openToppingScreen({Topping? topping}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ToppingEditScreen(topping: topping),
      ),
    ).then((saved) {
      if (saved == true) _fetchToppings();
    });
  }

  Future<void> _deleteTopping(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteTopping),
        content: Text(context.l10n.areYouSureYouWantTo4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: LaDolcePosUi.primaryButtonStyle(isDestructive: true),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteTopping(id);
      _fetchToppings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.toppingDeleted), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorWithMessage(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.manageToppings),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.addTopping,
            onPressed: () => _openToppingScreen(),
          ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchToppings,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(context.l10n.retry),
                            style: LaDolcePosUi.primaryButtonStyle(),
                          ),
                        ],
                      ),
                    ),
                  )
                : _toppings.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(Icons.eco_outlined, color: _accent.withValues(alpha: 0.5), size: 40),
                              ),
                              const SizedBox(height: 20),
                              Text(context.l10n.noToppingsYet, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(context.l10n.addYourFirstToppingToGet,
                                  style: TextStyle(fontSize: 14, color: LaDolcePosUi.mutedText)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(context.l10n.addTopping),
                                onPressed: () => _openToppingScreen(),
                                style: LaDolcePosUi.primaryButtonStyle(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
                        itemCount: _toppings.length,
                        itemBuilder: (context, index) {
                          final topping = _toppings[index];
                          return _ToppingCard(
                            topping: topping,
                            accent: _accent,
                            onTap: () => _openToppingScreen(topping: topping),
                            onDelete: () => _deleteTopping(topping.id),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openToppingScreen(),
      ),
    );
  }
}

class _ToppingCard extends StatelessWidget {
  final Topping topping;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ToppingCard({
    required this.topping,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
        child: Container(
          decoration: BoxDecoration(
            color: LaDolcePosUi.card,
            borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
            border: Border.all(color: LaDolcePosUi.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.eco_outlined, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topping.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: topping.extraPrice > 0
                              ? accent.withValues(alpha: 0.1)
                              : LaDolcePosUi.mutedText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          topping.extraPrice > 0
                              ? '+\$${topping.extraPrice.toStringAsFixed(2)}'
                              : context.l10n.free,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: topping.extraPrice > 0 ? accent : LaDolcePosUi.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 36, height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.red.withValues(alpha: 0.7),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    tooltip: context.l10n.delete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
