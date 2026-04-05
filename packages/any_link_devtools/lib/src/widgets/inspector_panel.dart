import 'package:flutter/material.dart';
import 'package:any_link/any_link.dart';
import '../network_inspector.dart';

/// In-app overlay inspector panel showing all HTTP requests.
///
/// Activate by shaking the device (on mobile) or pressing a debug button.
/// Shows method, path, status, timing, and full headers/body on tap.
///
/// ```dart
/// // Wrap your app:
/// InspectorOverlay(
///   inspector: networkInspector,
///   child: MyApp(),
/// )
/// ```
class InspectorOverlay extends StatefulWidget {
  final NetworkInspector inspector;
  final Widget child;

  const InspectorOverlay({
    super.key,
    required this.inspector,
    required this.child,
  });

  @override
  State<InspectorOverlay> createState() => _InspectorOverlayState();
}

class _InspectorOverlayState extends State<InspectorOverlay> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Material(
            child: _InspectorPanel(
              inspector: widget.inspector,
              onClose: () => setState(() => _visible = false),
            ),
          ),
        // Floating toggle button.
        Positioned(
          bottom: 80,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: () => setState(() => _visible = !_visible),
            backgroundColor: _visible ? Colors.red : Colors.blueGrey,
            tooltip: 'Network Inspector',
            child: Icon(_visible ? Icons.close : Icons.network_check, size: 18),
          ),
        ),
      ],
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  final NetworkInspector inspector;
  final VoidCallback onClose;

  const _InspectorPanel({required this.inspector, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Inspector', style: TextStyle(fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: inspector.clear,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: StreamBuilder<List<LogEntry>>(
        stream: inspector.logsStream,
        initialData: inspector.logs,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text('No requests yet'));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final entry = logs[index];
              return _LogTile(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.statusCode == null
        ? Colors.red
        : entry.statusCode! < 300
            ? Colors.green
            : entry.statusCode! < 400
                ? Colors.orange
                : Colors.red;

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(entry.method, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      title: Text(entry.path, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '[${entry.prefix}] ${entry.durationMs}ms',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: Text(
        '${entry.statusCode ?? "ERR"}',
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
      onTap: () => _showDetail(context, entry),
    );
  }

  void _showDetail(BuildContext context, LogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.method} ${entry.path}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Status: ${entry.statusCode ?? "Error"}'),
              Text('Duration: ${entry.durationMs}ms'),
              Text('Time: ${entry.timestamp}'),
              if (entry.error != null) ...[
                const SizedBox(height: 8),
                Text('Error: ${entry.error}', style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
