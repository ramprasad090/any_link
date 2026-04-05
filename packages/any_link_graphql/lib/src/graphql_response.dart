import 'graphql_error.dart';

/// The result of a GraphQL query or mutation.
class GraphQLResponse<T> {
  final T? data;
  final List<GraphQLError>? errors;
  final Map<String, dynamic>? extensions;

  const GraphQLResponse({this.data, this.errors, this.extensions});

  /// Whether the response contains any field-level errors.
  bool get hasErrors => errors?.isNotEmpty ?? false;

  @override
  String toString() => 'GraphQLResponse(data: $data, errors: $errors)';
}
