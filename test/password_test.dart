import 'package:flutter_test/flutter_test.dart';
import 'package:keep_pixel/core/password.dart';

void main() {
  test(
      'Necsoura key matches independent hash-wasm Argon2id and Node HKDF vector, including Unicode',
      () {
    expect(
        deriveAuthKey({
          'password': 'пароль 🔑',
          'kdf': {
            'algorithm': 'argon2id',
            'memory': 19456,
            'iterations': 2,
            'parallelism': 1,
            'salt': 'AAECAwQFBgcICQoLDA0ODw=='
          }
        }),
        't6VWDvyt30L3lnE3OKfXmgPbRtNs0drLEC/YhAT28cA=');
  });
  test('untrusted server KDF parameters cannot request unbounded resources',
      () {
    expect(
        () => deriveAuthKey({
              'password': 'x',
              'kdf': {
                'algorithm': 'argon2id',
                'memory': 1073741824,
                'iterations': 2,
                'parallelism': 1,
                'salt': 'AAECAwQFBgcICQoLDA0ODw=='
              }
            }),
        throwsFormatException);
  });
}
