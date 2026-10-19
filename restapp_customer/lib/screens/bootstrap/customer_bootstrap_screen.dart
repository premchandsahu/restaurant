import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:restapp_customer/screens/customer/customer_menu_screen.dart';
import 'package:restapp_customer/screens/customer/customer_order_status_screen.dart';
import 'package:restapp_customer/services/customer/customer_order_service.dart';

class CustomerBootstrapScreen extends StatefulWidget {
  const CustomerBootstrapScreen({super.key});

  @override
  State<CustomerBootstrapScreen> createState() =>
      _CustomerBootstrapScreenState();
}

class _CustomerBootstrapScreenState extends State<CustomerBootstrapScreen> {
  final AppLinks _appLinks = AppLinks();
  late final CustomerOrderService _service;
  bool _isProcessingQr = false;

  // Use the same API base URL used by your restaurant POS backend.
  //static const String _baseUrl = 'http://api.jaihindplaster.com:5000';
  static const String _baseUrl = 'http://api.jaihindplaster.com:5000';

  StreamSubscription<Uri>? _linkSubscription;
  String? _errorMessage;
  String? _qrToken;
  String? _incomingUrl;
  String _status = 'Scanning table QR...';
  String? _error;
  @override
  void initState() {
    super.initState();
    _service = CustomerOrderService(baseUrl: _baseUrl, token: '');
    _initializeDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();

    super.dispose();
  }

  String? _extractQrToken(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return null;
    }

    // Expected customer URL:
    //
    // https://your-domain.com/customer/<qrToken>
    //
    // Therefore the token is the final path segment.

