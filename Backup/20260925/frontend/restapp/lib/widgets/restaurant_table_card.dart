import 'package:flutter/material.dart';

import '../models/pos/restaurant_table.dart';

class RestaurantTableCard extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;

  const RestaurantTableCard({
    super.key,
    required this.table,
    required this.onTap,
  });

  Color get statusColor {
    switch (table.status) {
      case 'OCCUPIED':
        return Colors.orange;

      case 'RESERVED':
        return Colors.blue;

      case 'BILL_REQUESTED':
        return Colors.purple;

      case 'CLEANING':
        return Colors.grey;

      case 'DISABLED':
        return Colors.black38;

      case 'AVAILABLE':
      default:
        return Colors.green;
    }
  }

  String get displayStatus {
    return table.status.replaceAll('_', ' ');
  }

  bool get hasOrders {
    return table.activeOrderCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: hasOrders ? 4 : 2,
      margin: const EdgeInsets.all(5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: table.status == 'DISABLED' ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 6)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. TABLE HEADER
              // ==========================================
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        table.tableName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Text(
                      table.tableCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 3),

              // ==========================================
              // 2. TABLE ICON
              // ==========================================
              SizedBox(
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.table_restaurant,
                    size: 38,
                    color: statusColor,
                  ),
                ),
              ),

              // ==========================================
              // 3. CAPACITY
              // ==========================================
              SizedBox(
                height: 20,
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${table.capacity} Pax',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 2),

              // ==========================================
              // 4. ORDER / GUEST INFORMATION
              //    ALWAYS RESERVE THIS SPACE
              // ==========================================
              SizedBox(
                height: 20,
                child: hasOrders
                    ? Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 15),
                          const SizedBox(width: 4),

                          Text(
                            '${table.activeOrderCount} Order'
                            '${table.activeOrderCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          Text(
                            '${table.activeGuestCount} Guests',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              // ==========================================
              // 5. AMOUNT
              //    ALSO RESERVE THIS SPACE
              // ==========================================
              SizedBox(
                height: 20,
                child: hasOrders
                    ? Text(
                        '₹${table.activeOrderAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 3),

              // ==========================================
              // 6. STATUS
              // ==========================================
              SizedBox(
                height: 22,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    displayStatus,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
