import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../theme/ld.dart';
import 'combo_edit_screen.dart';
import 'manage_items_screen.dart';
import '../utils/money.dart';

class ManageCombosScreen extends StatefulWidget {
  const ManageCombosScreen({super.key});

  @override
  State<ManageCombosScreen> createState() => _ManageCombosScreenState();
}

class _ManageCombosScreenState extends State<ManageCombosScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _combos = [];
  List<Product> _allProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        _apiService.fetchCombos(),
        _apiService.fetchProducts(forceRefresh: true),
      ]);

      if (mounted) {
        setState(() {
          _combos = futures[0];
          _allProducts = futures[1] as List<Product>;
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

  void _openComboScreen({Map<String, dynamic>? combo}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ComboEditScreen(
          combo: combo,
          allProducts: _allProducts,
        ),
      ),
    ).then((saved) {
      if (saved == true) _fetchData();
    });
  }

  Future<void> _deleteCombo(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deleteCombo ?? 'Delete Combo'),
        content: Text(AppLocalizations.of(context)?.areYouSureYouWantTo2 ?? 'Are you sure you want to delete this combo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: itemsDangerButtonStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteCombo(id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.comboDeleted ?? 'Combo deleted'), backgroundColor: Ld.warning),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Ld.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gutter = itemsGutter(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      appBar: LdHeader(
        title: l10n?.manageCombos ?? 'Manage Combos',
        actions: [
          ItemsHeaderAction(
            label: l10n?.addCombo ?? 'Add Combo',
            icon: Icons.add_rounded,
            onPressed: () => _openComboScreen(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? ItemsStateView(
                  icon: Icons.error_outline_rounded,
                  title: _errorMessage!,
                  isError: true,
                  actionLabel: l10n?.retry ?? 'Retry',
                  actionIcon: Icons.refresh_rounded,
                  onAction: _fetchData,
                )
              : _combos.isEmpty
                  ? ItemsStateView(
                      icon: Icons.dashboard_customize_outlined,
                      title: l10n?.noCombosYet ?? 'No combos yet',
                      message: l10n?.addYourFirstComboToGet ?? 'Add your first combo to get started',
                      actionLabel: l10n?.addCombo ?? 'Add Combo',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _openComboScreen(),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 96 + Ld.navInset(context)),
                        itemCount: _combos.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final combo = _combos[index];
                          final itemsCount = (combo['lines'] as List).length;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: _ComboCard(
                                name: combo['name'] ?? '',
                                price: (combo['price'] ?? 0.0).toDouble(),
                                itemsCount: itemsCount,
                                wide: wide,
                                onTap: () => _openComboScreen(combo: combo),
                                onDelete: () => _deleteCombo(combo['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        tooltip: l10n?.addCombo ?? 'Add Combo',
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openComboScreen(),
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  final String name;
  final double price;
  final int itemsCount;
  final bool wide;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ComboCard({
    required this.name,
    required this.price,
    required this.itemsCount,
    required this.wide,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rMd),
        side: const BorderSide(color: Ld.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Ld.ground, borderRadius: BorderRadius.circular(Ld.r)),
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                  style: Ld.title(20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Ld.ink),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('₭${money(price)}', style: Ld.price(16, weight: FontWeight.w600)),
                        LdPill(
                          l10n?.itemsCount('$itemsCount') ?? '$itemsCount item${itemsCount == 1 ? '' : 's'}',
                          icon: Icons.widgets_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (wide) ...[
                const ItemsEditMark(),
                const SizedBox(width: 8),
              ],
              ItemsRowButton(
                icon: Icons.delete_outline_rounded,
                tooltip: l10n?.delete ?? 'Delete',
                danger: true,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
