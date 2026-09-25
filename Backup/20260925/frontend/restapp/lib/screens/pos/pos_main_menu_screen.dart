import 'package:flutter/material.dart';

import 'package:restapp/models/auth/app_menu.dart';
import 'package:restapp/screens/hotel/hotel_housekeeping_history_screen.dart';
import 'package:restapp/screens/hotel/hotel_housekeeping_screen.dart';
import 'package:restapp/screens/hotel/hotel_inhouse_screen.dart';
import 'package:restapp/screens/inventory/inventory_purchase_list_screen.dart';
import 'package:restapp/screens/inventory/inventory_purchase_screen.dart';
import 'package:restapp/screens/inventory/inventory_raw_material_screen.dart';
import 'package:restapp/screens/inventory/inventory_recipe_screen.dart';
import 'package:restapp/screens/inventory/inventory_stock_adjustment_list_screen.dart';
import 'package:restapp/screens/inventory/inventory_stock_balance_screen.dart';
import 'package:restapp/screens/inventory/inventory_stock_ledger_screen.dart';
import 'package:restapp/screens/inventory/inventory_supplier_ledger_screen.dart';
import 'package:restapp/screens/inventory/inventory_supplier_payment_list_screen.dart';
import 'package:restapp/screens/pos/customer_menu_screen.dart';
import 'package:restapp/screens/pos/customer_order_status_screen.dart';
import 'package:restapp/screens/hotel/hotel_folio_screen.dart';
import 'package:restapp/screens/pos/kitchen_display_screen.dart';
import 'package:restapp/screens/pos/pos_bill_history_screen.dart';
import 'package:restapp/screens/pos/restaurant_table_screen.dart';
import 'package:restapp/services/api_client.dart';
import 'package:restapp/screens/hotel/hotel_reservation_screen.dart';
import 'pending_bills_screen.dart';
import 'pos_order_screen.dart';

class PosMainMenuScreen extends StatelessWidget {
  final int outletId;
  final ApiClient apiClient;

  // Database driven application menus.
  final List<AppMenu> menus;

  // Permissions returned during login.
  final List<String> permissions;

