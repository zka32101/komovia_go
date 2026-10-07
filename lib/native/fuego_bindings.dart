import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

// Fuego C++ エンジンへの FFI バインディング
// Fuego は軽量 Go エンジン (9x9 最適化)

typedef NativeInitFuego = ffi.Int32 Function();
typedef DartInitFuego = int Function();

typedef NativeGetMove = ffi.Int32 Function(
  ffi.Pointer<ffi.Int32> boardState,
  ffi.Int32 boardSize,
  ffi.Int32 aiLevel,
);
typedef DartGetMove = int Function(
  ffi.Pointer<ffi.Int32> boardState,
  int boardSize,
  int aiLevel,
);

typedef NativeGetMoveCoord = ffi.Void Function(
  ffi.Int32 moveId,
  ffi.Pointer<ffi.Int32> row,
  ffi.Pointer<ffi.Int32> col,
);
typedef DartGetMoveCoord = void Function(
  int moveId,
  ffi.Pointer<ffi.Int32> row,
  ffi.Pointer<ffi.Int32> col,
);

typedef NativeCleanup = ffi.Void Function();
typedef DartCleanup = void Function();

// 死石判定: 盤面を渡し、同サイズの出力配列に 1=死石 / 0=生存 を書き込む。
// Fuego 側は内部の安全性読み (GoSafetySolver 等) を使って判定する想定。
// 戻り値は判定できた死石の数。
typedef NativeGetDeadStones = ffi.Int32 Function(
  ffi.Pointer<ffi.Int32> boardState,
  ffi.Int32 boardSize,
  ffi.Pointer<ffi.Int32> deadStonesOut,
);
typedef DartGetDeadStones = int Function(
  ffi.Pointer<ffi.Int32> boardState,
  int boardSize,
  ffi.Pointer<ffi.Int32> deadStonesOut,
);

/// Fuego Go エンジン FFI ラッパー
class FuegoNative {
  late ffi.DynamicLibrary _lib;
  late DartInitFuego _initFuego;
  late DartGetMove _getMove;
  late DartGetMoveCoord _getMoveCoord;
  late DartCleanup _cleanup;

  // 死石判定はネイティブ側の対応が任意（未実装のビルドでも他機能は
  // 動作させたいため）、他のシンボルとは別に、失敗しても許容するルック
  // アップにしている。
  DartGetDeadStones? _getDeadStones;

  FuegoNative() {
    _loadLibrary();
  }

  void _loadLibrary() {
    try {
      if (Platform.isAndroid) {
        _lib = ffi.DynamicLibrary.open('libfuego.so');
      } else if (Platform.isIOS) {
        _lib = ffi.DynamicLibrary.process();
      } else {
        throw UnsupportedError('Fuego is not supported on ${Platform.operatingSystem}');
      }

      _initFuego = _lib.lookupFunction<NativeInitFuego, DartInitFuego>('fuego_init');
      _getMove = _lib.lookupFunction<NativeGetMove, DartGetMove>('fuego_get_move');
      _getMoveCoord = _lib.lookupFunction<NativeGetMoveCoord, DartGetMoveCoord>('fuego_get_move_coord');
      _cleanup = _lib.lookupFunction<NativeCleanup, DartCleanup>('fuego_cleanup');
    } catch (e) {
      // Catches both Exception (e.g. missing symbol) and Error subclasses
      // (e.g. UnsupportedError from an unsupported platform above), so
      // callers always see a consistent, wrapped failure.
      throw Exception('Failed to load Fuego library: $e');
    }

    try {
      _getDeadStones = _lib.lookupFunction<NativeGetDeadStones, DartGetDeadStones>(
        'fuego_get_dead_stones',
      );
    } catch (e) {
      // Older/simpler native builds may not export this yet — the rest of
      // the engine still works, dead-stone detection just falls back.
      _getDeadStones = null;
    }
  }

  /// ネイティブ側が死石判定 API を実装しているか
  bool get supportsDeadStoneDetection => _getDeadStones != null;

  /// Fuego エンジンを初期化
  int initialize() {
    return _initFuego();
  }

  /// AI の手を取得
  /// boardState: 1D 配列 (row-major order)
  /// boardSize: ボードサイズ (9, 13, 19)
  /// aiLevel: AI レベル (1-10)
  /// 戻り値: move ID
  int getMove(List<int> boardState, int boardSize, int aiLevel) {
    final nativeBoard = malloc<ffi.Int32>(boardState.length);
    for (int i = 0; i < boardState.length; i++) {
      nativeBoard[i] = boardState[i];
    }

    try {
      return _getMove(nativeBoard, boardSize, aiLevel);
    } finally {
      malloc.free(nativeBoard);
    }
  }

  /// Move ID から座標を取得
  /// moveId: getMove() の戻り値
  /// 戻り値: (row, col)
  (int, int) getMoveCoords(int moveId) {
    final row = malloc<ffi.Int32>();
    final col = malloc<ffi.Int32>();

    try {
      _getMoveCoord(moveId, row, col);
      return (row.value, col.value);
    } finally {
      malloc.free(row);
      malloc.free(col);
    }
  }

  /// 死石を判定する（Fuego の安全性読みを使用）
  /// boardState: 1D 配列 (row-major order, 0=empty, 1=black, 2=white)
  /// 戻り値: boardState と同じ長さの配列。1=死石, 0=生存/空点
  /// throws StateError: ネイティブ側が未対応の場合
  List<int> getDeadStones(List<int> boardState, int boardSize) {
    final getDeadStones = _getDeadStones;
    if (getDeadStones == null) {
      throw StateError('fuego_get_dead_stones is not implemented by this native build');
    }

    final nativeBoard = malloc<ffi.Int32>(boardState.length);
    final deadStonesOut = malloc<ffi.Int32>(boardState.length);

    try {
      for (int i = 0; i < boardState.length; i++) {
        nativeBoard[i] = boardState[i];
      }
      getDeadStones(nativeBoard, boardSize, deadStonesOut);
      return List.generate(boardState.length, (i) => deadStonesOut[i]);
    } finally {
      malloc.free(nativeBoard);
      malloc.free(deadStonesOut);
    }
  }

  /// エンジンをクリーンアップ
  void cleanup() {
    _cleanup();
  }

  /// エンジンを破棄
  void dispose() {
    cleanup();
  }
}
