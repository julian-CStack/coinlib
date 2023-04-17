import 'dart:typed_data';

import 'package:coinlib/coinlib.dart';
import 'package:coinlib/src/common/hex.dart';
import 'package:test/test.dart';
import '../vectors/keys.dart';

void main() {

  group("ECPrivateKey", () {

    setUpAll(loadCoinlib);

    test("requires 32 bytes", () {

      for (final failing in [
        // Too small
        "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e",
        // Too large
        "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
      ]) {
        expect(
          () => ECPrivateKey.fromHex(failing),
          throwsA(isA<ArgumentError>()),
        );
      }

    });

    test("requires key is within 1 to order-1", () {

      for (final failing in [
        "0000000000000000000000000000000000000000000000000000000000000000",
        "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
      ]) {
        expect(
          () => ECPrivateKey.fromHex(failing),
          throwsA(isA<InvalidPrivateKey>()),
        );
      }

    });

    group(".fromWif", () {

      test("constructs corresponding private key", () {
        for (final vector in keyPairVectors) {

          expectAsVector(ECPrivateKey key) {
            expect(key.data, hexToBytes(vector.private));
            expect(key.compressed, vector.compressed);
          }

          expectAsVector(ECPrivateKey.fromWif(vector.wif));
          expectAsVector(ECPrivateKey.fromWif(vector.wif, version: vector.version));

        }
      });

      test("throws InvalidWif for incorrect format", () {

        for (final failing in [
          // Wrong final byte for compressed
          "KwFfpDsaF7yxCELuyrH9gP5XL7TAt5b9HPWC1xCQbmrxvhUSDecD",
          // Too small
          "yNgx2GS4gtpsqofv9mu8xN4ajx5hvs67v88NDsDNeBPzC3yfR",
          // Too large
          "2SaTkKRpDjKpNcZttqvWHJpSxsMUWcTFhZLKqdCdMAV1XrGkPFT2g6",
        ]) {
          expect(
            () => ECPrivateKey.fromWif(failing),
            throwsA(isA<InvalidWif>()),
          );
        }

      });

      test("throws WifVersionMismatch for wrong version", () {
        for (final vector in keyPairVectors) {
          expect(
            () => ECPrivateKey.fromWif(
              vector.wif, version: (vector.version+1) % 0xff,
            ),
            throwsA(isA<WifVersionMismatch>()),
          );
        }
      });

    });

    test(".generate() gives new key each time", () {
      final key1 = ECPrivateKey.generate();
      final key2 = ECPrivateKey.generate(compressed: false);
      expect(key1.compressed, true);
      expect(key2.compressed, false);
      expect(key1.data, isNot(equals(key2.data)));
    });

    test(".data", () {
      for (final vector in keyPairVectors) {
        expect(bytesToHex(vector.privateObj.data), vector.private);
      }
    });

    test(".compressed", () {
      for (final vector in keyPairVectors) {
        expect(vector.privateObj.compressed, vector.compressed);
      }
    });

    test(".pubkey", () {
      for (final vector in keyPairVectors) {
        // Should work twice with cache
        for (int i = 0; i < 2; i++) {
          expect(vector.privateObj.pubkey.hex, vector.public);
        }
      }
    });

    group(".signEcdsa()", () {

      late ECPrivateKey key, keyMutated1, keyMutated2;
      late Uint8List msgHash, msgMutated1, msgMutated2;

      setUpAll(() {
        key = ECPrivateKey.fromHex(
          "0000000000000000000000000000000000000000000000000000000000000001",
        );
        keyMutated1 = ECPrivateKey.fromHex(
          "0000000000000000000000000000000000000000000000000000000000000002",
        );
        keyMutated2 = ECPrivateKey.fromHex(
          "8000000000000000000000000000000000000000000000000000000000000001",
        );
        msgHash = hexToBytes(
          "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
        );
        msgMutated1 = msgHash.sublist(0);
        msgMutated1[31] = 0x1e;
        msgMutated2 = msgHash.sublist(0);
        msgMutated2[0] = 0x01;
      });

      test("provides a correct signature", () {
        // This signature has been determined to be correct. secp256k1 has more
        // exhaustive tests and this method is a wrapper around that.
        // Should be the same each time
        for (int x = 0; x < 2; x++) {
          expect(
            bytesToHex(key.signEcdsa(msgHash).compact),
            "a951b0cf98bd51c614c802a65a418fa42482dc5c45c9394e39c0d98773c51cd530104fdc36d91582b5757e1de73d982e803cc14d75e82c65daf924e38d27d834",
          );
        }
      });

      test("slight change in hash gives different signatures", () {

        final sig1 = key.signEcdsa(msgHash).compact;
        final sig2 = key.signEcdsa(msgMutated1).compact;
        final sig3 = key.signEcdsa(msgMutated2).compact;

        expect(sig1, isNot(equals(sig2)));
        expect(sig1, isNot(equals(sig3)));
        expect(sig2, isNot(equals(sig3)));

      });

      test("slight change in private key gives different signatures", () {

        final sig1 = key.signEcdsa(msgHash).compact;
        final sig2 = keyMutated1.signEcdsa(msgHash).compact;
        final sig3 = keyMutated2.signEcdsa(msgHash).compact;

        expect(sig1, isNot(equals(sig2)));
        expect(sig1, isNot(equals(sig3)));
        expect(sig2, isNot(equals(sig3)));

      });

    });

  });

}
