import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import 'app_snackbar.dart';

class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key, required this.authService});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final service = authService;
    final user = service?.currentUser;
    if (service == null || user == null) return const SizedBox.shrink();

    final name = user.displayName?.trim();
    final displayName = name == null || name.isEmpty ? user.email ?? '' : name;
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      icon: Icon(Icons.account_circle_outlined, color: AppTheme.muted(context)),
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.title(
                    fontSize: 13,
                    color: AppTheme.onCanvas(context),
                  ),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: 11,
                      color: AppTheme.muted(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_AccountAction>(
          value: _AccountAction.signOut,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      onSelected: (action) {
        if (action == _AccountAction.signOut) {
          _confirmSignOut(context, service, displayName);
        }
      },
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService service,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text('Sign out of $displayName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final email = service.currentUser?.email?.trim();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('hasAccount', true);
      if (email != null && email.isNotEmpty) {
        await preferences.setString('lastEmail', email);
      }
    } catch (error) {
      debugPrint('Could not save account details before sign-out: $error');
    }

    try {
      await service.signOut();
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, AuthService.friendlyErrorMessage(error));
      }
    }
  }
}

enum _AccountAction { signOut }
