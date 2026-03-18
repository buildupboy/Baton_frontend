import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _kAccess = 'auth.accessToken';
  static const _kRefresh = 'auth.refreshToken';

  Future<TokenPair?> read() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    if (access == null || access.isEmpty) return null;
    return TokenPair(accessToken: access, refreshToken: refresh ?? '');
  }

  Future<void> write(TokenPair pair) async {
    await _storage.write(key: _kAccess, value: pair.accessToken);
    await _storage.write(key: _kRefresh, value: pair.refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

