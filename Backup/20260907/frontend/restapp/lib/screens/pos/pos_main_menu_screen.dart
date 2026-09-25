import 'package:flutter/material.dart';
import 'package:restapp/screens/pos/restaurant_table_screen.dart';
import 'package:restapp/services/api_client.dart';

import 'pending_bills_screen.dart';
import 'pos_order_screen.dart';

class PosMainMenuScreen extends StatelessWidget {
  final int outletId;
  final ApiClient apiClient;
  const PosMainMenuScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  void _openPendingBills(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingBillsScreen(
          outletId: outletId,
          baseUrl: apiClient.baseUrl,
          token: apiClient.token ?? "",
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant POS')),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),

                    const SizedBox(height: 20),

                    _buildMenuGrid(context, isDesktop),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(Icons.restaurant, size: 30),
            ),

            const SizedBox(width: 15),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restaurant POS',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Order • KOT • Billing • Payment',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: () {
                _showMessage(
                  context,
                  'Refresh functionality will be added later',
                );
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context, bool isDesktop) {
    final crossAxisCount = isDesktop ? 4 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.35 : 1.15,
      children: [
        _menuCard(
          context,
          icon: Icons.table_restaurant,
          title: 'TABLES',
          subtitle: 'Manage restaurant tables',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RestaurantTableScreen(
                  outletId: outletId,
                  apiClient: apiClient,
                ),
              ),
            );
          },
        ),

        _menuCard(
          context,
          icon: Icons.receipt_long,
          title: 'PENDING BILLS',
          subtitle: 'Receive payment for bills',
          onTap: () {
            _openPendingBills(context);
          },
        ),

        _menuCard(
          context,
          icon: Icons.restaurant_menu,
          title: 'NEW ORDER',
          subtitle: 'Create a new order',
          onTap: () {
            _showMessage(
              context,
              'New order should normally be started from Tables',
            );
          },
        ),

        _menuCard(
          context,
          icon: Icons.kitchen,
          title: 'KOT',
          subtitle: 'Kitchen order tickets',
          onTap: () {
            _showMessage(context, 'KOT screen will be connected later');
          },
        ),

        _menuCard(
          context,
          icon: Icons.receipt,
          title: 'BILLS',
          subtitle: 'View generated bills',
          onTap: () {
            _showMessage(context, 'Bill history will be connected later');
          },
        ),

        _menuCard(
          context,
          icon: Icons.people,
          title: 'CUSTOMERS',
          subtitle: 'Customer management',
          onTap: () {
            _showMessage(context, 'Customer screen will be connected later');
          },
        ),

        _menuCard(
          context,
          icon: Icons.bar_chart,
          title: 'REPORTS',
          subtitle: 'Sales and business reports',
          onTap: () {
            _showMessage(context, 'Reports will be connected later');
          },
        ),

        _menuCard(
          context,
          icon: Icons.settings,
          title: 'SETTINGS',
          subtitle: 'POS configuration',
          onTap: () {
            _showMessage(context, 'Settings will be connected later');
          },
        ),
      ],
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),

              const SizedBox(height: 12),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
