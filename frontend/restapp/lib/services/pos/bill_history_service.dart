import '../../models/pos/bill_history.dart';
import '../api_client.dart';

class BillHistoryService {
  final ApiClient apiClient;

  BillHistoryService({required this.apiClient});

  Future<List<BillHistory>> getBillHistory({
    required int outletId,
    required String fromDate,
    required String toDate,
    String? billNo,
    String? orderNo,
    int? customerId,
    int? tableId,
    String? billStatus,
    String? paymentStatus,
  }) async {
    final queryParameters = <String, String>{
      'outletId': outletId.toString(),
      'fromDate': fromDate,
      'toDate': toDate,
    };

    if (billNo != null && billNo.trim().isNotEmpty) {
      queryParameters['billNo'] = billNo.trim();
    }

    if (orderNo != null && orderNo.trim().isNotEmpty) {
      queryParameters['orderNo'] = orderNo.trim();
    }

    if (customerId != null) {
      queryParameters['customerId'] = customerId.toString();
    }

    if (tableId != null) {
      queryParameters['tableId'] = tableId.toString();
    }

    if (billStatus != null &&
        billStatus.trim().isNotEmpty &&
        billStatus != 'ALL') {
      queryParameters['billStatus'] = billStatus;
    }

    if (paymentStatus != null &&
        paymentStatus.trim().isNotEmpty &&
        paymentStatus != 'ALL') {
      queryParameters['paymentStatus'] = paymentStatus;
    }

    final queryString = queryParameters.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    final response = await apiClient.get('/bills/history?$queryString');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to load bill history');
    }

    final List<dynamic> data = response['bills'] as List? ?? [];

    return data
        .map((e) => BillHistory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
