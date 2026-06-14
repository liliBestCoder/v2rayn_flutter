import 'package:flutter/material.dart';

import '../app_state.dart';

class TradeManagerPage extends StatefulWidget {
  const TradeManagerPage({super.key});

  @override
  State<TradeManagerPage> createState() => _TradeManagerPageState();
}

class _TradeManagerPageState extends State<TradeManagerPage> {
  late Future<List<_TradeRecord>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _loadRecords();
  }

  Future<List<_TradeRecord>> _loadRecords() async {
    final app = AppScope.of(context);
    final token = app.token;
    if (token == null || token.isEmpty) {
      return const [];
    }
    final result = await app.api.paymentOrders(token);
    if (!result.success) {
      throw result.msg.isNotEmpty ? result.msg : '加载交易记录失败';
    }
    final data = result.data;
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) => _TradeRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  void _reload() {
    setState(() {
      _future = _loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: FutureBuilder<List<_TradeRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError) {
            return _StateView(
              text: snapshot.error.toString(),
              actionText: '重试',
              onAction: _reload,
            );
          }

          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return _StateView(
              text: '暂无交易记录',
              actionText: '刷新',
              onAction: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 32, 28),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xffeeeeee),
              ),
              itemBuilder: (context, index) =>
                  _TradeRecordTile(record: records[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TradeRecord {
  const _TradeRecord({
    required this.type,
    required this.title,
    required this.createdAt,
    required this.orderNo,
    required this.paidAt,
    required this.amount,
    required this.status,
    required this.statusColor,
  });

  factory _TradeRecord.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    final paidAmount = json['paidAmount']?.toString();
    final amount = json['amount']?.toString() ?? '0.00';
    final currency = json['paidCurrency']?.toString().isNotEmpty == true
        ? json['paidCurrency'].toString()
        : (json['currency']?.toString() ?? 'USD');
    return _TradeRecord(
      type: _paymentTypeLabel(json['type']?.toString()),
      title: json['packetName']?.toString() ?? '-',
      createdAt: _dateOnly(json['createdAt']?.toString()),
      orderNo: json['orderNo']?.toString() ?? '-',
      paidAt: _dateTime(json['paidAt']?.toString()),
      amount: '${_currencySymbol(currency)} ${paidAmount ?? amount}',
      status: _statusLabel(status),
      statusColor: _statusColor(status),
    );
  }

  final String type;
  final String title;
  final String createdAt;
  final String orderNo;
  final String paidAt;
  final String amount;
  final String status;
  final Color statusColor;

  static String _paymentTypeLabel(String? type) {
    if ((type ?? '').toLowerCase() == 'alipay') {
      return '支付宝';
    }
    return '订单';
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return '已支付';
      case 'PENDING':
        return '待支付';
      case 'CLOSED':
        return '已关闭';
      case 'FAILED':
        return '失败';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xffff9f2d);
      case 'PENDING':
        return const Color(0xff2b77ff);
      case 'CLOSED':
        return const Color(0xff999999);
      case 'FAILED':
        return const Color(0xffd93025);
      default:
        return const Color(0xff666666);
    }
  }

  static String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return r'US$';
      case 'CNY':
        return '¥';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'KRW':
        return '₩';
      case 'SGD':
        return r'S$';
      case 'HKD':
        return r'HK$';
      case 'TWD':
        return r'NT$';
      case 'AUD':
        return r'A$';
      case 'CAD':
        return r'C$';
      case 'CHF':
        return 'Fr';
      case 'THB':
        return '฿';
      case 'VND':
        return '₫';
      case 'INR':
        return '₹';
      case 'RUB':
        return '₽';
      case 'BRL':
        return r'R$';
      case 'MYR':
        return 'RM';
      case 'IDR':
        return 'Rp';
      case 'PHP':
        return '₱';
      case 'NZD':
        return r'NZ$';
      case 'SEK':
        return 'kr';
      case 'NOK':
        return 'kr';
      case 'DKK':
        return 'kr';
      default:
        return '${currency.toUpperCase()} ';
    }
  }

  static String _dateOnly(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  static String _dateTime(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }
    return value.length >= 16 ? value.substring(0, 16) : value;
  }
}

class _TradeRecordTile extends StatelessWidget {
  const _TradeRecordTile({required this.record});

  final _TradeRecord record;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${record.type}：'),
                        TextSpan(text: record.title),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff111111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MetaLine(label: '创建时间', value: record.createdAt),
                  const SizedBox(height: 4),
                  _MetaLine(label: '订单号', value: record.orderNo),
                  const SizedBox(height: 4),
                  _MetaLine(label: '支付时间', value: record.paidAt),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    record.amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff111111),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: record.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label：'),
          TextSpan(text: value),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Color(0xff999999),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.text,
    required this.actionText,
    required this.onAction,
  });

  final String text;
  final String actionText;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xff777777)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
}
