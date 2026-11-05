import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

// Same Argon2id v1.3 + RFC5869 derivation as the Necsoura auth service.
String deriveAuthKey(Map<String, dynamic> input) {
  final k = Map<String, dynamic>.from(input['kdf'] as Map);
  final salt = base64Decode(k['salt'] as String);
  final memory = k['memory'] as int,
      iterations = k['iterations'] as int,
      lanes = k['parallelism'] as int;
  if (k['algorithm'] != 'argon2id' ||
      salt.length < 16 ||
      salt.length > 64 ||
      memory < 19456 ||
      memory > 262144 ||
      iterations < 2 ||
      iterations > 10 ||
      lanes < 1 ||
      lanes > 4) {
    throw const FormatException('Неподдерживаемые параметры входа');
  }
  final generator = Argon2BytesGenerator()
    ..init(Argon2Parameters(Argon2Parameters.ARGON2_id, salt,
        desiredKeyLength: 32,
        iterations: iterations,
        memory: memory,
        lanes: lanes));
  final master = generator
      .process(Uint8List.fromList(utf8.encode(input['password'] as String)));
  final prk = Hmac(sha256, Uint8List(32)).convert(master).bytes;
  final key =
      Hmac(sha256, prk).convert([...utf8.encode('necsoura-auth-v1'), 1]).bytes;
  master.fillRange(0, master.length, 0);
  return base64Encode(key);
}
