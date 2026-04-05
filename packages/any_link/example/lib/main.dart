import 'package:any_link/any_link.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AnyLinkExampleApp());
}

class AnyLinkExampleApp extends StatelessWidget {
  const AnyLinkExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'any_link Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

// ── Shared client ─────────────────────────────────────────────────────────────

final _client = AnyLinkClient(
  config: AnyLinkConfig(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ),
)..interceptors.addAll([
    LogInterceptor(level: LogLevel.basic),
    RetryInterceptor(maxRetries: 2),
  ]);

// ── Home page ─────────────────────────────────────────────────────────────────

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <(String, Widget)>[
      ('GET  — fetch posts', const _GetPostsPage()),
      ('POST — create post', const _CreatePostPage()),
      ('PUT  — update post', const _UpdatePostPage()),
      ('DEL  — delete post', const _DeletePostPage()),
      ('ERR  — error handling', const _ErrorPage()),
      ('AUTH — token refresh', const _AuthPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('any_link demos')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: demos.length,
        separatorBuilder: (context, i) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final (title, page) = demos[i];
          return FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => page),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: const TextStyle(fontFamily: 'monospace')),
            ),
          );
        },
      ),
    );
  }
}

// ── Reusable scaffold ─────────────────────────────────────────────────────────

class _DemoPage extends StatefulWidget {
  final String title;
  final Future<String> Function() action;

  const _DemoPage({required this.title, required this.action});

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  String _output = 'Tap "Run" to fire the request.';
  bool _loading = false;

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _output = 'Loading…';
    });
    try {
      final result = await widget.action();
      setState(() => _output = result);
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _loading ? null : _run,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Run'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _output,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Demo pages ────────────────────────────────────────────────────────────────

class _GetPostsPage extends StatelessWidget {
  const _GetPostsPage();

  @override
  Widget build(BuildContext context) => _DemoPage(
        title: 'GET — fetch posts',
        action: () async {
          final response = await _client.get('/posts', queryParams: {'_limit': '5'});
          final posts = response.jsonList;
          return posts
              .map((p) {
                final post = p as Map<String, dynamic>;
                return '[${post['id']}] ${post['title']}';
              })
              .join('\n\n');
        },
      );
}

class _CreatePostPage extends StatelessWidget {
  const _CreatePostPage();

  @override
  Widget build(BuildContext context) => _DemoPage(
        title: 'POST — create post',
        action: () async {
          final response = await _client.post(
            '/posts',
            body: {
              'title': 'any_link is awesome',
              'body': 'Zero-dependency HTTP client for Flutter.',
              'userId': 1,
            },
          );
          final post = response.jsonMap;
          return 'Created post #${post['id']}\n'
              'Title: ${post['title']}\n'
              'Body:  ${post['body']}';
        },
      );
}

class _UpdatePostPage extends StatelessWidget {
  const _UpdatePostPage();

  @override
  Widget build(BuildContext context) => _DemoPage(
        title: 'PUT — update post',
        action: () async {
          final response = await _client.put(
            '/posts/1',
            body: {'title': 'Updated title', 'body': 'Updated body', 'userId': 1},
          );
          final post = response.jsonMap;
          return 'Updated post #${post['id']}\n'
              'New title: ${post['title']}';
        },
      );
}

class _DeletePostPage extends StatelessWidget {
  const _DeletePostPage();

  @override
  Widget build(BuildContext context) => _DemoPage(
        title: 'DEL — delete post',
        action: () async {
          final response = await _client.delete('/posts/1');
          return 'Status: ${response.statusCode}\n'
              'Post deleted successfully.';
        },
      );
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage();

  @override
  Widget build(BuildContext context) => _DemoPage(
        title: 'ERR — error handling',
        action: () async {
          try {
            await _client.get('/posts/99999');
            return 'Unexpected success';
          } on AnyLinkError catch (e) {
            return 'Caught AnyLinkError:\n'
                '  statusCode : ${e.statusCode}\n'
                '  message    : ${e.message}\n'
                '  isNotFound : ${e.isNotFound}\n'
                '  isTimeout  : ${e.isTimeout}\n'
                '  isCancelled: ${e.isCancelled}';
          }
        },
      );
}

class _AuthPage extends StatelessWidget {
  const _AuthPage();

  @override
  Widget build(BuildContext context) => _DemoPage(
        title: 'AUTH — token refresh',
        action: () async {
          final storage = InMemoryTokenStorage();
          await storage.saveTokens(
            accessToken: 'demo-access-token',
            refreshToken: 'demo-refresh-token',
          );

          final authClient = AnyLinkClient(
            config: AnyLinkConfig(baseUrl: 'https://jsonplaceholder.typicode.com'),
          )..interceptors.add(
              AuthInterceptor(
                tokenStorage: storage,
                onRefresh: (_, refreshToken) async {
                  // In a real app, call your auth endpoint here.
                  return TokenPair(
                    accessToken: 'new-access-token',
                    refreshToken: refreshToken,
                  );
                },
                onSessionExpired: () => debugPrint('Session expired!'),
              ),
            );

          final response = await authClient.get('/posts/1');
          final post = response.jsonMap;
          return 'AuthInterceptor attached Bearer token.\n\n'
              'Response:\n'
              '  id   : ${post['id']}\n'
              '  title: ${post['title']}';
        },
      );
}
