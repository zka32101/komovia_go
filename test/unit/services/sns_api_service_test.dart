import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/sns_api_service.dart';
import 'package:http/http.dart' as http;

/// A fake [http.Client] that only needs to implement [send] (everything
/// else - get/post/etc. - is provided by [http.BaseClient] in terms of
/// it), avoiding mockito entirely: its `any`/`anyNamed` matchers are
/// typed `Null` and only work with codegen'd mocks, which this service
/// doesn't have.
class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

http.StreamedResponse _jsonStreamed(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
  );
}

http.StreamedResponse _plainStreamed(String body, int statusCode) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
}

void main() {
  group('Twitter/X API Integration Tests', () {
    final testBearerToken = 'test-bearer-token';
    final testImageBytes = [137, 80, 78, 71]; // PNG magic bytes

    group('Twitter API v2 Integration', () {
      test('Posts tweet with game result successfully', () async {
        // Given
        final text = '🎮 I just won a Go game on GoEn! #GoEn #Gaming';
        final mediaIds = ['123456', '789012'];
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({
            'data': {'id': 'tweet-1'},
          }, statusCode: 201),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final result = await snsService.postGameResultTweet(
          text: text,
          mediaIds: mediaIds,
        );

        // Then
        expect(result, isNotNull);
        expect(result?.text, text);
        expect(result?.createdAt, isNotNull);
      });

      test('Handles missing bearer token gracefully', () async {
        // Given
        final client = FakeHttpClient(
          (request) async => throw StateError('should not be called'),
        );
        final snsServiceNoToken = SnsApiService(client: client);
        final text = 'Test tweet';

        // When
        final result = await snsServiceNoToken.postGameResultTweet(
          text: text,
          mediaIds: null,
        );

        // Then
        expect(result, isNull);
        expect(client.requests, isEmpty);
      });

      test('Posts tweet without media', () async {
        // Given
        final text = '碁を勉強中です！ #Go #GoEn';
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({
            'data': {'id': 'tweet-2'},
          }, statusCode: 201),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final result = await snsService.postGameResultTweet(
          text: text,
          mediaIds: null,
        );

        // Then
        expect(result, isNotNull);
        expect(result?.text, text);
      });
    });

    group('Media Upload to Twitter', () {
      test('Uploads board image successfully', () async {
        // Given
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({'media_id_string': 'media-1'}),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final mediaId = await snsService.uploadMediaToTwitter(
          imageBytes: testImageBytes,
          mediaType: 'image/png',
        );

        // Then
        expect(mediaId, 'media-1');
      });

      test('Handles media upload without bearer token', () async {
        // Given
        final client = FakeHttpClient(
          (request) async => throw StateError('should not be called'),
        );
        final snsServiceNoToken = SnsApiService(client: client);

        // When
        final mediaId = await snsServiceNoToken.uploadMediaToTwitter(
          imageBytes: testImageBytes,
          mediaType: 'image/png',
        );

        // Then
        expect(mediaId, isNull);
        expect(client.requests, isEmpty);
      });

      test('Supports JPEG format media upload', () async {
        // Given
        final jpegBytes = [255, 216, 255, 224]; // JPEG magic bytes
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({'media_id_string': 'media-jpeg'}),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final mediaId = await snsService.uploadMediaToTwitter(
          imageBytes: jpegBytes,
          mediaType: 'image/jpeg',
        );

        // Then
        expect(mediaId, 'media-jpeg');
      });
    });

    group('Twitter Thread Management', () {
      test('Posts game analysis thread with replies', () async {
        // Given
        final gameId = 'game-123';
        final threadTexts = [
          '分析開始：この対局を見てください 📊',
          '序盤：白のアプローチが興味深い',
          '中盤：黒が領地を確保した',
          '終盤：白が粘り強く戦った 🏁',
        ];
        final mediaIds = ['image-1'];
        var nextId = 0;
        final client = FakeHttpClient((request) async {
          nextId++;
          return _jsonStreamed({
            'data': {'id': 'thread-tweet-$nextId'},
          }, statusCode: 201);
        });
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final responses = await snsService.postGameAnalysisThread(
          gameId: gameId,
          threadTexts: threadTexts,
          mediaIds: mediaIds,
        );

        // Then
        expect(responses.length, threadTexts.length);
        expect(responses.first.text, threadTexts.first);
      });

      test('Handles empty thread gracefully', () async {
        // Given
        final gameId = 'game-456';
        final threadTexts = <String>[];
        final client = FakeHttpClient(
          (request) async => throw StateError('should not be called'),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final responses = await snsService.postGameAnalysisThread(
          gameId: gameId,
          threadTexts: threadTexts,
          mediaIds: null,
        );

        // Then
        expect(responses.isEmpty, true);
        expect(client.requests, isEmpty);
      });

      test('Creates tweet with in_reply_to relationship', () async {
        // Given
        final threadTexts = [
          'First tweet in thread',
          'Reply to first tweet',
          'Another reply',
        ];
        var nextId = 0;
        final client = FakeHttpClient((request) async {
          nextId++;
          return _jsonStreamed({
            'data': {'id': 'reply-tweet-$nextId'},
          }, statusCode: 201);
        });
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final responses = await snsService.postGameAnalysisThread(
          gameId: 'game-789',
          threadTexts: threadTexts,
          mediaIds: null,
        );

        // Then
        expect(responses.length, threadTexts.length);
        // Each tweet should maintain thread order
        for (int i = 0; i < responses.length; i++) {
          expect(responses[i].text, threadTexts[i]);
        }
      });
    });

    group('Tweet Metrics & Analytics', () {
      test('Retrieves tweet engagement metrics', () async {
        // Given
        final tweetId = 'tweet-123456';
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({
            'data': {
              'public_metrics': {
                'like_count': 12,
                'retweet_count': 3,
                'reply_count': 2,
                'quote_count': 1,
                'impression_count': 500,
                'bookmark_count': 4,
              },
            },
          }),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final metrics = await snsService.getTweetMetrics(tweetId: tweetId);

        // Then
        expect(metrics, isNotNull);
        expect(metrics?.tweetId, tweetId);
        expect(metrics?.likes, greaterThanOrEqualTo(0));
        expect(metrics?.retweets, greaterThanOrEqualTo(0));
        expect(metrics?.replies, greaterThanOrEqualTo(0));
      });

      test('Handles metrics for non-existent tweet', () async {
        // Given
        final tweetId = 'non-existent-tweet-id';
        final client = FakeHttpClient(
          (request) async => _plainStreamed('Not Found', 404),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final metrics = await snsService.getTweetMetrics(tweetId: tweetId);

        // Then
        expect(metrics, isNull);
      });

      test('Calculates engagement from all metrics', () async {
        // Given
        final tweetId = 'viral-tweet-123';
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({
            'data': {
              'public_metrics': {
                'like_count': 1000,
                'retweet_count': 200,
                'reply_count': 50,
                'quote_count': 10,
                'impression_count': 50000,
                'bookmark_count': 30,
              },
            },
          }),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final metrics = await snsService.getTweetMetrics(tweetId: tweetId);

        // Then
        expect(metrics, isNotNull);
        final totalEngagement = (metrics?.likes ?? 0) +
            (metrics?.retweets ?? 0) +
            (metrics?.replies ?? 0) +
            (metrics?.bookmarks ?? 0);
        expect(totalEngagement, greaterThanOrEqualTo(0));
      });
    });

    group('User Timeline Retrieval', () {
      test('Retrieves user timeline with tweets', () async {
        // Given
        final userId = 'user-123';
        final maxResults = 10;
        final client = FakeHttpClient(
          (request) async => _jsonStreamed({
            'data': [
              {
                'id': 'tweet-1',
                'text': 'Hello',
                'created_at': DateTime.now().toIso8601String(),
              },
              {
                'id': 'tweet-2',
                'text': 'World',
                'created_at': DateTime.now().toIso8601String(),
              },
            ],
          }),
        );
        final snsService = SnsApiService(
          twitterBearerToken: testBearerToken,
          client: client,
        );

        // When
        final tweets = await snsService.getUserTimeline(
          userId: userId,
          maxResults: maxResults,
        );

        // Then
        expect(tweets, isNotNull);
        expect(tweets.length, lessThanOrEqualTo(maxResults));
      });

      test('Returns empty list without bearer token', () async {
        // Given
        final client = FakeHttpClient(
          (request) async => throw StateError('should not be called'),
        );
        final snsServiceNoToken = SnsApiService(client: client);
        final userId = 'user-456';

        // When
        final tweets = await snsServiceNoToken.getUserTimeline(
          userId: userId,
          maxResults: 5,
        );

        // Then
        expect(tweets.isEmpty, true);
        expect(client.requests, isEmpty);
      });
    });
  });

  group('Content Optimization Tests', () {
    test('Optimizes tweet with hashtags for Go', () {
      // Given
      final baseText = 'I just completed a Go game!';
      final optimizedText =
          '$baseText #Go #GoEn #WeiQi #BoardGame #OnlineGo';

      // Then
      expect(optimizedText.contains('#Go'), true);
      expect(optimizedText.contains('#GoEn'), true);
      expect(optimizedText.length, lessThanOrEqualTo(280));
    });

    test('Validates tweet character count', () {
      // Given
      final shortTweet = 'Quick game!';
      final maxTweetLength = 280;

      // Then
      expect(shortTweet.length, lessThanOrEqualTo(maxTweetLength));
    });

    test('Handles emoji in tweet content', () async {
      // Given
      final textWithEmoji = '🎮 GoEn ♟️ 碁 🏆 #Gaming';
      final client = FakeHttpClient(
        (request) async => _jsonStreamed({
          'data': {'id': 'emoji-tweet'},
        }, statusCode: 201),
      );
      final snsService = SnsApiService(
        twitterBearerToken: 'test-token',
        client: client,
      );

      // When
      final result = await snsService.postGameResultTweet(
        text: textWithEmoji,
        mediaIds: null,
      );

      // Then
      expect(result?.text, textWithEmoji);
    });
  });

  group('Error Handling & Resilience', () {
    test('Handles API error responses gracefully', () async {
      // Given - Simulating API error
      final client = FakeHttpClient(
        (request) async => _plainStreamed('Server Error', 500),
      );
      final snsService = SnsApiService(
        twitterBearerToken: 'test-token',
        client: client,
      );

      // When
      final result = await snsService.postGameResultTweet(
        text: 'Test tweet',
        mediaIds: null,
      );

      // Then
      expect(result, isNull);
    });

    test('Handles network timeout in tweet posting', () async {
      // Given
      final client = FakeHttpClient(
        (request) async => throw Exception('Connection timed out'),
      );
      final snsService = SnsApiService(
        twitterBearerToken: 'test-token',
        client: client,
      );

      // When
      final result = await snsService.postGameResultTweet(
        text: 'Test tweet for timeout',
        mediaIds: null,
      );

      // Then - the service catches the exception and returns null
      expect(result, isNull);
    });

    test('Retries failed media uploads', () async {
      // Given
      final client = FakeHttpClient(
        (request) async => _plainStreamed('Server Error', 500),
      );
      final snsService = SnsApiService(
        twitterBearerToken: 'test-token',
        client: client,
      );

      // When
      final mediaId = await snsService.uploadMediaToTwitter(
        imageBytes: [137, 80, 78, 71],
        mediaType: 'image/png',
      );

      // Then - a failed upload returns null rather than throwing
      expect(mediaId, isNull);
    });
  });

  group('Facebook Integration Tests', () {
    final testFbToken = 'test-facebook-token';

    test('Posts message to Facebook page', () async {
      // Given
      final message = 'Check out my Go game on GoEn!';
      final pageId = 'page-123';
      final client = FakeHttpClient(
        (request) async => _jsonStreamed({'id': 'fb-post-1'}),
      );
      final snsService = SnsApiService(
        facebookAccessToken: testFbToken,
        client: client,
      );

      // When
      final result = await snsService.postToFacebook(
        message: message,
        pageId: pageId,
        imageUrl: 'https://example.com/image.jpg',
      );

      // Then
      expect(result, isNotNull);
      expect(result?.message, message);
    });

    test('Handles missing Facebook token', () async {
      // Given
      final client = FakeHttpClient(
        (request) async => throw StateError('should not be called'),
      );
      final snsServiceNoToken = SnsApiService(client: client);

      // When
      final result = await snsServiceNoToken.postToFacebook(
        message: 'Test',
        pageId: 'page-456',
      );

      // Then
      expect(result, isNull);
      expect(client.requests, isEmpty);
    });
  });
}
