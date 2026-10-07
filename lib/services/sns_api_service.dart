import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import '../models/sns_models.dart';

final _logger = Logger();

/// Service for API-based SNS integration (Twitter/X, etc.)
class SnsApiService {
  final String? twitterBearerToken;
  final String? facebookAccessToken;
  final String? instagramAccessToken;
  final http.Client _client;

  SnsApiService({
    this.twitterBearerToken,
    this.facebookAccessToken,
    this.instagramAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // Twitter/X API v2 Integration
  /// Post a tweet with game result
  Future<TwitterTweetResponse?> postGameResultTweet({
    required String text,
    required List<String>? mediaIds,
  }) async {
    if (twitterBearerToken == null) {
      _logger.w('Twitter bearer token not configured');
      return null;
    }

    try {
      final url = Uri.parse('https://api.twitter.com/2/tweets');

      final body = {
        'text': text,
        if (mediaIds != null && mediaIds.isNotEmpty)
          'media': {
            'media_ids': mediaIds,
          },
      };

      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $twitterBearerToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return TwitterTweetResponse(
          tweetId: data['data']['id'],
          text: text,
          createdAt: DateTime.now(),
        );
      } else {
        _logger.e('Twitter API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Failed to post tweet: $e');
      return null;
    }
  }

  /// Upload media (board image) to Twitter
  Future<String?> uploadMediaToTwitter({
    required List<int> imageBytes,
    required String mediaType, // 'image/png', 'image/jpeg'
  }) async {
    if (twitterBearerToken == null) {
      _logger.w('Twitter bearer token not configured');
      return null;
    }

    try {
      final url = Uri.parse('https://upload.twitter.com/1.1/media/upload.json');

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $twitterBearerToken'
        ..fields['media_data'] = base64Encode(imageBytes);

      final streamResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['media_id_string'];
      } else {
        _logger.e('Media upload error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Failed to upload media: $e');
      return null;
    }
  }

  /// Create a tweet thread for detailed game analysis
  Future<List<TwitterTweetResponse>> postGameAnalysisThread({
    required String gameId,
    required List<String> threadTexts,
    required List<String>? mediaIds,
  }) async {
    if (twitterBearerToken == null) return [];

    final responses = <TwitterTweetResponse>[];
    String? replyToId;

    try {
      for (int i = 0; i < threadTexts.length; i++) {
        final text = threadTexts[i];
        final url = Uri.parse('https://api.twitter.com/2/tweets');

        final body = {
          'text': text,
          if (replyToId != null)
            'reply': {
              'in_reply_to_tweet_id': replyToId,
            },
          if (i == 0 && mediaIds != null && mediaIds.isNotEmpty)
            'media': {
              'media_ids': mediaIds,
            },
        };

        final response = await _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $twitterBearerToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final tweetResponse = TwitterTweetResponse(
            tweetId: data['data']['id'],
            text: text,
            createdAt: DateTime.now(),
          );
          responses.add(tweetResponse);
          replyToId = tweetResponse.tweetId; // Set for next reply
        }
      }

      return responses;
    } catch (e) {
      _logger.e('Failed to post thread: $e');
      return responses;
    }
  }

  // Facebook/Instagram Integration
  /// Post to Facebook page
  Future<FacebookPostResponse?> postToFacebook({
    required String message,
    required String pageId,
    String? imageUrl,
  }) async {
    if (facebookAccessToken == null) {
      _logger.w('Facebook access token not configured');
      return null;
    }

    try {
      final url = Uri.parse('https://graph.facebook.com/v18.0/$pageId/feed');

      final body = {
        'message': message,
        if (imageUrl != null) 'picture': imageUrl,
        'access_token': facebookAccessToken,
      };

      final response = await _client.post(
        url,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FacebookPostResponse(
          postId: data['id'],
          message: message,
          createdAt: DateTime.now(),
        );
      } else {
        _logger.e('Facebook API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Failed to post to Facebook: $e');
      return null;
    }
  }

  /// Share to Instagram Stories (requires app links configuration)
  Future<bool> shareToInstagramStories({
    required String imageUrl,
    required String caption,
  }) async {
    // Instagram Stories sharing typically requires app links
    // This is a placeholder for future implementation
    _logger.w('Instagram Stories sharing requires app links setup');
    return false;
  }

  // Analytics & Engagement
  /// Get tweet engagement metrics
  Future<TweetMetrics?> getTweetMetrics({
    required String tweetId,
  }) async {
    if (twitterBearerToken == null) return null;

    try {
      final url = Uri.parse(
        'https://api.twitter.com/2/tweets/$tweetId?tweet.fields=public_metrics,created_at',
      );

      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $twitterBearerToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final metrics = data['data']['public_metrics'];
        return TweetMetrics(
          tweetId: tweetId,
          likes: metrics['like_count'],
          retweets: metrics['retweet_count'],
          replies: metrics['reply_count'],
          quotes: metrics['quote_count'],
          impressions: metrics['impression_count'],
          bookmarks: metrics['bookmark_count'],
        );
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get tweet metrics: $e');
      return null;
    }
  }

  /// Get user's tweet timeline
  Future<List<TwitterTweetResponse>> getUserTimeline({
    required String userId,
    int maxResults = 10,
  }) async {
    if (twitterBearerToken == null) return [];

    try {
      final url = Uri.parse(
        'https://api.twitter.com/2/users/$userId/tweets?max_results=$maxResults&tweet.fields=created_at,public_metrics',
      );

      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $twitterBearerToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tweets = (data['data'] as List)
            .map((t) => TwitterTweetResponse(
                  tweetId: t['id'],
                  text: t['text'],
                  createdAt: DateTime.parse(t['created_at']),
                ))
            .toList();
        return tweets;
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get timeline: $e');
      return [];
    }
  }
}
