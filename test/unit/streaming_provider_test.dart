import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';

void main() {
  group('Streaming Provider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    /// Test 1: streamingUIProvider initial state
    test('streamingUIProvider initial state', () {
      final state = container.read(streamingUIProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.selectedTab, isNull);
    });

    /// Test 2: StreamingUINotifier setLoading
    test('StreamingUINotifier setLoading updates state', () {
      container.read(streamingUIProvider.notifier).setLoading(true);
      final state = container.read(streamingUIProvider);
      expect(state.isLoading, isTrue);
      expect(state.error, isNull);
    });

    /// Test 3: StreamingUINotifier setError
    test('StreamingUINotifier setError updates state', () {
      container.read(streamingUIProvider.notifier).setError('Upload failed');
      final state = container.read(streamingUIProvider);
      expect(state.error, equals('Upload failed'));
      expect(state.isLoading, isFalse);
    });

    /// Test 4: StreamingUINotifier selectTab
    test('StreamingUINotifier selectTab updates state', () {
      container.read(streamingUIProvider.notifier).selectTab('youtube');
      final state = container.read(streamingUIProvider);
      expect(state.selectedTab, equals('youtube'));
    });

    /// Test 5: StreamingUIState copyWith
    test('StreamingUIState copyWith creates new instance', () {
      final state1 = StreamingUIState(isLoading: true);
      final state2 = state1.copyWith(isLoading: false, selectedTab: 'twitch');

      expect(state1.isLoading, isTrue);
      expect(state2.isLoading, isFalse);
      expect(state2.selectedTab, equals('twitch'));
    });

    /// Test 6: Multiple tab selections
    test('multiple tab selections update correctly', () {
      final notifier = container.read(streamingUIProvider.notifier);

      notifier.selectTab('youtube');
      expect(container.read(streamingUIProvider).selectedTab, equals('youtube'));

      notifier.selectTab('twitch');
      expect(container.read(streamingUIProvider).selectedTab, equals('twitch'));

      notifier.selectTab('sponsorship');
      expect(container.read(streamingUIProvider).selectedTab, equals('sponsorship'));
    });

    /// Test 7: Error clears when setting loading
    test('error clears when setting loading', () {
      final notifier = container.read(streamingUIProvider.notifier);

      notifier.setError('Test error');
      expect(container.read(streamingUIProvider).error, isNotNull);

      notifier.setLoading(true);
      expect(container.read(streamingUIProvider).error, isNull);
      expect(container.read(streamingUIProvider).isLoading, isTrue);
    });

    /// Test 8: StreamingUIState preserves unmodified fields
    test('StreamingUIState copyWith preserves unmodified fields', () {
      final state1 = StreamingUIState(
        isLoading: true,
        error: 'Test error',
        selectedTab: 'youtube',
      );

      final state2 = state1.copyWith(isLoading: false);

      expect(state2.isLoading, isFalse);
      expect(state2.error, equals('Test error')); // Preserved
      expect(state2.selectedTab, equals('youtube')); // Preserved
    });

    /// Test 9: Multiple state updates in sequence
    test('multiple state updates work correctly', () {
      final notifier = container.read(streamingUIProvider.notifier);

      notifier.setLoading(true);
      var state = container.read(streamingUIProvider);
      expect(state.isLoading, isTrue);

      notifier.selectTab('youtube');
      state = container.read(streamingUIProvider);
      expect(state.isLoading, isTrue);
      expect(state.selectedTab, equals('youtube'));

      notifier.setError('Upload failed');
      state = container.read(streamingUIProvider);
      expect(state.error, equals('Upload failed'));
      expect(state.isLoading, isFalse);
    });

    /// Test 10: Reset to initial state
    test('can reset to initial state', () {
      final notifier = container.read(streamingUIProvider.notifier);

      // Set multiple states
      notifier.setLoading(true);
      notifier.selectTab('twitch');
      notifier.setError('Some error');

      // Create new notifier to reset
      final newContainer = ProviderContainer();
      final newState = newContainer.read(streamingUIProvider);

      expect(newState.isLoading, isFalse);
      expect(newState.error, isNull);
      expect(newState.selectedTab, isNull);
    });
  });
}