  const PosMainMenuScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
    required this.menus,
    required this.permissions,
  });

  // ------------------------------------------------------------
  // PERMISSION CHECK
  // ------------------------------------------------------------

  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  // ------------------------------------------------------------
  // PENDING BILLS
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // HOTEL FOLIO
  // ------------------------------------------------------------

  void _openHotelFolio(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelFolioScreen(
          // Temporary test stay.
          // We will replace this with stay selection
          // when the Hotel In-House/Folio screen is created.
          stayId: 2,
          baseUrl: apiClient.baseUrl,
          token: apiClient.token ?? "",
        ),
      ),
    );
  }

  void _openHouseKeeping(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelHousekeepingScreen(
          // Temporary test stay.
          // We will replace this with stay selection
          // when the Hotel In-House/Folio screen is created.
          outletId: outletId,
          baseUrl: apiClient.baseUrl,
          token: apiClient.token ?? "",
        ),
      ),
    );
  }

  void _openHouseKeepingHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelHousekeepingHistoryScreen(
          // Temporary test stay.
          // We will replace this with stay selection
          // when the Hotel In-House/Folio screen is created.
          outletId: outletId,
          baseUrl: apiClient.baseUrl,
          token: apiClient.token ?? "",
        ),
      ),
    );
  }

  void _openInventoryRecipe(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryRecipeScreen(
          outletId: outletId,
          baseUrl: apiClient.baseUrl,
          token: apiClient.token ?? '',
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

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

  Widget _buildAppMenuCard(BuildContext context, AppMenu menu) {
    return _menuCard(
      context,
      icon: _getMenuIcon(menu.iconName),
      title: menu.menuName.toUpperCase(),
      subtitle: menu.moduleName,
      onTap: () {
        _openAppMenu(context, menu);
      },
    );
  }

  void _openAppMenu(BuildContext context, AppMenu menu) {
    switch (menu.menuCode) {
      case 'RESTAURANT_TABLES':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RestaurantTableScreen(outletId: outletId, apiClient: apiClient),
          ),
        );
        break;
      case 'HOTEL_RESERVATIONS':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HotelReservationScreen(
              outletId: outletId,
              apiClient: apiClient,
            ),
          ),
        );
        break;
      case 'INVENTORY_PURCHASES':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryPurchaseListScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;

      case 'INVENTORY_RAW_MATERIALS':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryRawMaterialScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;

      case 'HOTEL_INHOUSE':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HotelInhouseScreen(outletId: outletId, apiClient: apiClient),
          ),
        );
        break;
      case 'RESTAURANT_BILLS':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PosBillHistoryScreen(outletId: outletId, apiClient: apiClient),
          ),
        );
        break;
      case 'RESTAURANT_NEW_ORDER':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RestaurantTableScreen(outletId: outletId, apiClient: apiClient),
          ),
        );
        break;
      case 'INVENTORY_SUPPLIER_PAYMENTS':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventorySupplierPaymentListScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;
      case 'INVENTORY_STOCK_REGISTER':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryStockBalanceScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;
      case 'INVENTORY_STOCK_LEDGER':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryStockLedgerScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;

      case 'INVENTORY_STOCK_ADJUSTMENTS':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryStockAdjustmentListScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;
      case 'INVENTORY_SUPPLIER_LEDGER':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventorySupplierLedgerScreen(
              outletId: outletId,
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;
      case 'RESTAURANT_OPEN_ORDERS':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RestaurantTableScreen(outletId: outletId, apiClient: apiClient),
          ),
        );
        break;

      case 'RESTAURANT_PENDING_BILLS':
        _openPendingBills(context);
        break;
      case 'INVENTORY_RECIPE_COVERAGE':
        _openInventoryRecipe(context);
        break;

      case 'HOTEL_FOLIOS':
        _openHotelFolio(context);
        break;
      case 'HOUSEKEEPING_ROOMS':
        _openHouseKeeping(context);
        break;
      case 'HOUSEKEEPING_CLEANING':
        _openHouseKeepingHistory(context);
        break;
      case 'RESTAURANT_KDS':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KitchenDisplayScreen(
              baseUrl: apiClient.baseUrl,
              token: apiClient.token ?? '',
            ),
          ),
        );
        break;

      default:
        _showMessage(
          context,
          '${menu.menuName} screen will be connected later',
        );
    }
  }

  IconData _getMenuIcon(String? iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;

      case 'table_restaurant':
        return Icons.table_restaurant;

      case 'receipt':
        return Icons.receipt;

      case 'receipt_long':
        return Icons.receipt_long;

      case 'kitchen':
        return Icons.kitchen;

      case 'hotel':
        return Icons.hotel;

      case 'people':
        return Icons.people;

      case 'bar_chart':
        return Icons.bar_chart;

      case 'settings':
        return Icons.settings;

      case 'person':
        return Icons.person;

      case 'calendar':
        return Icons.calendar_month;

      case 'bed':
        return Icons.bed;

      case 'login':
        return Icons.login;

      case 'logout':
        return Icons.logout;

      case 'cleaning_services':
        return Icons.cleaning_services;

      case 'payments':
        return Icons.payments;

      default:
        return Icons.apps;
    }
  }

  // ------------------------------------------------------------
  // MENU GRID
  // ------------------------------------------------------------

  Widget _buildMenuGrid(BuildContext context, bool isDesktop) {
    final crossAxisCount = isDesktop ? 4 : 2;

    // Only display actual menu items.
    // Group menus such as RESTAURANT, HOTEL, REPORTS are
    // used as sections and are not displayed as cards.
    final List<AppMenu> menuItems = [];

    for (final group in menus) {
      if (!group.isGroup) {
        menuItems.add(group);
        continue;
      }

      for (final child in group.children) {
        menuItems.add(child);
      }
    }

    // Safety check:
    // App-menu API already filters menus by permission,
    // but we also check the permission here.
    final visibleMenus = menuItems.where((menu) {
      if (menu.requiredPermission == null || menu.requiredPermission!.isEmpty) {
        return true;
      }

      return hasPermission(menu.requiredPermission!);
    }).toList();

    if (visibleMenus.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.lock_outline, size: 50),

                const SizedBox(height: 12),

                const Text(
                  'No menu options available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(
                  'Your user account does not have '
                  'any assigned permissions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.35 : 1.15,

      children: visibleMenus.map((menu) {
        return _buildAppMenuCard(context, menu);
      }).toList(),
    );
  }
  // ------------------------------------------------------------
  // MENU CARD
  // ------------------------------------------------------------

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
