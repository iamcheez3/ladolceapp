import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import '../services/app_update_service.dart';

/// The update dialogs: offer → download progress → Android installer.
class AppUpdateFlow {
  static bool _checkedThisRun = false;
  static bool _busy = false;

  /// Quiet check when the POS opens (once per app start): only speaks up when
  /// a newer build is on the server.
  static Future<void> checkOnStart(BuildContext context) async {
    if (_checkedThisRun || !AppUpdateService.isSupported) return;
    _checkedThisRun = true;
    try {
      final service = AppUpdateService();
      // The app restarted, so an earlier download is installed or unwanted.
      await service.deleteDownloads();
      final release = await service.availableUpdate();
      if (release == null || !context.mounted) return;
      await _offer(context, service, release);
    } catch (_) {
      // Offline or old server without the endpoint: try again next start.
    }
  }

  /// Settings → App update: always answers, "up to date" included.
  static Future<void> checkManually(BuildContext context) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(l10n?.appUpdateChecking ?? 'Checking for updates…'),
      duration: const Duration(seconds: 2),
    ));
    try {
      final service = AppUpdateService();
      final release = await service.availableUpdate();
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      if (release == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n?.appUpdateLatest ?? 'You have the latest version.'),
          backgroundColor: Colors.green,
        ));
        return;
      }
      await _offer(context, service, release);
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n?.appUpdateFailed('$e') ?? 'Update failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  static Future<void> _offer(
    BuildContext context,
    AppUpdateService service,
    AppRelease release,
  ) async {
    final l10n = AppLocalizations.of(context);
    final installed = await service.installedVersion();
    if (!context.mounted) return;
    final sizeMb = (release.size / (1024 * 1024)).toStringAsFixed(0);
    final current = installed?.toString() ?? '?';
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: !release.force,
      builder: (ctx) => PopScope(
        canPop: !release.force,
        child: AlertDialog(
          icon: const Icon(Icons.system_update_rounded, size: 40),
          title: Text(l10n?.appUpdateAvailableTitle ?? 'New version available'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n?.appUpdateAvailableBody(
                        '${release.version} (${release.build})', sizeMb, current) ??
                    'Version ${release.version} (${release.build}) is ready ($sizeMb MB). '
                        'This tablet has $current.'),
                if (release.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(l10n?.appUpdateWhatsNew ?? "What's new",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(release.notes.trim()),
                ],
                if (release.force) ...[
                  const SizedBox(height: 14),
                  Text(l10n?.appUpdateRequired ?? 'This update is required.',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          actions: [
            if (!release.force)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n?.appUpdateLater ?? 'Later'),
              ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n?.appUpdateNow ?? 'Update'),
            ),
          ],
        ),
      ),
    );
    if (go == true && context.mounted) {
      await _downloadAndInstall(context, service, release);
    }
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    AppUpdateService service,
    AppRelease release,
  ) async {
    if (_busy) return;
    _busy = true;
    final l10n = AppLocalizations.of(context);
    final progress = ValueNotifier<double?>(null);
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n?.appUpdateDownloading ?? 'Downloading update…'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value, minHeight: 8),
                const SizedBox(height: 10),
                Text(value == null ? '' : '${(value * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
      ),
    );
    // Close the progress dialog once only: a second pop closed the screen
    // underneath (POS or Settings) when the install step failed.
    var progressOpen = true;
    void closeProgress() {
      if (progressOpen) {
        progressOpen = false;
        navigator.pop();
      }
    }

    try {
      final path = await service.download(
        release,
        onProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
      closeProgress();
      if (!context.mounted) return;
      await _install(context, service, release, path);
    } catch (e) {
      closeProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n?.appUpdateFailed('$e') ?? 'Update failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      _busy = false;
      progress.dispose();
    }
  }

  /// Opens Android's installer. The first time, Android needs "Install
  /// unknown apps" switched on for LaDolce: explain, open that screen, and
  /// let staff tap Install when they are back.
  static Future<void> _install(
    BuildContext context,
    AppUpdateService service,
    AppRelease release,
    String path,
  ) async {
    final l10n = AppLocalizations.of(context);
    while (context.mounted && !await service.canInstall()) {
      if (!context.mounted) return;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: !release.force,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.security_update_good_rounded, size: 40),
          title: Text(l10n?.appUpdateAllowTitle ?? 'Allow app updates'),
          content: Text(l10n?.appUpdateAllowBody ??
              'Android asks once: turn on "Allow from this source" for LaDolce, '
                  'then come back and tap Install.'),
          actions: [
            if (!release.force)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'later'),
                child: Text(l10n?.appUpdateLater ?? 'Later'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'settings'),
              child: Text(l10n?.appUpdateOpenSettings ?? 'Open settings'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'install'),
              child: Text(l10n?.appUpdateInstall ?? 'Install'),
            ),
          ],
        ),
      );
      if (action == 'settings') {
        await service.openInstallSettings();
      } else if (action != 'install') {
        return; // later
      }
    }
    if (!context.mounted) return;
    await service.install(path);
  }
}
