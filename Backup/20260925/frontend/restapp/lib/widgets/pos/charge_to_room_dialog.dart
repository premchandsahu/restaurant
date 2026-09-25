import 'package:flutter/material.dart';

import '../../models/pos/active_hotel_stay.dart';

class ChargeToRoomDialog extends StatefulWidget {
  final List<ActiveHotelStay> stays;

  const ChargeToRoomDialog({super.key, required this.stays});

  @override
  State<ChargeToRoomDialog> createState() => _ChargeToRoomDialogState();
}

class _ChargeToRoomDialogState extends State<ChargeToRoomDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<ActiveHotelStay> _filteredStays = [];

  @override
  void initState() {
    super.initState();

    _filteredStays = List.from(widget.stays);

    _searchController.addListener(_filterStays);
  }

  void _filterStays() {
    final search = _searchController.text.trim().toLowerCase();

    setState(() {
      if (search.isEmpty) {
        _filteredStays = List.from(widget.stays);
      } else {
        _filteredStays = widget.stays.where((stay) {
          final guest = stay.guest.displayName.toLowerCase();

          final room = stay.room.roomNo?.toLowerCase() ?? '';

          final stayNo = stay.stayNo.toLowerCase();

          final phone = stay.guest.phone?.toLowerCase() ?? '';

          return guest.contains(search) ||
              room.contains(search) ||
              stayNo.contains(search) ||
              phone.contains(search);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Charge to Room'),

      content: SizedBox(
        width: 550,
        height: 450,
        child: Column(
          children: [
            TextField(
              controller: _searchController,

              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search guest, room or stay',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _filteredStays.isEmpty
                  ? const Center(child: Text('No active hotel stays found'))
                  : ListView.builder(
                      itemCount: _filteredStays.length,

                      itemBuilder: (context, index) {
                        final stay = _filteredStays[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.meeting_room),
                            ),

                            title: Text(
                              'Room ${stay.room.roomNo ?? '-'}'
                              ' - ${stay.guest.displayName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            subtitle: Text(
                              '${stay.stayNo}'
                              ' • ${stay.room.roomTypeName ?? ''}'
                              '\n'
                              '${stay.guest.phone ?? ''}',
                            ),

                            isThreeLine: true,

                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),

                            onTap: () {
                              Navigator.pop(context, stay);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}
