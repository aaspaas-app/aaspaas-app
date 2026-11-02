import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../app_state.dart';
import '../launch.dart';
import '../widgets/common.dart';
import 'area_picker.dart';
import 'auth_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  Future<void> _pickArea(BuildContext context) async {
    final app = AppScope.of(context);
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const AreaPickerScreen()),
    );
    if (id != null) await app.setArea(id);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final app = AppScope.of(context);
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes your account, your favorites and your reviews. If you own a business listing, it is removed too. This cannot be undone.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Type your password to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    try {
      await app.deleteAccount(password);
      if (context.mounted) toast(context, 'Your account was deleted.');
    } on ApiException catch (e) {
      if (context.mounted)
        toast(
          context,
          e.isNetwork ? 'You need internet to delete your account.' : e.message,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final u = app.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          if (u == null) ...[
            const SizedBox(height: 12),
            MessageView(
              icon: Icons.account_circle_outlined,
              title: 'Welcome to ${AppConfig.appName}',
              message: 'Log in to save favorites and write reviews.',
              actionLabel: 'Log in or sign up',
              onAction: () => requireLogin(context),
            ),
          ] else ...[
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  u.name.isEmpty ? '?' : u.name.characters.first.toUpperCase(),
                ),
              ),
              title: Text(
                u.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${u.email}\n${u.type == 'business'
                    ? 'Business account'
                    : u.type == 'admin'
                    ? 'Admin'
                    : 'Customer'}',
              ),
              isThreeLine: true,
            ),
            if (u.isBusiness)
              ListTile(
                leading: const Icon(Icons.storefront),
                title: const Text('Manage my business'),
                subtitle: const Text(
                  'Add or edit your listing, deals, holiday mode and jobs on the website',
                ),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openOrWarn(context, AppConfig.siteUrl),
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('My area'),
            subtitle: Text(app.areaLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickArea(context),
          ),
          ListTile(
            leading: const Icon(Icons.near_me_outlined),
            title: const Text('Use my location'),
            subtitle: Text(
              app.hasLocation
                  ? 'On. Nearest first sorting is available.'
                  : 'Off. Turn on to sort by distance.',
            ),
            onTap: () async {
              final err = await app.useMyLocation();
              if (context.mounted) toast(context, err ?? 'Location updated.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Open the website'),
            subtitle: Text(AppConfig.siteUrl),
            onTap: () => openOrWarn(context, AppConfig.siteUrl),
          ),
          if (u != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                await app.logout();
                if (context.mounted) toast(context, 'You are logged out.');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: cs.error),
              title: Text(
                'Delete my account',
                style: TextStyle(color: cs.error),
              ),
              onTap: () => _confirmDelete(context),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${AppConfig.appName} ${AppConfig.version}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
