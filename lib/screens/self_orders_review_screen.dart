import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SelfOrdersReviewScreen extends StatefulWidget {
  const SelfOrdersReviewScreen({super.key});

  @override
  State<SelfOrdersReviewScreen> createState() => _SelfOrdersReviewScreenState();
}

class _SelfOrdersReviewScreenState extends State<SelfOrdersReviewScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.fetchPendingSelfOrders();
      if (!mounted) return;
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmOrder(Map<String, dynamic> order) async {
    final orderId = order['id'];
    if (orderId == null) return;
    try {
      await _apiService.confirmSelfOrderTransfer(orderId as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer confirmed. Order moved to Open Tickets.'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Confirm failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openProofDialog(Map<String, dynamic> order) {
    final proofUrl = (order['transfer_proof_url'] ?? '').toString();
    final title = 'Proof - ${order['name'] ?? ''}';
    final proofFuture = proofUrl.isEmpty
        ? Future.value(const <dynamic>['', <String, String>{}])
        : Future.wait<dynamic>([
            _apiService.resolveMediaUrlAsync(proofUrl),
            _apiService.buildImageHeaders(),
          ]);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: proofFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final absUrl = (snapshot.data![0] as String?) ?? '';
                  final headers =
                      (snapshot.data![1] as Map<String, String>?) ?? const {};
                  if (absUrl.isEmpty) return const Text('No proof image uploaded');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InteractiveViewer(
                        minScale: 1,
                        maxScale: 8,
                        child: GestureDetector(
                          onDoubleTap: () => _openProofFullScreen(
                            title: title,
                            imageUrl: absUrl,
                            headers: headers,
                          ),
                          child: Image.network(
                            absUrl,
                            headers: headers,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                const Text('Cannot load proof image'),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _openProofFullScreen(
                              title: title,
                              imageUrl: absUrl,
                              headers: headers,
                            );
                          },
                          icon: const Icon(Icons.zoom_out_map),
                          label: const Text('Fullscreen Zoom'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openProofFullScreen({
    required String title,
    required String imageUrl,
    required Map<String, String> headers,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          title: Text(title, style: const TextStyle(fontSize: 16)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 12,
            child: Image.network(
              imageUrl,
              headers: headers,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Cannot load proof image',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Orders Review'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _orders.isEmpty
                  ? const Center(child: Text('No self orders waiting transfer review'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final lines = (order['lines'] as List?) ?? [];
                        final paymentType = (order['payment_type'] ?? '').toString();
                        final hasTransferProof = order['transfer_proof_uploaded'] == true ||
                            ((order['transfer_proof_url'] ?? '').toString().isNotEmpty);
                        final isPayAtStore = paymentType == 'pay_at_store' ||
                            (paymentType != 'transfer' && !hasTransferProof);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order['name']?.toString() ?? 'Order',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text('Customer: ${order['customer'] ?? '-'}'),
                                Text('Table: ${order['table_name'] ?? '-'}'),
                                Text('Amount: ₭${(order['amount_total'] ?? 0).toString()}'),
                                Text('Items: ${lines.length}'),
                                if (isPayAtStore)
                                  const Text(
                                    'Payment: Pay at store (no proof needed)',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                isPayAtStore
                                    ? SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _confirmOrder(order),
                                          icon: const Icon(Icons.done_all),
                                          label: const Text('Quick Confirm (Pay at Store)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _openProofDialog(order),
                                              icon: const Icon(Icons.image_search),
                                              label: const Text('View Transfer Proof'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _confirmOrder(order),
                                              icon: const Icon(Icons.check_circle),
                                              label: const Text('Confirm'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E3A8A),
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

