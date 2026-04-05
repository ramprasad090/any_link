/// `any_link` — Zero-dependency Flutter HTTP client family.
///
/// Built on `dart:io` directly. No `dio`, no `http` package.
/// 80+ features across 11 packages.
///
/// Publisher: ramprasadsreerama.co.in
library;

// ── Client ────────────────────────────────────────────────────────────────────
export 'src/client/any_link_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────
export 'src/models/config.dart';
export 'src/models/request.dart';
export 'src/models/response.dart';
export 'src/models/error.dart';
export 'src/models/cancel_token.dart';

// ── Interceptors ──────────────────────────────────────────────────────────────
export 'src/interceptors/base_interceptor.dart';
export 'src/interceptors/auth_interceptor.dart';
export 'src/interceptors/log_interceptor.dart';
export 'src/interceptors/retry_interceptor.dart';
export 'src/interceptors/dedup_interceptor.dart';
export 'src/interceptors/transform_interceptor.dart';
export 'src/interceptors/version_interceptor.dart';
export 'src/interceptors/idempotency_interceptor.dart';
export 'src/interceptors/rate_limit_interceptor.dart';
export 'src/interceptors/analytics_interceptor.dart';

// ── Auth ──────────────────────────────────────────────────────────────────────
export 'src/auth/token_storage.dart';

// ── Logging ───────────────────────────────────────────────────────────────────
export 'src/logging/log_entry.dart';
export 'src/logging/log_sink.dart';

// ── Error mappers ─────────────────────────────────────────────────────────────
export 'src/errors/error_mappers.dart';

// ── Form data ─────────────────────────────────────────────────────────────────
export 'src/form_data/any_link_form_data.dart';

// ── Batching ──────────────────────────────────────────────────────────────────
export 'src/batching/batch_manager.dart';

// ── Pagination ────────────────────────────────────────────────────────────────
export 'src/pagination/paginator.dart';
export 'src/pagination/page_info.dart';
export 'src/pagination/pagination_state.dart';
export 'src/pagination/pagination_strategy.dart';
export 'src/pagination/parsers/pagination_parser.dart';
export 'src/pagination/parsers/laravel_parser.dart';
export 'src/pagination/parsers/django_parser.dart';
export 'src/pagination/parsers/strapi_parser.dart';
export 'src/pagination/parsers/fastapi_parser.dart';
export 'src/pagination/parsers/cursor_parser.dart';
export 'src/pagination/parsers/custom_parser.dart';
export 'src/pagination/widgets/paginated_list.dart';
export 'src/pagination/widgets/paginated_grid.dart';
export 'src/pagination/widgets/paginated_sliver.dart';

// ── Module ────────────────────────────────────────────────────────────────────
export 'src/module/api_module.dart';

// ── Speed ─────────────────────────────────────────────────────────────────────
export 'src/speed/dns_pre_resolver.dart';
export 'src/speed/contract_validator.dart';
export 'src/speed/cost_tracker.dart';