    return segments.last.trim().isEmpty ? null : segments.last.trim();
  }
  /*
  void _handleIncomingUri(Uri uri) {
    debugPrint('CUSTOMER APP DEEP LINK: $uri');

    if (!mounted) {
      return;
    }

    setState(() {
      _incomingUrl = uri.toString();
      _qrToken = _extractQrToken(uri);
    });

    if (_qrToken != null) {
      debugPrint('CUSTOMER QR TOKEN: $_qrToken');

      // --------------------------------------------------
      // Next step:
      // Call:
      //
      // GET /customer-order/qr/<qrToken>
      //
      // and then create customer session.
      // --------------------------------------------------
    }
  }
*/

  Future<void> _handleIncomingUri(Uri uri) async {
    debugPrint('CUSTOMER APP DEEP LINK: $uri');

    if (!mounted) {
      return;
    }

    final token = _extractQrToken(uri);

    setState(() {
      _incomingUrl = uri.toString();
      _qrToken = token;
    });

    if (token == null || token.isEmpty) {
      debugPrint('CUSTOMER QR TOKEN NOT FOUND');
      return;
    }

    debugPrint('CUSTOMER QR TOKEN: $token');

    await _processQrToken(token);
  }
  /*
  Future<void> _processQrToken(String qrToken) async {
    try {
      if (!mounted) {
        return;
      }

      setState(() {});

      // ------------------------------------------------------
      // 1. Validate table token
      // ------------------------------------------------------

      final tableData = await _service.getTableByToken(tableToken: qrToken);

      if (!mounted) {
        return;
      }

      debugPrint('CUSTOMER TABLE RESPONSE: $tableData');

      final sessionData = tableData['session'];

      if (sessionData is! Map<String, dynamic>) {
        throw Exception('Invalid table session response');
      }

      final tableSessionToken = sessionData['session_token']?.toString();

      if (tableSessionToken == null || tableSessionToken.trim().isEmpty) {
        throw Exception('Table session token not received');
      }

      // ------------------------------------------------------
      // 2. Create customer session
      // ------------------------------------------------------

      final customerData = await _service.createCustomerSession(
        tableSessionToken: tableSessionToken,
      );

      if (!mounted) {
        return;
      }

      debugPrint('CUSTOMER SESSION RESPONSE: $customerData');

      final customerSession = customerData['customer_session'];

      if (customerSession is! Map<String, dynamic>) {
        throw Exception('Invalid customer session response');
      }

      final customerSessionToken = customerSession['session_token']?.toString();

      if (customerSessionToken == null || customerSessionToken.trim().isEmpty) {
        throw Exception('Customer session token not received');
      }

      // ------------------------------------------------------
      // 3. Open customer menu
      // ------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerMenuScreen(
            customerSessionToken: customerSessionToken,
            baseUrl: _baseUrl,
          ),
        ),
      );
    } catch (e) {
      debugPrint('CUSTOMER BOOTSTRAP ERROR: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
*/
  /*
  Future<void> _processQrToken(String tableUuid) async {
    if (tableUuid.trim().isEmpty) {
      return;
    }

    final service = CustomerOrderService(baseUrl: _baseUrl, token: '');

    if (!mounted) return;

    setState(() {
      _status = 'Starting table session...';
    });

    try {
      // ----------------------------------------------------------
      // 1. TABLE UUID -> TABLE SESSION TOKEN
      // ----------------------------------------------------------

      final tableSessionToken = await service.startTableSession(
        tableUuid: tableUuid,
      );

      if (!mounted) return;

      setState(() {
        _status = 'Validating table...';
      });

      // ----------------------------------------------------------
      // 2. Validate newly-created/reused table session
      // ----------------------------------------------------------

      final tableData = await service.getTableByToken(
        tableToken: tableSessionToken,
      );

      final sessionRaw = tableData['session'];

      if (sessionRaw is! Map) {
        throw Exception('Invalid table session response');
      }

      final tableSessionTokenFromResponse =
          sessionRaw['session_token']?.toString() ?? '';

      if (tableSessionTokenFromResponse.isEmpty) {
        throw Exception('Table session token missing');
      }

      // ----------------------------------------------------------
      // 3. Create CUSTOMER SESSION
      // ----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _status = 'Starting customer session...';
      });

      final customerSessionData = await service.createCustomerSession(
        customerName: null,
        customerPhone: null,
        tableSessionToken: tableSessionTokenFromResponse,
      );

      final customerSessionRaw = customerSessionData['customer_session'];

      if (customerSessionRaw is! Map) {
        throw Exception('Customer session was not created');
      }

      final customerSessionToken =
          customerSessionRaw['session_token']?.toString() ?? '';

      if (customerSessionToken.isEmpty) {
        throw Exception('Customer session token missing');
      }

      // ----------------------------------------------------------
      // 4. Continue existing flow
      // ----------------------------------------------------------

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerMenuScreen(
            customerSessionToken: customerSessionToken,
            baseUrl: _baseUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Unable to open table';
        _error = e.toString();
      });
    }
  }


*/

  Future<void> _processQrToken(String tableUuid) async {
    if (tableUuid.trim().isEmpty) {
      debugPrint('CUSTOMER BOOTSTRAP: tableUuid is empty');
      return;
    }

    debugPrint('==============================================');
    debugPrint('CUSTOMER BOOTSTRAP: START');
    debugPrint('CUSTOMER BOOTSTRAP: tableUuid = $tableUuid');
    debugPrint('CUSTOMER BOOTSTRAP: baseUrl = $_baseUrl');
    debugPrint('==============================================');

    if (_isProcessingQr) {
      debugPrint(
        'CUSTOMER BOOTSTRAP: Already processing QR - ignoring duplicate',
      );
      return;
    }

    _isProcessingQr = true;

    final service = CustomerOrderService(baseUrl: _baseUrl, token: '');

    if (!mounted) return;

    setState(() {
      _status = 'Starting table session...';
      _error = null;
    });

    try {
      // ----------------------------------------------------------
      // 1. TABLE UUID -> TABLE SESSION TOKEN
      // ----------------------------------------------------------

      debugPrint('STEP 1: Calling startTableSession()');
      debugPrint('STEP 1: tableUuid = $tableUuid');

      final tableSessionToken = await service.startTableSession(
        tableUuid: tableUuid,
      );

      debugPrint('STEP 1: startTableSession() SUCCESS');
      debugPrint(
        'STEP 1: tableSessionToken = '
        '${tableSessionToken.length > 10 ? '${tableSessionToken.substring(0, 10)}...' : tableSessionToken}',
      );

      if (!mounted) return;

      setState(() {
        _status = 'Validating table...';
      });

      // ----------------------------------------------------------
      // 2. Validate newly-created/reused table session
      // ----------------------------------------------------------

      debugPrint('STEP 2: Calling getTableByToken()');

      final tableData = await service.getTableByToken(
        tableToken: tableSessionToken,
      );

      debugPrint('STEP 2: getTableByToken() SUCCESS');
      debugPrint('STEP 2: tableData = $tableData');

      final sessionRaw = tableData['session'];

      debugPrint('STEP 2: session object type = ${sessionRaw.runtimeType}');

      if (sessionRaw is! Map) {
        debugPrint('STEP 2 ERROR: Invalid table session response');
        throw Exception('Invalid table session response');
      }

      final tableSessionTokenFromResponse =
          sessionRaw['session_token']?.toString() ?? '';

      debugPrint('STEP 2: session_token received');
      debugPrint(
        'STEP 2: token = '
        '${tableSessionTokenFromResponse.length > 10 ? '${tableSessionTokenFromResponse.substring(0, 10)}...' : tableSessionTokenFromResponse}',
      );

      if (tableSessionTokenFromResponse.isEmpty) {
        debugPrint('STEP 2 ERROR: Table session token missing');
        throw Exception('Table session token missing');
      }

      // ----------------------------------------------------------
      // 3. Create CUSTOMER SESSION
      // ----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _status = 'Starting customer session...';
      });

      debugPrint('STEP 3: Calling createCustomerSession()');
      debugPrint('STEP 3: customerName = null');
      debugPrint('STEP 3: customerPhone = null');

      final customerSessionData = await service.createCustomerSession(
        customerName: null,
        customerPhone: null,
        tableSessionToken: tableSessionTokenFromResponse,
      );

      debugPrint('STEP 3: createCustomerSession() SUCCESS');
      debugPrint('STEP 3: customerSessionData = $customerSessionData');

      final customerSessionRaw = customerSessionData['customer_session'];

      debugPrint(
        'STEP 3: customer_session object type = '
        '${customerSessionRaw.runtimeType}',
      );

      if (customerSessionRaw is! Map) {
        debugPrint('STEP 3 ERROR: Customer session was not created');
        throw Exception('Customer session was not created');
      }

      final customerSessionToken =
          customerSessionRaw['session_token']?.toString() ?? '';

      debugPrint('STEP 3: customer session token received');
      debugPrint(
        'STEP 3: token = '
        '${customerSessionToken.length > 10 ? '${customerSessionToken.substring(0, 10)}...' : customerSessionToken}',
      );

      if (customerSessionToken.isEmpty) {
        debugPrint('STEP 3 ERROR: Customer session token missing');
        throw Exception('Customer session token missing');
      }

      // ----------------------------------------------------------
      // 4. Continue existing flow
      // ----------------------------------------------------------

      debugPrint('STEP 4: Navigating to CustomerDashboardcreen');
      debugPrint('STEP 4: customerSessionToken received = YES');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerOrderStatusScreen(
            customerSessionToken: customerSessionToken,
            baseUrl: _baseUrl,
          ),
        ),
      );

      debugPrint('STEP 4: Navigation completed');
      debugPrint('CUSTOMER BOOTSTRAP: SUCCESS');
      debugPrint('==============================================');
    } catch (e, stackTrace) {
      debugPrint('==============================================');
      debugPrint('CUSTOMER BOOTSTRAP: ERROR');
      debugPrint('ERROR TYPE: ${e.runtimeType}');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE:');
      debugPrint('$stackTrace');
      debugPrint('==============================================');

      if (!mounted) return;

      setState(() {
        _status = 'Unable to open table';
        _error = e.toString();
      });
    } finally {
      _isProcessingQr = false;
    }
  }

  Future<void> _initializeDeepLinks() async {
    try {
      // --------------------------------------------------
      // Listen for links while application is running.
      // --------------------------------------------------
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleIncomingUri(uri);
        },
        onError: (error) {
          debugPrint('Customer deep-link error: $error');
        },
      );

      // --------------------------------------------------
      // Get the link that launched the application.
      // --------------------------------------------------
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        _handleIncomingUri(initialUri);
        return;
      }

      // --------------------------------------------------
      // No QR/deep-link information.
      //
      // This can happen when the customer opens the
      // application manually.
      // --------------------------------------------------
      await _initialize();
    } catch (e) {
      debugPrint('Customer deep-link initialization error: $e');

      await _initialize();
    }
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Container(
                  width: 90,
                  height: 90,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepOrange.withOpacity(0.10),
                  ),

                  child: const Icon(
                    Icons.restaurant,
                    size: 48,
                    color: Colors.deepOrange,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Restaurant',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Digital Ordering',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 28),

                const CircularProgressIndicator(),

                const SizedBox(height: 18),

                if (_errorMessage != null) ...[
                  const Icon(Icons.error_outline, size: 36, color: Colors.red),

                  const SizedBox(height: 10),

                  const Text(
                    'Unable to open table',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () {
                      if (_qrToken != null) {
                        setState(() {
                          _errorMessage = null;
                        });

                        _processQrToken(_qrToken!);
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('TRY AGAIN'),
                  ),
                ] else if (_qrToken != null) ...[
                  const Text(
                    'QR detected',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Table token: $_qrToken',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Opening your menu...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ] else ...[
                  const Text(
                    'Preparing your table...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
