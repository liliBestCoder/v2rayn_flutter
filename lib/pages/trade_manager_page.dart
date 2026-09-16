import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/luxwap_theme.dart';

class TradeManagerPage extends StatefulWidget {
  const TradeManagerPage({super.key});

  @override
  State<TradeManagerPage> createState() => _TradeManagerPageState();
}

class _TradeManagerPageState extends State<TradeManagerPage> {
  late Future<List<TradeRecord>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _loadRecords();
  }

  Future<List<TradeRecord>> _loadRecords() async {
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
        .map((item) => TradeRecord.fromJson(Map<String, dynamic>.from(item)))
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
      child: FutureBuilder<List<TradeRecord>>(
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '加载失败：${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFE53935)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return const Center(
              child: Text(
                '暂无交易记录',
                style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(42, 30, 42, 32),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (context, index) =>
                  TradeBillCard(record: records[index]),
            ),
          );
        },
      ),
    );
  }
}

class TradeRecord {
  const TradeRecord({
    required this.type,
    required this.title,
    required this.createdAt,
    required this.orderNo,
    required this.paidAt,
    required this.amount,
    required this.status,
    required this.statusColor,
  });

  factory TradeRecord.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    final paidAmount = json['paidAmount']?.toString();
    final amount = json['amount']?.toString() ?? '0.00';
    final currency = json['paidCurrency']?.toString().isNotEmpty == true
        ? json['paidCurrency'].toString()
        : (json['currency']?.toString() ?? 'USD');
    return TradeRecord(
      type: _paymentTypeLabel(json['paymentType']?.toString()),
      title: json['packageName']?.toString() ?? '会员套餐',
      createdAt: _dateTime(json['createdAt']?.toString()),
      orderNo: json['orderNo']?.toString() ?? '-',
      paidAt: _dateTime(json['paidAt']?.toString()),
      amount:
          '${_currencySymbol(currency)} ${paidAmount?.isNotEmpty == true ? paidAmount : amount}',
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
        return const Color(0xFFFF9923);
      case 'PENDING':
        return const Color(0xFF286AFC);
      case 'CLOSED':
        return const Color(0xFF999999);
      case 'FAILED':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF666666);
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
      default:
        return '$currency ';
    }
  }

  static String _dateTime(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }
    return value.length >= 16 ? value.substring(0, 16) : value;
  }
}

class TradeBillCard extends StatelessWidget {
  const TradeBillCard({super.key, required this.record});

  final TradeRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFDFDFDF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '订单：${record.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxwapTypography.heading2.copyWith(
                    color: LuxwapColors.neutral900,
                  ),
                ),
                Text(
                  '有效期：${record.paidAt != '-' ? record.paidAt : record.createdAt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxwapTypography.heading3.copyWith(
                    color: LuxwapColors.neutral700,
                  ),
                ),
                Text(
                  '订单号：${record.orderNo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxwapTypography.heading6.copyWith(
                    color: LuxwapColors.neutral400,
                  ),
                ),
                Text(
                  '开始时间：${record.createdAt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxwapTypography.heading6.copyWith(
                    color: LuxwapColors.neutral400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.amount,
                style: LuxwapTypography.heading2.copyWith(
                  color: LuxwapColors.neutral900,
                ),
              ),
              const Spacer(),
              Text(
                record.status,
                style: LuxwapTypography.heading3.copyWith(
                  color: record.statusColor,
                ),
              ),
            ],
          ),
        ],
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
            style: const TextStyle(fontSize: 16, color: Color(0xffb2b2b2)),
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
