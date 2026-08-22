import 'dart:async';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// A paginated, optimized customer selection bottom sheet with server-side search.
/// 
/// Key optimizations for large datasets (20,000+ customers):
/// - Server-side search with LIMIT 50 (never loads all customers)
/// - Debounced search (300ms) only triggers after 2+ characters
/// - Persistent TextEditingController and FocusNode
/// - Proper disposal of all controllers and focus nodes
/// - Stable keyboard handling without resize loops
/// - "More..." button for paginated results
class CustomerSelectionSheet extends StatefulWidget {
  final Future<CustomerSearchResult> Function(String query, int limit, int offset) onSearchCustomers;
  final Future<void> Function(String name, String phone) onCreateCustomer;
  final void Function(Map<String, dynamic> customer) onCustomerSelected;

  const CustomerSelectionSheet({
    super.key,
    required this.onSearchCustomers,
    required this.onCreateCustomer,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerSelectionSheet> createState() => _CustomerSelectionSheetState();
}

class _CustomerSelectionSheetState extends State<CustomerSelectionSheet> {
  // Persistent controllers - NEVER recreated in build()
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  
  // Debounce timer for search
  Timer? _debounceTimer;
  
  // Pagination state
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String _searchQuery = '';
  int _currentOffset = 0;
  
  // Prevent duplicate fetches
  bool _isFetching = false;
  
  // Search only starts after this many characters
  static const int _minSearchLength = 2;
  static const int _limit = 50;

  @override
  void initState() {
    super.initState();
    
    // Initialize persistent controllers
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    
    // Add listener for debounced search
    _searchController.addListener(_onSearchChanged);
    
    // Load initial recent customers (empty search = recent 50)
    _searchCustomers('');
    
    // Request focus after a short delay to avoid initial focus conflict
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();
    
    // Remove listener before disposing
    _searchController.removeListener(_onSearchChanged);
    
    // Dispose all controllers and focus nodes
    _searchController.dispose();
    _searchFocusNode.dispose();
    
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    final query = _searchController.text.trim();
    
    // Only search if query changed
    if (query == _searchQuery) return;
    
    // If query is shorter than minimum, show recent customers
    if (query.isNotEmpty && query.length < _minSearchLength) {
      return;
    }
    
    // Set new timer for 300ms debounce
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _searchCustomers(query);
    });
  }

