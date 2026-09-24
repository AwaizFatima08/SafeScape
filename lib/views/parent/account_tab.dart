// Backup & account (PDD Q2, L5-L7): cloud backup switch, optional email
// linking, sign-in on a new device, sign-out and full deletion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

const privacyUrl = 'https://safescape-homilabs.web.app/privacy';
const deletionUrl = 'https://safescape-homilabs.web.app/delete-account';

class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});
  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  bool _busy = false;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));

  Future<(String, String)?> _credentials({required String title, required String action, String? note}) async {
    final email = TextEditingController();
    final pass = TextEditingController();
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (note != null) ...[Text(note, style: const TextStyle(color: SC.textDim)), const SizedBox(height: 12)],
            TextField(
              key: const ValueKey('acct_email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Parent email'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('acct_password'),
              controller: pass,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password (6+ characters)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('acct_submit'),
            onPressed: () => Navigator.pop(context, (email.text.trim(), pass.text)),
            child: Text(action),
          ),
        ],
      ),
    );
    email.dispose();
    pass.dispose();
    if (res == null || res.$1.isEmpty || res.$2.isEmpty) return null;
    return res;
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    final c = await _credentials(
      title: 'Save progress with an email',
      action: 'Save',
      note: 'Use this email and password on a new phone or tablet to bring back all settings, routines and progress.',
    );
    if (c == null) return;
    await _run(() async {
      final store = ref.read(storeProvider);
      final cloud = ref.read(cloudProvider);
      final err = await cloud.linkEmail(c.$1, c.$2);
      if (err != null) return _toast(err);
      if (!store.settings.cloudBackup) await store.setCloudBackup(true);
      await cloud.pushAll(store.data);
      _toast('Saved. Progress is now linked to ${c.$1}.');
    });
  }

  Future<void> _signIn() async {
    final c = await _credentials(
      title: 'Sign in to an existing account',
      action: 'Sign in',
      note: 'Children, routines and progress from that account are added to this device, '
          'and anything on this device is added to the account.',
    );
    if (c == null) return;
    await _run(() async {
      final store = ref.read(storeProvider);
      final cloud = ref.read(cloudProvider);
      final err = await cloud.signInEmail(c.$1, c.$2);
      if (err != null) return _toast(err);
      final snap = await cloud.pullAll();
      if (snap != null) store.mergeFrom(snap);
      store.data.settings.cloudBackup = true;
      await store.flush();
      await cloud.pushAll(store.data);
      _toast(snap == null ? 'Signed in. (Could not load the cloud copy yet; it will sync later.)' : 'Signed in and synced.');
    });
  }

  Future<void> _reset() async {
    final c = await _credentials(title: 'Reset password', action: 'Send email', note: 'Enter your email; leave any password.');
    if (c == null) return;
    final err = await ref.read(cloudProvider).sendPasswordReset(c.$1);
    _toast(err ?? 'Password reset email sent to ${c.$1}.');
  }

  Future<void> _signOut() async {
    final ok = await _confirm('Sign out of this device?',
        'Everything is removed from this device but stays in your account. Sign in again to bring it back.', 'Sign out');
    if (!ok) return;
    await _run(() async {
      await ref.read(cloudProvider).signOut();
      await ref.read(storeProvider).wipe();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  Future<void> _delete() async {
    final cloud = ref.read(cloudProvider);
    final ok = await _confirm(
      'Delete everything?',
      'This permanently deletes all children, routines, photos and progress from this device'
          '${cloud.signedIn ? ' and from the cloud backup, and closes the account' : ''}. This cannot be undone.',
      'Delete everything',
    );
    if (!ok) return;
    String? password;
    if (cloud.signedIn && !cloud.isAnonymous) {
      final c = await _credentials(title: 'Confirm with your password', action: 'Delete', note: cloud.email);
      if (c == null) return;
      password = c.$2;
    }
    await _run(() async {
      final err = await cloud.deleteAccount(password: password);
      if (err != null) return _toast(err);
      await ref.read(storeProvider).wipe();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(key: const ValueKey('confirm'), onPressed: () => Navigator.pop(c, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final cloud = ref.watch(cloudProvider);
    final linked = cloud.signedIn && !cloud.isAnonymous;
    final status = !cloud.available
        ? 'Cloud backup is not available on this device.'
        : !store.settings.cloudBackup
            ? 'Off. Everything stays on this device only.'
            : linked
                ? 'On, linked to ${cloud.email}.'
                : cloud.signedIn
                    ? 'On, as a private guest. Add an email so you can restore on a new device.'
                    : 'On. Waiting for an internet connection.';

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_busy) const LinearProgressIndicator(),
          const SectionTitle('Cloud backup'),
          Card(
            child: SwitchListTile(
              key: const ValueKey('cloud_switch'),
              title: const Text('Private cloud backup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              subtitle: Text(status, style: const TextStyle(color: SC.textDim)),
              value: store.settings.cloudBackup,
              onChanged: !cloud.available ? null : (v) => _run(() => store.setCloudBackup(v)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text('Backed up: nicknames, age groups, settings, routines (without photos) and activity times. '
                'Never uploaded: photos, audio, location or contacts.',
                style: TextStyle(color: SC.textDim)),
          ),
          const SectionTitle('Account'),
          if (!linked)
            _ActionTile(
              key: const ValueKey('link_email'),
              icon: Icons.cloud_upload_rounded,
              title: 'Save progress with an email',
              subtitle: 'Optional. Lets you restore everything on a new device.',
              onTap: cloud.available ? _link : null,
            ),
          if (!linked)
            _ActionTile(
              key: const ValueKey('sign_in'),
              icon: Icons.login_rounded,
              title: 'Sign in to an existing account',
              subtitle: 'Moving to a new phone or tablet? Bring your children\'s progress back.',
              onTap: cloud.available ? _signIn : null,
            ),
          if (!linked)
            _ActionTile(icon: Icons.key_rounded, title: 'Forgot password', onTap: cloud.available ? _reset : null),
          if (linked)
            _ActionTile(key: const ValueKey('sign_out'), icon: Icons.logout_rounded, title: 'Sign out of this device', onTap: _signOut),
          _ActionTile(
            key: const ValueKey('delete_all'),
            icon: Icons.delete_forever_rounded,
            color: SC.peach,
            title: cloud.signedIn ? 'Delete account and all cloud data' : 'Erase all data on this device',
            subtitle: 'Permanently removes everything.',
            onTap: _delete,
          ),
          if (cloud.signedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: SelectableText('Account ID: ${cloud.uid}', style: const TextStyle(color: SC.textDim, fontSize: 13)),
            ),
          const SectionTitle('About'),
          _ActionTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy policy',
            onTap: () => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication),
          ),
          _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'Sensory SafeScape 1.0',
            subtitle: 'Calm sensory play and visual routines. An educational tool, not a medical device. '
                'Pictograms: Noto Emoji (Apache 2.0). Font: Andika (SIL OFL).',
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;
  const _ActionTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.color = SC.lavender});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon, color: color, size: 30),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: SC.textDim)),
      onTap: onTap,
    ),
  );
}
