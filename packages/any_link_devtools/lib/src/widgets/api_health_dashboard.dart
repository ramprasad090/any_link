import 'package:flutter/material.dart';
import 'package:any_link/any_link.dart';

/// Drop-in API health dashboard widget.
///
/// Shows real-time response times, error rates, and slowest endpoints.
/// Powered by [AnalyticsInterceptor].
///
/// ```dart
/// ApiHealthDashboard(analyticsInterceptor: myAnalytics)
/// ```
class ApiHealthDashboard extends StatelessWidget {
  final AnalyticsInterceptor analyticsInterceptor;
  final bool compact;

  const ApiHealthDashboard({
    super.key,
    required this.analyticsInterceptor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AnalyticsEvent>(
      stream: analyticsInterceptor.analyticsStream,
      builder: (context, _) {
        final stats = analyticsInterceptor.getStats();
        if (stats.isEmpty) {
          return const Center(child: Text('No API calls yet'));
        }

        final sorted = stats.values.toList()
          ..sort((a, b) => b.avgResponseMs.compareTo(a.avgResponseMs));

        if (compact) return _CompactDashboard(endpoints: sorted);
        return _FullDashboard(endpoints: sorted);
      },
    );
  }
}

class _CompactDashboard extends StatelessWidget {
  final List<EndpointStats> endpoints;
  const _CompactDashboard({required this.endpoints});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('API Health', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            ...endpoints.take(5).map((e) => _EndpointRow(stats: e)),
          ],
        ),
      ),
    );
  }
}

class _FullDashboard extends StatelessWidget {
  final List<EndpointStats> endpoints;
  const _FullDashboard({required this.endpoints});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: endpoints.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _EndpointRow(stats: endpoints[i]),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final EndpointStats stats;
  const _EndpointRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final errorColor = stats.errorRate > 0.1 ? Colors.red : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(stats.path,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('${stats.avgResponseMs.toStringAsFixed(0)}ms',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 8),
          Text('${stats.callCount}×',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
          const SizedBox(width: 8),
          if (stats.errorCount > 0)
            Text('${(stats.errorRate * 100).toStringAsFixed(0)}% err',
                style: TextStyle(fontSize: 11, color: errorColor)),
        ],
      ),
    );
  }
}
