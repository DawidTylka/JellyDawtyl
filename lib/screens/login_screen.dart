import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/jellyfin_api.dart';
import '../services/playback_sync_service.dart';
import '../services/server_certificate_trust.dart';
import '../services/storage_service.dart';
import '../utils/server_url.dart';
import 'downloads_screen.dart';
import 'library_selector_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialUrl;
  const LoginScreen({super.key, this.initialUrl});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _urlController;
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _api = JellyfinApi();
  bool _isLoading = false;
  bool _trustInvalidCertificate = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _trustInvalidCertificate = ServerCertificateTrust.trustsAddress(
      _urlController.text,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _setCertificateTrust(bool trusted) async {
    final previousValue = _trustInvalidCertificate;
    setState(() => _trustInvalidCertificate = trusted);
    try {
      await ServerCertificateTrust.setAddressTrusted(
        storage: StorageService(),
        address: _urlController.text,
        trusted: trusted,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _trustInvalidCertificate = previousValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.certificateTrustSaveError,
            ),
          ),
        );
      }
    }
  }

  void _onServerAddressChanged(String value) {
    final trusted = ServerCertificateTrust.trustsAddress(value);
    // Rebuild also for the certificate checkbox and the plain-HTTP warning.
    setState(() => _trustInvalidCertificate = trusted);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = normalizeServerUrl(_urlController.text);
    final username = _userController.text.trim();
    if (serverUrl.isEmpty ||
        Uri.tryParse(serverUrl)?.host.isEmpty != false ||
        username.isEmpty) {
      _showError(l10n.enterServerAndUsername);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _api.loginWithResult(
      serverUrl,
      username,
      _passController.text,
    );
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showError(switch (result.failure!) {
        LoginFailure.invalidCredentials => l10n.invalidLoginOrPassword,
        LoginFailure.unreachable => l10n.connectionError(serverUrl),
        LoginFailure.certificate => l10n.loginCertificateError,
        LoginFailure.server => l10n.loginServerError,
      });
      return;
    }

    final data = result.data!;
    final token = data['AccessToken'] as String;
    final userId = (data['User'] as Map)['Id'] as String;
    _passController.clear();
    await StorageService().saveCredentials(serverUrl, token, userId);
    PlaybackSyncService.instance.onCredentialsChanged();
    final libs = await _api.fetchUserLibraries(serverUrl, token, userId);

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LibrarySelectorScreen(
          libraries: libs,
          baseUrl: serverUrl,
          token: token,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isWide ? 32 : 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(isWide ? 28 : 20),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.live_tv_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.welcome,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.loginSubTitle,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _urlController,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              onChanged: _onServerAddressChanged,
                              decoration: InputDecoration(
                                labelText: l10n.serverAddress,
                                hintText: l10n.serverAddressHint,
                                prefixIcon: const Icon(Icons.link_rounded),
                              ),
                            ),
                            if (isInsecurePublicAddress(
                              _urlController.text,
                            )) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orangeAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.insecureHttpWarning,
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (ServerCertificateTrust.addressUsesHttps(
                              _urlController.text,
                            )) ...[
                              const SizedBox(height: 4),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _trustInvalidCertificate,
                                onChanged: _isLoading
                                    ? null
                                    : (value) =>
                                          _setCertificateTrust(value ?? false),
                                title: Text(l10n.trustCertificateTitle),
                                subtitle: Text(l10n.trustCertificateSub),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextField(
                              controller: _userController,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: InputDecoration(
                                labelText: l10n.username,
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) {
                                if (!_isLoading) _handleLogin();
                              },
                              decoration: InputDecoration(
                                labelText: l10n.password,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton(
                                      onPressed: _handleLogin,
                                      child: Text(l10n.loginButton),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.download_done_rounded),
                                label: Text(l10n.offlineFiles),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DownloadsScreen(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