  Future<void> _searchCustomers(String query) async {
    if (_isFetching) return;
    _isFetching = true;
    
    setState(() {
      _isLoading = true;
      _searchQuery = query;
      _currentOffset = 0;
    });
    
    try {
      final result = await widget.onSearchCustomers(query, _limit, 0);
      
      if (!mounted) return;
      
      setState(() {
        _customers = result.customers;
        _hasMore = result.hasMore;
        _currentOffset = result.customers.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[CustomerSearch] search failed: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.searchFailedPleaseTryAgain ?? (AppLocalizations.of(context)?.searchFailedPleaseTryAgain ?? 'Search failed. Please try again.')),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_isFetching || _isLoadingMore || !_hasMore) return;
    _isFetching = true;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final result = await widget.onSearchCustomers(_searchQuery, _limit, _currentOffset);
      
      if (!mounted) return;
      
      setState(() {
        _customers.addAll(result.customers);
        _hasMore = result.hasMore;
        _currentOffset += result.customers.length;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[CustomerSearch] loadMore failed: $e');
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.couldNotLoadMorePleaseTry ?? (AppLocalizations.of(context)?.couldNotLoadMorePleaseTry ?? 'Could not load more. Please try again.')),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _showCreateCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final nameFocusNode = FocusNode();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Request focus after dialog opens
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (nameFocusNode.canRequestFocus) {
            nameFocusNode.requestFocus();
          }
        });
        
        return AlertDialog(
          title: Text(AppLocalizations.of(context)?.newCustomer ?? (AppLocalizations.of(context)?.newCustomer ?? 'New Customer')),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                focusNode: nameFocusNode,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.name ?? (AppLocalizations.of(context)?.name ?? 'Name'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  // Move focus to phone field
                  FocusScope.of(ctx).nextFocus();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.phone ?? (AppLocalizations.of(context)?.phone ?? 'Phone'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppLocalizations.of(context)?.cancel ?? (AppLocalizations.of(context)?.cancel ?? 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001460),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)?.save ?? (AppLocalizations.of(context)?.save ?? 'Save')),
            ),
          ],
        );
      },
    );
    
    // Dispose controllers after dialog closes
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    nameController.dispose();
    phoneController.dispose();
    nameFocusNode.dispose();
    
    if (result == true && name.isNotEmpty) {
      try {
        await widget.onCreateCustomer(name, phone);
        if (!mounted) return;
        
        // Refresh customer list after creating
        await _searchCustomers('');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer "$name" created successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('[CustomerSheet] create customer failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.couldNotCreateCustomerPleaseTry ?? (AppLocalizations.of(context)?.couldNotCreateCustomerPleaseTry ?? 'Could not create customer. Please try again.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use FractionallySizedBox for stable height
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header with drag handle
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)?.selectCustomer ?? (AppLocalizations.of(context)?.selectCustomer ?? 'Select Customer'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _showCreateCustomerDialog,
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(AppLocalizations.of(context)?.newLabel ?? (AppLocalizations.of(context)?.newLabel ?? 'New')),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF001460),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)?.searchByNameOrPhone ?? (AppLocalizations.of(context)?.searchByNameOrPhone ?? 'Search by name or phone...'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            // _onSearchChanged will be called by the listener
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF001460), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                // Do NOT use autofocus - we handle focus manually in initState
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  // Dismiss keyboard on submit
                  _searchFocusNode.unfocus();
                },
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Customer list
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)?.loadingCustomers ?? (AppLocalizations.of(context)?.loadingCustomers ?? 'Loading customers...'),
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? (AppLocalizations.of(context)?.noCustomersFound ?? 'No customers found')
                  : 'No customers match "$_searchQuery"',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty || _searchQuery.length < _minSearchLength) ...[
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? 'Type at least $_minSearchLength characters to search'
                    : (AppLocalizations.of(context)?.addCustomerIfNotFound ?? 'Add customer if not found'),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateCustomerDialog,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)?.addCustomer2 ?? (AppLocalizations.of(context)?.addCustomer2 ?? 'Add Customer')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001460),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _customers.length + (_hasMore ? 1 : 0),
      separatorBuilder: (ctx, index) {
        // Don't show divider after last item if showing load more button
        if (index >= _customers.length - 1 && _hasMore) {
          return const SizedBox.shrink();
        }
        return const Divider(height: 1);
      },
      itemBuilder: (ctx, index) {
        // Show Load More button at the end
        if (index >= _customers.length) {
          return _buildLoadMoreButton();
        }
        
        final customer = _customers[index];
        final String name = customer['name']?.toString() ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown');
        final String phone = customer['phone']?.toString() ?? '';
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF001460).withOpacity(0.1),
            child: Icon(
              Icons.person,
              color: const Color(0xFF001460).withOpacity(0.8),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: phone.isNotEmpty
              ? Text(
                  phone,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                )
              : null,
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
          onTap: () {
            // Unfocus before selection to prevent keyboard issues
            _searchFocusNode.unfocus();
            widget.onCustomerSelected(customer);
          },
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: _loadMoreCustomers,
                icon: const Icon(Icons.expand_more, size: 18),
                label: const Text('More...'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF001460),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
      ),
    );
  }
}

/// Shows the customer selection bottom sheet with paginated server-side search.
/// Optimized for large customer databases (20,000+ customers).
///
/// Example usage:
/// ```dart
/// final result = await showCustomerSelectionSheet(
///   context: context,
///   onSearchCustomers: (query, limit, offset) => apiService.searchCustomersPaginated(
///     query: query,
///     limit: limit,
///     offset: offset,
///   ),
///   onCreateCustomer: (name, phone) => apiService.saveCustomer(name: name, phone: phone),
/// );
/// ```
Future<Map<String, dynamic>?> showCustomerSelectionSheet({
  required BuildContext context,
  required Future<CustomerSearchResult> Function(String query, int limit, int offset) onSearchCustomers,
  required Future<void> Function(String name, String phone) onCreateCustomer,
}) async {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Use these settings for stable keyboard behavior
    useSafeArea: true,
    enableDrag: true,
    builder: (ctx) {
      return CustomerSelectionSheet(
        onSearchCustomers: onSearchCustomers,
        onCreateCustomer: onCreateCustomer,
        onCustomerSelected: (customer) {
          Navigator.of(ctx).pop(customer);
        },
      );
    },
  );
}
