import 'package:flutter/material.dart';

import '../services/captain_auth_service.dart';
import 'captain_table_screen.dart';

class CaptainHomeScreen extends StatelessWidget {
  final CaptainAuthResult authResult;
  final CaptainOutlet outlet;
  final String baseUrl;

  const CaptainHomeScreen({
    super.key,
    required this.authResult,
    required this.outlet,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return CaptainTableScreen(
      baseUrl: baseUrl,
      token: authResult.token,
      outlet: outlet,
      outletId: outlet.outletId,
    );
  }
}
