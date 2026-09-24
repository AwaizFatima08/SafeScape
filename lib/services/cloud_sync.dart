// Cloud mirror of the device data (docs/design-review-v1.md L3-L7).
//
// The device file is the source of truth; this class only copies it to
// Firestore under users/{uid}/... Writes are fire-and-forget: Firestore queues
// them while offline. Nothing here is ever awaited by the child's screens.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Cloud data pulled for merging into the device.
class CloudSnapshot {
  final List<ChildProfile> children;
  final List<Routine> routines;
  final List<SensorySession> sessions;
  CloudSnapshot(this.children, this.routines, this.sessions);
}

abstract class CloudSync extends ChangeNotifier {
  bool get available;
  bool get signedIn;
  bool get isAnonymous;
  String? get email;
  String? get uid;

  /// Silent anonymous sign-in when nobody is signed in. Never throws.
  Future<void> ensureSignedIn();

  void upsertSettings(GlobalSettings s);
  void upsertChild(ChildProfile c);
  void deleteChild(String childId);
  void upsertRoutine(Routine r);
  void deleteRoutine(Routine r);
  void upsertSession(SensorySession s);

  /// Uploads everything (used when backup is switched on or after a merge).
  Future<void> pushAll(AppData data);

  Future<CloudSnapshot?> pullAll();

  /// Turns the anonymous account into an email account. Returns an error
  /// message for the parent, or null on success.
  Future<String?> linkEmail(String email, String password);

  /// Signs in to an existing account (e.g. on a new device). Returns an error
  /// message or null.
  Future<String?> signInEmail(String email, String password);

  Future<String?> sendPasswordReset(String email);

  Future<void> signOut();

  /// Deletes every cloud document and the account itself. Returns an error
  /// message or null. [password] re-authenticates email accounts if needed.
  Future<String?> deleteAccount({String? password});
}

/// Used when Firebase can't start (tests, no Play services).
class OfflineCloudSync extends CloudSync {
  @override
  bool get available => false;
  @override
  bool get signedIn => false;
  @override
  bool get isAnonymous => true;
  @override
  String? get email => null;
  @override
  String? get uid => null;
  @override
  Future<void> ensureSignedIn() async {}
  @override
  void upsertSettings(GlobalSettings s) {}
  @override
  void upsertChild(ChildProfile c) {}
  @override
  void deleteChild(String childId) {}
  @override
  void upsertRoutine(Routine r) {}
  @override
  void deleteRoutine(Routine r) {}
  @override
  void upsertSession(SensorySession s) {}
  @override
  Future<void> pushAll(AppData data) async {}
  @override
  Future<CloudSnapshot?> pullAll() async => null;
  static const _msg = 'Cloud backup is not available on this device right now.';
  @override
  Future<String?> linkEmail(String email, String password) async => _msg;
  @override
  Future<String?> signInEmail(String email, String password) async => _msg;
  @override
  Future<String?> sendPasswordReset(String email) async => _msg;
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> deleteAccount({String? password}) async => null;
}

class FirebaseCloudSync extends CloudSync {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  StreamSubscription<User?>? _sub;

