import 'dart:async';
import 'package:flutter/material.dart';
import '../connectivity_monitor.dart';
import '../network_status.dart';

/// Shows an animated banner or full-screen overlay when offline.
///
/// Wraps your app's body. The banner auto-shows when offline and
/// auto-hides when back online.
///
/// ```dart
/// ConnectivityOverlay(
///   monitor: connectivityMonitor,
///   child: Scaffold(body: MyApp()),
/// )
/// ```
class ConnectivityOverlay extends StatefulWidget {
  final ConnectivityMonitor monitor;
  final Widget child;
  final bool fullScreen;
  final Color? bannerColor;
  final String? offlineMessage;
  final String? captivePortalMessage;

  const ConnectivityOverlay({
    super.key,
    required this.monitor,
    required this.child,
    this.fullScreen = false,
    this.bannerColor,
    this.offlineMessage,
    this.captivePortalMessage,
  });

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late StreamSubscription<NetworkStatus> _sub;
  NetworkStatus _status = NetworkStatus.online;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _status = widget.monitor.status.value;
    _sub = widget.monitor.statusStream.listen((status) {
      setState(() => _status = status);
      if (status != NetworkStatus.online) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_status != NetworkStatus.online)
          SlideTransition(
            position: _slideAnimation,
            child: _buildBanner(),
          ),
      ],
    );
  }

  Widget _buildBanner() {
    final message = _status == NetworkStatus.captivePortal
        ? (widget.captivePortalMessage ?? 'Sign in to use this network')
        : (widget.offlineMessage ?? 'No internet connection');

    final color = widget.bannerColor ??
        (_status == NetworkStatus.captivePortal ? Colors.orange : Colors.red.shade700);

    if (widget.fullScreen) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A standalone offline banner widget.
class OfflineBanner extends StatelessWidget {
  final String message;
  final Color? backgroundColor;

  const OfflineBanner({
    super.key,
    this.message = 'No internet connection',
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// A full-screen offline placeholder.
class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? title;
  final String? subtitle;

  const NoInternetScreen({super.key, this.onRetry, this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              Text(
                title ?? 'No Internet Connection',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ?? 'Please check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
