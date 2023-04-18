import 'dart:typed_data';
import 'heap_array_base.dart';

class Secp256k1Exception implements Exception {
  final String what;
  Secp256k1Exception(this.what);
  @override
  String toString() => what;
}

abstract class Secp256k1Base<
  CtxPtr, HeapArrayPtr, PubKeyPtr, SizeTPtr, SignaturePtr, NullPtr
> {

  static const contextNone = 1;
  static const compressedFlags = 258;
  static const uncompressedFlags = 2;
  static const privkeySize = 32;
  static const hashSize = 32;
  static const pubkeySize = 64;
  static const compressedPubkeySize = 33;
  static const uncompressedPubkeySize = 65;
  static const sigSize = 64;

  // Functions
  late int Function(CtxPtr, HeapArrayPtr) extEcSeckeyVerify;
  late int Function(CtxPtr, PubKeyPtr, HeapArrayPtr) extEcPubkeyCreate;
  late int Function(
    CtxPtr, HeapArrayPtr, SizeTPtr, PubKeyPtr, int,
  ) extEcPubkeySerialize;
  late int Function(
    CtxPtr, SignaturePtr, HeapArrayPtr, HeapArrayPtr, NullPtr, NullPtr,
  ) extEcdsaSign;
  late int Function(
    CtxPtr, HeapArrayPtr, SignaturePtr,
  ) extEcdsaSignatureSerializeCompact;

  // Heap arrays
  late HeapArrayBase privKeyArray;
  late HeapArrayBase serializedPubKeyArray;
  late HeapArrayBase hashArray;
  late HeapArrayBase serializedSigArray;

  // Other pointers
  late CtxPtr ctxPtr;
  late PubKeyPtr pubKeyPtr;
  late SizeTPtr sizeTPtr;
  late SignaturePtr sigPtr;
  late NullPtr nullPtr;

  // This may be overriden by the subclass to load the library asynchronously
  Future<void> internalLoad() async {}

  bool _loaded = false;
  _requireLoad() {
    if (!_loaded) throw Secp256k1Exception("load() not called");
  }

  /// Asynchronously load the library. `await` must be used to ensure the
  /// library is loaded. Must be called before other methods are available.
  Future<void> load() async {
    if (_loaded) return;
    await internalLoad();
    _loaded = true;
  }

  /// Returns true if a 32-byte [privKey] is valid.
  bool privKeyVerify(Uint8List privKey) {
    _requireLoad();
    privKeyArray.load(privKey);
    return extEcSeckeyVerify(ctxPtr, privKeyArray.ptr) == 1;
  }

  /// Converts a 32-byte [privKey] into a either a 33-byte compressed or a
  /// 65-byte uncompressed public key.
  Uint8List privToPubKey(Uint8List privKey, bool compressed) {
    _requireLoad();

    privKeyArray.load(privKey);

    // Derive public key from private key
    if (extEcPubkeyCreate(ctxPtr, pubKeyPtr, privKeyArray.ptr) != 1) {
      throw Secp256k1Exception("Cannot compute public key from private key");
    }

    // Parse public key

    int size = sizeT = compressed
      ? Secp256k1Base.compressedPubkeySize
      : Secp256k1Base.uncompressedPubkeySize;

    final flags = compressed
      ? Secp256k1Base.compressedFlags
      : Secp256k1Base.uncompressedFlags;

    extEcPubkeySerialize(
      ctxPtr, serializedPubKeyArray.ptr, sizeTPtr, pubKeyPtr, flags,
    );

    // Return copy of public key
    return serializedPubKeyArray.list.sublist(0, size);

  }

  /// Constructs a signature in the compact format using a 32-byte message
  /// [hash] and 32-byte [privKey] scalar. The signature contains a 32-byte
  /// big-endian R value followed by a 32-byte big-endian low-S value.
  /// Signatures are deterministic according to RFC6979.
  Uint8List ecdsaSign(Uint8List hash, Uint8List privKey) {
    _requireLoad();

    privKeyArray.load(privKey);
    hashArray.load(hash);

    // Sign
    if (
      extEcdsaSign(
        ctxPtr, sigPtr, hashArray.ptr, privKeyArray.ptr, nullPtr, nullPtr,
      ) != 1
    ) {
      throw Secp256k1Exception("Cannot sign message with private key");
    }

    // Serialize
    extEcdsaSignatureSerializeCompact(ctxPtr, serializedSigArray.ptr, sigPtr);

    return serializedSigArray.list.sublist(0, Secp256k1Base.sigSize);

  }

  /// Specialised sub-classes should override to set the value behind the
  /// sizeTPtr
  set sizeT(int size);

}