  FirebaseCloudSync({required this.auth, required this.db}) {
    _sub = auth.authStateChanges().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  User? get _user => auth.currentUser;
  @override
  bool get available => true;
  @override
  bool get signedIn => _user != null;
  @override
  bool get isAnonymous => _user?.isAnonymous ?? true;
  @override
  String? get email => _user?.email;
  @override
  String? get uid => _user?.uid;

  DocumentReference<Map<String, dynamic>>? get _root =>
      _user == null ? null : db.collection('users').doc(_user!.uid);

  CollectionReference<Map<String, dynamic>> _children(DocumentReference<Map<String, dynamic>> root) =>
      root.collection('children');

  @override
  Future<void> ensureSignedIn() async {
    if (_user != null) return;
    try {
      await auth.signInAnonymously().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Anonymous sign-in failed (offline?): $e');
    }
  }

  void _write(Future<void> Function() op) {
    if (_user == null) return;
    op().catchError((Object e) => debugPrint('Cloud write failed: $e'));
  }

  @override
  void upsertSettings(GlobalSettings s) => _write(() async {
    final u = _user!;
    await _root!.set({
      'global_settings': s.toJson(),
      'is_anonymous': u.isAnonymous,
      'last_login': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  @override
  void upsertChild(ChildProfile c) =>
      _write(() => _children(_root!).doc(c.id).set(c.toJson()));

  @override
  void deleteChild(String childId) => _write(() async {
    final doc = _children(_root!).doc(childId);
    await _deleteCollection(doc.collection('routines'));
    await _deleteCollection(doc.collection('sessions'));
    await doc.delete();
  });

  @override
  void upsertRoutine(Routine r) => _write(
    () => _children(_root!).doc(r.childId).collection('routines').doc(r.id).set(r.toJson(forCloud: true)),
  );

  @override
  void deleteRoutine(Routine r) => _write(
    () => _children(_root!).doc(r.childId).collection('routines').doc(r.id).delete(),
  );

  @override
  void upsertSession(SensorySession s) => _write(
    () => _children(_root!).doc(s.childId).collection('sessions').doc(s.id).set(s.toJson()),
  );

  @override
  Future<void> pushAll(AppData data) async {
    await ensureSignedIn();
    final root = _root;
    if (root == null) return;
    try {
      upsertSettings(data.settings);
      // Firestore batches hold at most 500 writes.
      var batch = db.batch();
      var n = 0;
      Future<void> add(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> v) async {
        batch.set(ref, v);
        if (++n == 450) {
          await batch.commit();
          batch = db.batch();
          n = 0;
        }
      }

      for (final c in data.children) {
        await add(_children(root).doc(c.id), c.toJson());
      }
      for (final r in data.routines) {
        await add(_children(root).doc(r.childId).collection('routines').doc(r.id), r.toJson(forCloud: true));
      }
      for (final s in data.sessions) {
        await add(_children(root).doc(s.childId).collection('sessions').doc(s.id), s.toJson());
      }
      if (n > 0) await batch.commit();
    } catch (e) {
      debugPrint('pushAll failed: $e');
    }
  }

  @override
  Future<CloudSnapshot?> pullAll() async {
    final root = _root;
    if (root == null) return null;
    try {
      final kids = await _children(root).get();
      final children = <ChildProfile>[];
      final routines = <Routine>[];
      final sessions = <SensorySession>[];
      for (final k in kids.docs) {
        children.add(ChildProfile.fromJson(k.data()));
        final rs = await k.reference.collection('routines').get();
        routines.addAll(rs.docs.map((d) => Routine.fromJson(d.data())));
        final ss = await k.reference.collection('sessions').get();
        sessions.addAll(ss.docs.map((d) => SensorySession.fromJson(d.data())));
      }
      return CloudSnapshot(children, routines, sessions);
    } catch (e) {
      debugPrint('pullAll failed: $e');
      return null;
    }
  }

  static String _authMessage(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'email-already-in-use' || 'credential-already-in-use' =>
          'That email already has an account. Use "Sign in to an existing account" instead.',
        'invalid-email' => 'That email address doesn\'t look right.',
        'weak-password' => 'Please choose a password with at least 6 characters.',
        'wrong-password' || 'invalid-credential' || 'user-not-found' =>
          'Email or password is not correct.',
        'network-request-failed' => 'No internet connection. Please try again when online.',
        'too-many-requests' => 'Too many tries. Please wait a few minutes.',
        'requires-recent-login' => 'Please enter your password to confirm.',
        _ => e.message ?? 'Something went wrong (${e.code}).',
      };
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<String?> linkEmail(String email, String password) async {
    try {
      await ensureSignedIn();
      final u = _user;
      if (u == null) return 'No internet connection. Please try again when online.';
      await u.linkWithCredential(EmailAuthProvider.credential(email: email.trim(), password: password));
      await _root?.set({'is_anonymous': false}, SetOptions(merge: true));
      notifyListeners();
      return null;
    } catch (e) {
      return _authMessage(e);
    }
  }

  @override
  Future<String?> signInEmail(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      notifyListeners();
      return null;
    } catch (e) {
      return _authMessage(e);
    }
  }

  @override
  Future<String?> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } catch (e) {
      return _authMessage(e);
    }
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    notifyListeners();
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final snap = await col.limit(300).get();
      if (snap.docs.isEmpty) return;
      final batch = db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<String?> deleteAccount({String? password}) async {
    final u = _user;
    if (u == null) return null;
    try {
      if (!u.isAnonymous && password != null && u.email != null) {
        await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
      }
      final root = _root!;
      final kids = await _children(root).get();
      for (final k in kids.docs) {
        await _deleteCollection(k.reference.collection('routines'));
        await _deleteCollection(k.reference.collection('sessions'));
        await k.reference.delete();
      }
      await root.delete();
      await u.delete();
      notifyListeners();
      return null;
    } catch (e) {
      return _authMessage(e);
    }
  }
}
