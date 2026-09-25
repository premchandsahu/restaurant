import 'package:flutter/material.dart';
import 'package:restapp/screens/pos/pos_main_menu_screen.dart';
import 'package:restapp/services/app_menu_service.dart';

import '../../models/auth/login_response.dart';
import '../../services/api_client.dart';
import '../pos/restaurant_table_screen.dart';

class DashboardScreen extends StatefulWidget {
  final LoginResponse loginResponse;
  final ApiClient apiClient;

  const DashboardScreen({
    super.key,
    required this.loginResponse,
    required this.apiClient,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = false;

  Future<void> _openOutlet(BuildContext context, int outletId) async {
    setState(() {
      loading = true;
    });

    try {
      final menuService = AppMenuService(apiClient: widget.apiClient);

      final menus = await menuService.getMyMenus();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PosMainMenuScreen(
            outletId: outletId,
            apiClient: widget.apiClient,
            menus: menus,
            permissions: widget.loginResponse.permissions,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load application menu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlets = widget.loginResponse.outlets;

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant POS')),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Welcome, ${widget.loginResponse.user.displayName}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(widget.loginResponse.user.roleName),

            const SizedBox(height: 30),

            const Text(
              'Select Outlet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                itemCount: outlets.length,

                itemBuilder: (context, index) {
                  final outlet = outlets[index];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.store),

                      title: Text(outlet.outletName),

                      subtitle: Text(outlet.outletCode),

                      trailing: outlet.isDefault
                          ? const Chip(label: Text('Default'))
                          : null,

                      onTap: loading
                          ? null
                          : () {
                              _openOutlet(context, outlet.outletId);
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
