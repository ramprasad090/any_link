/// A GraphQL field-level error returned in the `errors` array.
class GraphQLError {
  final String message;
  final List<String>? path;
  final Map<String, dynamic>? extensions;

  const GraphQLError({
    required this.message,
    this.path,
    this.extensions,
  });

  factory GraphQLError.fromJson(Map<String, dynamic> json) => GraphQLError(
        message: json['message'] as String? ?? 'Unknown GraphQL error',
        path: (json['path'] as List?)?.map((e) => e.toString()).toList(),
        extensions: json['extensions'] as Map<String, dynamic>?,
      );

  @override
  String toString() => 'GraphQLError: $message (path: ${path?.join('.')})';
}
