import 'dart:async';
import 'dart:developer' as dev;

/// An API cost event emitted by [CostTracker].
class CostEvent {
  final String path;
  final double cost;
  final DateTime timestamp;
  final double totalSessionCost;

  const CostEvent({
    required this.path,
    required this.cost,
    required this.timestamp,
    required this.totalSessionCost,
  });
}

/// Tracks per-call API costs in real time.
///
/// Particularly useful for LLM/AI APIs (OpenAI, Anthropic, Gemini) where each
/// call has a measurable cost in USD.
///
/// ```dart
/// final tracker = CostTracker()
///   ..registerCost('/v1/chat/completions', 0.002)
///   ..setBudget(10.0, onBudgetExceeded: () => disableAIFeatures());
/// ```
class CostTracker {
  final Map<RegExp, double> _patterns = {};
  double _sessionCost = 0;
  double? _monthlyBudget;
  VoidCallback? _onBudgetExceeded;

  final StreamController<CostEvent> _controller =
      StreamController<CostEvent>.broadcast();

  /// Live stream of cost events.
  Stream<CostEvent> get costStream => _controller.stream;

  /// Total cost accumulated this session.
  double get sessionCost => _sessionCost;

  /// Register a fixed cost per call for paths matching [pathPattern].
  void registerCost(String pathPattern, double costPerCall) {
    _patterns[RegExp(pathPattern)] = costPerCall;
  }

  /// Set a monthly budget. [onBudgetExceeded] is called when [sessionCost]
  /// exceeds [monthlyLimit].
  void setBudget(double monthlyLimit, {VoidCallback? onBudgetExceeded}) {
    _monthlyBudget = monthlyLimit;
    _onBudgetExceeded = onBudgetExceeded;
  }

  /// Record a cost event for [path].
  void record(String path) {
    double cost = 0;
    for (final entry in _patterns.entries) {
      if (entry.key.hasMatch(path)) {
        cost = entry.value;
        break;
      }
    }
    if (cost == 0) return;

    _sessionCost += cost;

    final event = CostEvent(
      path: path,
      cost: cost,
      timestamp: DateTime.now(),
      totalSessionCost: _sessionCost,
    );
    _controller.add(event);

    dev.log(
      'API cost: \$${cost.toStringAsFixed(4)} for $path '
      '(session total: \$${_sessionCost.toStringAsFixed(4)})',
      name: 'any_link.cost',
    );

    if (_monthlyBudget != null && _sessionCost >= _monthlyBudget!) {
      dev.log('⚠️  Monthly budget \$$_monthlyBudget exceeded!', name: 'any_link.cost');
      _onBudgetExceeded?.call();
    }
  }

  void dispose() => _controller.close();
}

typedef VoidCallback = void Function();
