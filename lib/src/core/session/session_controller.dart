import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/token_storage.dart';

class SessionState {
  const SessionState({required this.tokenPair});
  final TokenPair? tokenPair;

  bool get isLoggedIn => tokenPair?.accessToken.isNotEmpty == true;
}

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(_secureStorageProvider));
});

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    _load();
    return const SessionState(tokenPair: null);
  }

  Future<void> _load() async {
    final pair = await ref.read(tokenStorageProvider).read();
    state = SessionState(tokenPair: pair);
  }

  Future<void> setTokens(TokenPair pair) async {
    await ref.read(tokenStorageProvider).write(pair);
    state = SessionState(tokenPair: pair);
  }

  Future<void> clear() async {
    await ref.read(tokenStorageProvider).clear();
    state = const SessionState(tokenPair: null);
  }
}

