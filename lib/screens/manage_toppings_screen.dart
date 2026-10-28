import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/topping.dart';
import '../theme/ld.dart';
import '../widgets/topping_picker.dart';
import 'manage_items_screen.dart';
import 'manage_topping_groups_screen.dart';
import 'topping_edit_screen.dart';
import '../utils/money.dart';

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
      // Fresh list: saving a default can untick another option server-side.
      final data = await _apiService.fetchToppings(forceRefresh: true);
      if (mounted) {
        setState(() {
          _toppings = ToppingRules.ordered(
            data.map((json) => Topping.fromJson(json)).toList(),
          );
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

  void _openGroups() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageToppingGroupsScreen()),
    ).then((_) => _fetchToppings());
  }

  Future<void> _deleteTopping(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deleteTopping ?? 'Delete Topping'),
        content: Text(AppLocalizations.of(context)?.areYouSureYouWantTo4 ?? 'Are you sure you want to delete this topping?'),
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
      await _apiService.deleteTopping(id);
      _fetchToppings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.toppingDeleted ?? 'Topping deleted'), backgroundColor: Ld.warning),
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
    return Scaffold(
      appBar: LdHeader(
        title: l10n?.manageToppings ?? 'Manage Toppings',
        actions: [
          ItemsHeaderAction(
            label: l10n?.toppingGroups ?? 'Topping groups',
            icon: Icons.view_agenda_outlined,
            primary: false,
            onPressed: _openGroups,
          ),
          ItemsHeaderAction(
            label: l10n?.addTopping ?? 'Add Topping',
            icon: Icons.add_rounded,
            onPressed: () => _openToppingScreen(),
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
                  onAction: _fetchToppings,
                )
              : _toppings.isEmpty
                  ? ItemsStateView(
                      icon: Icons.eco_outlined,
                      title: l10n?.noToppingsYet ?? 'No toppings yet',
                      message: l10n?.addYourFirstToppingToGet ?? 'Add your first topping to get started',
                      actionLabel: l10n?.addTopping ?? 'Add Topping',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _openToppingScreen(),
                    )
                  : _buildGroups(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        tooltip: l10n?.addTopping ?? 'Add Topping',
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openToppingScreen(),
      ),
    );
  }

  /// One card per group (Type, Taste, Size, add-ons), laid out in as many
  /// columns as fit: 1 on phones, up to 4 on a landscape tablet.
  Widget _buildGroups(BuildContext context) {
    final gutter = itemsGutter(context);
    final sections = ToppingRules.sections(_toppings);
    return RefreshIndicator(
      onRefresh: _fetchToppings,
      child: LayoutBuilder(
        builder: (context, box) {
          final inner = box.maxWidth - gutter * 2;
          final columns = (inner / 340).floor().clamp(1, 4);
          const gap = 14.0;
          final cols = List.generate(columns, (_) => <Widget>[]);
          for (var i = 0; i < sections.length; i++) {
            cols[i % columns].add(Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: _ToppingGroupCard(
                section: sections[i],
                onEdit: (t) => _openToppingScreen(topping: t),
                onDelete: (t) => _deleteTopping(t.id),
              ),
            ));
          }
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 96 + Ld.navInset(context)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  Expanded(child: Column(children: cols[c])),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ToppingGroupCard extends StatelessWidget {
  final ToppingSection section;
  final ValueChanged<Topping> onEdit;
  final ValueChanged<Topping> onDelete;

  const _ToppingGroupCard({required this.section, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grouped = section.groupId != null;
    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            grouped ? section.title : (l10n?.toppingNoGroup ?? 'No group (add-on)'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Ld.title(19),
          ),
          if (grouped) ...[
            const SizedBox(height: 8),
            // Rule pills, e.g. "Pick 1" and "Required".
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                LdPill(section.single ? (l10n?.toppingPickOne ?? 'Pick 1') : (l10n?.toppingPickMany ?? 'Pick many')),
                if (section.required)
                  LdPill(l10n?.toppingRequired ?? 'Required', background: Ld.dangerWash, foreground: Ld.danger),
              ],
            ),
          ],
          const SizedBox(height: 10),
          for (final topping in section.options)
            _ToppingRow(
              topping: topping,
              onTap: () => onEdit(topping),
              onDelete: () => onDelete(topping),
            ),
        ],
      ),
    );
  }
}

class _ToppingRow extends StatelessWidget {
  final Topping topping;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ToppingRow({
    required this.topping,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lao = (topping.nameLo ?? '').trim();
    final hasLao = lao.isNotEmpty && lao != topping.name;
    final primary = topping.displayName;
    final secondary = hasLao ? (primary == topping.name ? lao : topping.name) : null;
    final paid = topping.extraPrice > 0;

    final priceText = Text(
      paid ? '+₭${money(topping.extraPrice)}' : (l10n?.free ?? 'Free'),
      maxLines: 1,
      style: paid
          ? Ld.price(15, weight: FontWeight.w600)
          : const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Ld.muted),
    );

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ld.lineSoft))),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ld.rSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: LayoutBuilder(
              builder: (context, box) {
                // Narrow card (phones): the price goes under the name so the
                // name keeps its width.
                final compact = box.maxWidth < 330;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Ld.ink),
                          ),
                          if (secondary != null)
                            Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
                          if (compact || (topping.isDefault && topping.groupId != null))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (compact) priceText,
                                  if (topping.isDefault && topping.groupId != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Ld.warning),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            l10n?.toppingDefaultBadge ?? 'Default',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12.5, fontWeight: FontWeight.w600, color: Ld.warning),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: FittedBox(fit: BoxFit.scaleDown, child: priceText),
                      ),
                    ],
                    const SizedBox(width: 8),
                    ItemsRowButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: l10n?.delete ?? 'Delete',
                      danger: true,
                      onPressed: onDelete,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
