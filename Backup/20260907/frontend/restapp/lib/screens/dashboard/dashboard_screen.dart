import 'package:flutter/material.dart';
import 'package:restapp/screens/pos/pos_main_menu_screen.dart';

import '../../models/auth/login_response.dart';
import '../../services/api_client.dart';
import '../pos/restaurant_table_screen.dart';

class DashboardScreen extends StatelessWidget {
  final LoginResponse loginResponse;
  final ApiClient apiClient;

  const DashboardScreen({
    super.key,
    required this.loginResponse,
    required this.apiClient,
  });

  @override
  Widget build(BuildContext context) {
    final outlets = loginResponse.outlets;

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant POS')),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Welcome, '
              '${loginResponse.user.displayName}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(loginResponse.user.roleName),

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

                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PosMainMenuScreen(
                              outletId: outlet.outletId,
                              apiClient: apiClient,
                            ),
                          ),
                        );
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
