import 'package:flutter/material.dart';

import '../../models/inventory/inventory_purchase.dart';
import '../../services/inventory/inventory_purchase_service.dart';
import 'inventory_purchase_screen.dart';

class InventoryPurchaseListScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const InventoryPurchaseListScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<InventoryPurchaseListScreen> createState() =>
      _InventoryPurchaseListScreenState();
}

class _InventoryPurchaseListScreenState
    extends State<InventoryPurchaseListScreen> {
  late final InventoryPurchaseService _service;

  final TextEditingController _searchController = TextEditingController();

  List<InventoryPurchase> _purchases = [];

  bool _loading = true;
  bool _deleting = false;

  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();

    _service = InventoryPurchaseService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _loadPurchases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final purchases = await _service.getPurchases(
        outletId: widget.outletId,
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _purchases = purchases;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Unable to load purchases: $e');
    }
  }

  Future<void> _openNewPurchase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryPurchaseScreen(
          outletId: widget.outletId,
          baseUrl: widget.baseUrl,
          token: widget.token,
        ),
      ),
    );

    await _loadPurchases();
  }

  Future<void> _openPurchase(InventoryPurchase purchase) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryPurchaseScreen(
          outletId: widget.outletId,
          baseUrl: widget.baseUrl,
          token: widget.token,
          purchaseId: purchase.purchaseId,
        ),
      ),
    );

    await _loadPurchases();
  }

  Future<void> _deletePurchase(InventoryPurchase purchase) async {
    if (purchase.status.toUpperCase() != 'DRAFT') {
      _showMessage('Only DRAFT purchases can be deleted');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Purchase'),
          content: Text(
            'Delete purchase ${purchase.purchaseNo}?\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _deleting = true;
    });

    try {
      await _service.deletePurchase(
        purchaseId: purchase.purchaseId,
        outletId: widget.outletId,
      );

      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      _showMessage('Purchase deleted successfully');

      await _loadPurchases();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      _showMessage('Unable to delete purchase: $e');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _loadPurchases();
  }

  String _formatDate(String value) {
    if (value.length >= 10) {
      return value.substring(0, 10);
    }

    return value;
  }

  String _formatAmount(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  Widget _statusChip(String status) {
    final normalized = status.toUpperCase();

    Color backgroundColor;
    Color textColor;

    switch (normalized) {
      case 'POSTED':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;

      case 'CANCELLED':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;

      default:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            final searchField = TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Purchase No / Supplier / Supplier Invoice',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onSubmitted: (_) => _loadPurchases(),
              onChanged: (_) {
                setState(() {});
              },
            );

            final statusField = DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('All')),
                DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                DropdownMenuItem(value: 'POSTED', child: Text('Posted')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? '';
                });

                _loadPurchases();
              },
            );

            final searchButton = ElevatedButton.icon(
              onPressed: _loading ? null : _loadPurchases,
              icon: const Icon(Icons.search),
              label: const Text('SEARCH'),
            );

            if (compact) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  statusField,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: searchButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 8),
                Expanded(child: statusField),
                const SizedBox(width: 8),
                searchButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(InventoryPurchase purchase) {
    final isDraft = purchase.status.toUpperCase() == 'DRAFT';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    purchase.purchaseNo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(purchase.status),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              '${_formatDate(purchase.purchaseDate)}   •   '
              '${purchase.supplierCode} - ${purchase.supplierName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if ((purchase.supplierInvoiceNo ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Supplier Invoice: ${purchase.supplierInvoiceNo}'),
              ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text('Total\n${_formatAmount(purchase.grandTotal)}'),
                ),
                Expanded(
                  child: Text('Paid\n${_formatAmount(purchase.paidAmount)}'),
                ),
                Expanded(
                  child: Text(
                    'Balance\n${_formatAmount(purchase.balanceAmount)}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openPurchase(purchase),
                  icon: Icon(isDraft ? Icons.edit : Icons.visibility),
                  label: Text(isDraft ? 'EDIT' : 'VIEW'),
                ),

                if (isDraft)
                  TextButton.icon(
                    onPressed: _deleting
                        ? null
                        : () => _deletePurchase(purchase),
                    icon: const Icon(Icons.delete),
                    label: const Text('DELETE'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 22,
          headingRowHeight: 48,
          columns: const [
            DataColumn(label: Text('Purchase No')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Supplier Invoice')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Paid')),
            DataColumn(label: Text('Balance')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _purchases.map((purchase) {
            final isDraft = purchase.status.toUpperCase() == 'DRAFT';

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    purchase.purchaseNo,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(_formatDate(purchase.purchaseDate))),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      '${purchase.supplierCode} - '
                      '${purchase.supplierName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(purchase.supplierInvoiceNo ?? '')),
                DataCell(Text(_formatAmount(purchase.grandTotal))),
                DataCell(Text(_formatAmount(purchase.paidAmount))),
                DataCell(Text(_formatAmount(purchase.balanceAmount))),
                DataCell(_statusChip(purchase.status)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isDraft ? 'Edit' : 'View',
                        onPressed: () => _openPurchase(purchase),
                        icon: Icon(isDraft ? Icons.edit : Icons.visibility),
                      ),
                      if (isDraft)
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: _deleting
                              ? null
                              : () => _deletePurchase(purchase),
                          icon: const Icon(Icons.delete),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_purchases.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPurchases,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text('No purchases found', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPurchases,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [_buildDesktopTable()],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: _purchases.length,
            itemBuilder: (context, index) {
              return _buildPurchaseCard(_purchases[index]);
            },
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory • Purchases'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadPurchases,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPurchase,
        icon: const Icon(Icons.add),
        label: const Text('NEW PURCHASE'),
      ),

      body: Column(
        children: [
          _buildFilterBar(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
