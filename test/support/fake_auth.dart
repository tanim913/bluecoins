import 'dart:async';

import 'package:bluecoins/data/auth.dart';

class FakeAuth implements AuthService {
  FakeAuth({this.fail});
  final _c = StreamController<CloudUser?>.broadcast();
  CloudUser? _user;
  final String? fail;
  int deleted = 0;

  @override
  CloudUser? get current => _user;

  @override
  Stream<CloudUser?> get changes => _c.stream;

  @override
  Future<CloudUser> signIn() async {
    if (fail != null) throw AuthFailure(fail!);
    _user = const CloudUser('u1', 'me@example.com');
    _c.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _c.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleted++;
    await signOut();
  }
}
