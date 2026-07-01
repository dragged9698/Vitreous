import 'dart:async';

import 'package:flutter/material.dart';
import 'package:emby_player/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../connection/connection.dart';
import '../../exceptions/media_server_exceptions.dart';
import '../../focus/card_focus_scope.dart';
import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../focus/focusable_wrapper.dart';
import '../../i18n/strings.g.dart';
import '../../mixins/controller_disposer_mixin.dart';
import '../../profiles/active_profile_binder.dart';
import '../../profiles/active_profile_provider.dart';
import '../../profiles/profile.dart';
import '../../profiles/profile_connection.dart';
import '../../profiles/profile_registry.dart';
import '../../services/emby_auth_service.dart';
import '../../services/emby_endpoint_discovery.dart';
import '../../services/emby_lan_discovery_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../profile/profile_switch_screen.dart';
import 'async_form_state_mixin.dart';
import 'connection_persistence.dart';
import '../../widgets/loading_indicator_box.dart';

@visibleForTesting
bool shouldCreateLocalEmbyProfile({
  required Profile? targetProfile,
  required Profile? activeProfile,
  required bool hasProfiles,
}) {
  return targetProfile == null && activeProfile == null && !hasProfiles;
}

@visibleForTesting
bool shouldPromptForEmbyProfileSelection({
  required Profile? targetProfile,
  required Profile? activeProfile,
  required bool hasProfiles,
}) {
  return targetProfile == null && activeProfile == null && hasProfiles;
}

/// Three-step form to add a Emby server:
///   1. Probe URL candidates (`/System/Info/Public`).
///   2. Username + password (`/Users/AuthenticateByName`) **or** Quick Connect
///      (`/QuickConnect/Initiate` → poll → `/Users/AuthenticateWithQuickConnect`).
///   3. Persist via [ConnectionRegistry] and create a [ProfileConnection]
///      row binding the server to [targetProfile] (or the active profile,
///      if not provided). When the target *is* the active profile we also
///      register the client with the manager so libraries refresh
///      immediately; otherwise the binder picks it up on the next switch.
class AddEmbyScreen extends StatefulWidget {
  /// When set, the new Emby connection is bound to this profile via a
  /// [ProfileConnection] row. When null, falls back to the currently active
  /// profile (typical for the global Connections screen entry point).
  final Profile? targetProfile;
  final FutureOr<EmbyConnectionAuthService> Function()? _authServiceFactory;
  final FutureOr<List<DiscoveredEmbyServer>> Function()? _localDiscoveryFactory;

  const AddEmbyScreen({
    super.key,
    this.targetProfile,
    @visibleForTesting FutureOr<EmbyConnectionAuthService> Function()? authServiceFactory,
    @visibleForTesting FutureOr<List<DiscoveredEmbyServer>> Function()? localDiscoveryFactory,
  }) : _authServiceFactory = authServiceFactory,
       _localDiscoveryFactory = localDiscoveryFactory;

  @override
  State<AddEmbyScreen> createState() => _AddEmbyScreenState();
}

class _AddEmbyScreenState extends State<AddEmbyScreen> with AsyncFormStateMixin, ControllerDisposerMixin {
  late final _urlController = createTextEditingController();
  late final _usernameController = createTextEditingController();
  late final _passwordController = createTextEditingController();
  final _urlFocus = FocusNode(debugLabel: 'AddEmby:Url');
  final _findServerFocus = FocusNode(debugLabel: 'AddEmby:FindServer');
  final _changeServerFocus = FocusNode(debugLabel: 'AddEmby:ChangeServer');
  final _usernameFocus = FocusNode(debugLabel: 'AddEmby:Username');
  // Owned so the username field can advance focus on Enter; mobile keyboards
  // act on `textInputAction: next` automatically but TV remotes / hardware
  // keyboards need the explicit `onFieldSubmitted` handler below.
  final _passwordFocus = FocusNode(debugLabel: 'AddEmby:Password');
  final _signInFocus = FocusNode(debugLabel: 'AddEmby:SignIn');
  final _quickConnectFocus = FocusNode(debugLabel: 'AddEmby:QuickConnect');
  final _cancelQuickConnectFocus = FocusNode(debugLabel: 'AddEmby:CancelQuickConnect');
  final _discoveredServerFocusNodes = <String, FocusNode>{};
  final _formKey = GlobalKey<FormState>();

  EmbyServerInfo? _serverInfo;
  EmbyEndpointRaceResult? _serverEndpoint;
  List<DiscoveredEmbyServer> _localServers = const [];
  bool _isDiscoveringLocalServers = true;
  bool _quickConnectEnabled = false;
  EmbyQuickConnectInitiation? _qcInitiation;
  bool _qcCancelled = false;
  int _qcAttemptId = 0;
  int _localDiscoveryAttemptId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_discoverLocalServers());
  }

  @override
  void dispose() {
    // Short-circuit any in-flight Quick Connect poll so it doesn't try to
    // setState after the widget is gone.
    _qcCancelled = true;
    _qcAttemptId++;
    _urlFocus.dispose();
    _findServerFocus.dispose();
    _changeServerFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _signInFocus.dispose();
    _quickConnectFocus.dispose();
    _cancelQuickConnectFocus.dispose();
    for (final node in _discoveredServerFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _discoverLocalServers() async {
    final attemptId = ++_localDiscoveryAttemptId;
    try {
      final factory = widget._localDiscoveryFactory;
      final servers = factory != null
          ? await factory()
          : await EmbyLanDiscoveryService().discover(responseWindow: const Duration(milliseconds: 1300));
      if (!mounted || attemptId != _localDiscoveryAttemptId) return;
      setState(() {
        _localServers = servers;
        _isDiscoveringLocalServers = false;
        _syncDiscoveredServerFocusNodes(servers);
      });
    } catch (e, st) {
      appLogger.w('Add Emby local discovery failed', error: e, stackTrace: st);
      if (!mounted || attemptId != _localDiscoveryAttemptId) return;
      setState(() => _isDiscoveringLocalServers = false);
    }
  }

  void _syncDiscoveredServerFocusNodes(List<DiscoveredEmbyServer> servers) {
    final ids = servers.map((server) => server.id).toSet();
    final removed = _discoveredServerFocusNodes.keys.where((id) => !ids.contains(id)).toList(growable: false);
    for (final id in removed) {
      _discoveredServerFocusNodes.remove(id)?.dispose();
    }
    for (final server in servers) {
      _discoveredServerFocusNodes.putIfAbsent(
        server.id,
        () => FocusNode(debugLabel: 'AddEmby:Discovered:${server.id}'),
      );
    }
  }

  void _clearResolvedServer() {
    _serverEndpoint = null;
    _serverInfo = null;
    _quickConnectEnabled = false;
  }

  Future<void> _useDiscoveredServer(DiscoveredEmbyServer server) async {
    if (busy) return;
    setState(() {
      _urlController.text = server.address;
      _clearResolvedServer();
    });
    await _probe();
  }

  Future<void> _probe() async {
    final input = EmbyEndpointDiscovery.buildUserInputCandidates(_enteredUrls());
    if (input.probeBaseUrls.isEmpty) {
      setErrorText(t.addServer.enterJellyfinUrlError);
      return;
    }
    final autoStartQuickConnect = await runAsync<bool>(
      () async {
        final auth = await _buildAuthService();
        final endpoint = await auth.raceEndpoints(
          input.probeBaseUrls,
          baseUrlsToPersist: input.explicitBaseUrls,
          baseUrlValidationGroups: input.validationBaseUrlGroups,
        );
        final qcEnabled = await auth.isQuickConnectEnabled(endpoint.activeBaseUrl);
        if (!mounted) return false;
        setState(() {
          _serverEndpoint = endpoint;
          _serverInfo = endpoint.serverInfo;
          _quickConnectEnabled = qcEnabled;
          _urlController.text = endpoint.baseUrls.join('\n');
        });
        // On TV, typing a username/password with a remote is misery — auto-jump
        // to Quick Connect when the server supports it. Mirrors the
        // PlatformDetector.isTV() default in add_plex_account_screen.dart.
        final autoStart = qcEnabled && PlatformDetector.isTV();
        if (!autoStart) _requestFocusAfterFrame(_usernameFocus);
        return autoStart;
      },
      errorMapper: (e) =>
          e is MediaServerUrlException ? e.message : t.addServer.couldNotReachServer(error: e.toString()),
    );
    // Sequenced after the probe's runAsync so busy stays set straight through
    // /QuickConnect/Initiate. Started from inside the probe body, the probe's
    // `finally` cleared busy mid-initiate, re-enabling the form — the focus
    // fallback from the removed tile/button then landed on the URL field and
    // auto-opened the TV keyboard over the Quick Connect panel.
    if (autoStartQuickConnect == true && mounted) await _startQuickConnect();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final info = _serverInfo;
    final endpoint = _serverEndpoint;
    if (info == null || endpoint == null) {
      await _probe();
      return;
    }
    await runAsync<void>(
      () async {
        final auth = await _buildAuthService();
        final storage = await StorageService.getInstance();
        final deviceId = await storage.getOrCreateClientIdentifier();

        final connection = await auth.authenticateByName(
          baseUrl: endpoint.activeBaseUrl,
          baseUrls: endpoint.baseUrls,
          username: _usernameController.text,
          password: _passwordController.text,
          deviceId: deviceId,
          serverInfo: info,
        );

        if (!mounted) return;
        await _persistAndExit(connection);
      },
      errorMapper: (e) {
        if (e is MediaServerAuthException) return e.message;
        appLogger.e('Add Emby failed', error: e);
        return t.addServer.signInFailed(error: e.toString());
      },
    );
  }

  Future<void> _startQuickConnect() async {
    final info = _serverInfo;
    final endpoint = _serverEndpoint;
    if (info == null || endpoint == null) return;
    final attemptId = ++_qcAttemptId;
    setState(() => _qcCancelled = false);
    await runAsync<void>(
      () async {
        final auth = await _buildAuthService();
        final storage = await StorageService.getInstance();
        final deviceId = await storage.getOrCreateClientIdentifier();

        final initiation = await auth.initiateQuickConnect(baseUrl: endpoint.activeBaseUrl, deviceId: deviceId);
        if (!_isCurrentQuickConnectAttempt(attemptId)) return;
        // Show the waiting panel without a spinner — opt-out of busy mid-flow
        // so the user-visible state matches "we're polling, nothing for you to do".
        setState(() => _qcInitiation = initiation);
        _requestFocusAfterFrame(_cancelQuickConnectFocus);
        setBusy(false);

        final connection = await auth.authenticateByQuickConnect(
          baseUrl: endpoint.activeBaseUrl,
          baseUrls: endpoint.baseUrls,
          secret: initiation.secret,
          deviceId: deviceId,
          serverInfo: info,
          shouldCancel: () => _qcCancelled || attemptId != _qcAttemptId,
        );

        if (!_isCurrentQuickConnectAttempt(attemptId)) return;
        if (connection == null) {
          // Either user cancelled or the secret expired before approval.
          // Cancellation is silent; expiry surfaces an error.
          setState(() => _qcInitiation = null);
          if (!_qcCancelled) setErrorText(t.auth.quickConnectExpired);
          return;
        }
        await _persistAndExit(connection);
      },
      errorMapper: (e) {
        if (e is MediaServerAuthException) return e.message;
        appLogger.e('Emby Quick Connect failed', error: e);
        return t.addServer.quickConnectFailed(error: e.toString());
      },
      shouldApplyState: () => attemptId == _qcAttemptId,
    );
    // Clear the QC panel after any error so the form re-shows.
    if (_isCurrentQuickConnectAttempt(attemptId) && errorText != null && _qcInitiation != null) {
      setState(() => _qcInitiation = null);
    }
  }

  bool _isCurrentQuickConnectAttempt(int attemptId) => mounted && attemptId == _qcAttemptId;

  void _cancelQuickConnect() {
    _qcAttemptId++;
    setState(() {
      _qcCancelled = true;
      _qcInitiation = null;
    });
    setBusy(false);
  }

  void _requestFocusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus) return;
      node.requestFocus();
    });
  }

  void _focusFirstDiscoveredServerOrFind() {
    if (_localServers.isEmpty) {
      _findServerFocus.requestFocus();
      return;
    }
    _discoveredServerFocusNodes[_localServers.first.id]?.requestFocus();
  }

  void _focusLastDiscoveredServerOrUrl() {
    if (_localServers.isEmpty) {
      _urlFocus.requestFocus();
      return;
    }
    _discoveredServerFocusNodes[_localServers.last.id]?.requestFocus();
  }

  List<String> _enteredUrls() {
    return _urlController.text
        .split(RegExp(r'[\n,]+'))
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  /// Shared persistence path for both username/password and Quick Connect:
  /// upsert the connection, attach a ProfileConnection to the bound profile,
  /// register with the live manager when binding to the active profile, and
  /// pop with success.
  Future<void> _persistAndExit(EmbyConnection connection) async {
    if (!mounted) return;
    // Bind to the target profile (caller's choice) or the active one. On a
    // first-run Emby-only sign-in there is no profile yet, so create and
    // activate a local profile before registering the server.
    final activeProvider = context.read<ActiveProfileProvider>();
    await activeProvider.initialize();
    if (!mounted) return;
    final targetProfile = widget.targetProfile;
    var boundProfile = targetProfile ?? activeProvider.active;
    if (shouldPromptForEmbyProfileSelection(
      targetProfile: targetProfile,
      activeProfile: activeProvider.active,
      hasProfiles: activeProvider.profiles.isNotEmpty,
    )) {
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileSwitchScreen(requireSelection: true)));
      if (!mounted) return;
      boundProfile = activeProvider.active;
      if (boundProfile == null) {
        setErrorText(t.messages.noProfilesAvailable);
        return;
      }
    }
    if (shouldCreateLocalEmbyProfile(
      targetProfile: targetProfile,
      activeProfile: boundProfile,
      hasProfiles: activeProvider.profiles.isNotEmpty,
    )) {
      final now = DateTime.now();
      final profile = Profile.local(
        id: 'local-${const Uuid().v4()}',
        displayName: connection.userName.isNotEmpty ? connection.userName : connection.serverName,
        sortOrder: now.millisecondsSinceEpoch,
        createdAt: now,
      );
      await context.read<ProfileRegistry>().upsert(profile);
      await activeProvider.activate(profile);
      if (!mounted) return;
      boundProfile = activeProvider.active ?? profile;
    }
    final bindProfile = boundProfile;
    if (bindProfile == null) {
      setErrorText(t.messages.noProfilesAvailable);
      return;
    }
    final boundToActive = bindProfile.id == activeProvider.activeId;

    await persistAndBindConnection(
      context: context,
      connection: connection,
      bindToProfile: ProfileConnection(
        profileId: bindProfile.id,
        connectionId: connection.id,
        userToken: connection.accessToken,
        userIdentifier: connection.userId,
        tokenAcquiredAt: DateTime.now(),
      ),
      addToManager: null,
    );

    if (!mounted) return;
    if (boundToActive) {
      await context.read<ActiveProfileBinder>().rebindIfActive(bindProfile.id);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<EmbyConnectionAuthService> _buildAuthService() async {
    final authServiceFactory = widget._authServiceFactory;
    if (authServiceFactory != null) return await authServiceFactory();
    final pkg = await PackageInfo.fromPlatform();
    final deviceName = await _resolveDeviceName();
    return EmbyConnectionAuthService(clientName: 'Plezy', clientVersion: pkg.version, deviceName: deviceName);
  }

  Future<String> _resolveDeviceName() async {
    // PackageInfo doesn't expose a device name; fall back to a generic label.
    // Emby only shows this in the admin "Devices" list — fine to keep
    // simple until we add proper device_info_plus integration.
    return 'Plezy';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusedScrollScaffold(
      title: Text(t.addServer.addJellyfinTitle),
      slivers: [
        if (_qcInitiation != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: _buildQuickConnectPanel(theme)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: .stretch, children: _buildBodyChildren(theme)),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildBodyChildren(ThemeData theme) {
    return [
      FocusableTextFormField(
        controller: _urlController,
        focusNode: _urlFocus,
        autofocus: true,
        tvKeyboardAutoOpenBehavior: TvKeyboardAutoOpenBehavior.afterFirstFocus,
        keyboardType: TextInputType.url,
        minLines: 1,
        maxLines: 4,
        autocorrect: false,
        enableSuggestions: false,
        enabled: !busy,
        onChanged: (_) {
          if (_serverInfo == null && _serverEndpoint == null && !_quickConnectEnabled) return;
          setState(() {
            _clearResolvedServer();
          });
        },
        onNavigateDown: _serverInfo == null
            ? _focusFirstDiscoveredServerOrFind
            : () => _changeServerFocus.requestFocus(),
        textInputAction: TextInputAction.go,
        onFieldSubmitted: busy ? null : (_) => _probe(),
        decoration: InputDecoration(
          labelText: t.addServer.serverUrls,
          // URL example — intentionally not localized.
          hintText: 'https://emby.example.com',
          helperText: _serverInfo == null ? t.addServer.serverUrlsHelper : null,
          prefixIcon: const AppIcon(Symbols.link_rounded, fill: 1),
        ),
        validator: (_) => _enteredUrls().isEmpty ? t.addServer.required : null,
      ),
      if (_serverInfo == null) ...[
        ..._buildLocalDiscoverySection(theme),
        const SizedBox(height: 16),
        FocusableButton(
          focusNode: _findServerFocus,
          useBackgroundFocus: true,
          onNavigateUp: _focusLastDiscoveredServerOrUrl,
          onPressed: busy ? null : _probe,
          child: FilledButton.icon(
            onPressed: busy ? null : _probe,
            icon: busy ? const LoadingIndicatorBox() : const AppIcon(Symbols.travel_explore_rounded, fill: 1),
            label: Text(t.addServer.findServer),
          ),
        ),
      ] else ...[
        const SizedBox(height: 16),
        _buildServerCard(theme),
        const SizedBox(height: 16),
        FocusableTextFormField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !busy,
          onNavigateUp: () => _changeServerFocus.requestFocus(),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: busy ? null : (_) => _passwordFocus.requestFocus(),
          decoration: InputDecoration(
            labelText: t.addServer.username,
            prefixIcon: const AppIcon(Symbols.person_rounded, fill: 1),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? t.addServer.required : null,
        ),
        const SizedBox(height: 12),
        FocusableTextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: true,
          enabled: !busy,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: busy ? null : (_) => _signIn(),
          decoration: InputDecoration(
            labelText: t.addServer.password,
            prefixIcon: const AppIcon(Symbols.lock_rounded, fill: 1),
          ),
          // Empty password is valid for some Emby setups, so don't
          // require a value.
        ),
        const SizedBox(height: 16),
        FocusableButton(
          focusNode: _signInFocus,
          useBackgroundFocus: true,
          onPressed: busy ? null : _signIn,
          child: FilledButton.icon(
            onPressed: busy ? null : _signIn,
            icon: busy ? const LoadingIndicatorBox() : const AppIcon(Symbols.login_rounded, fill: 1),
            label: Text(t.addServer.signIn),
          ),
        ),
        if (_quickConnectEnabled) ...[
          const SizedBox(height: 12),
          FocusableButton(
            focusNode: _quickConnectFocus,
            useBackgroundFocus: true,
            onPressed: busy ? null : _startQuickConnect,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _startQuickConnect,
              icon: const AppIcon(Symbols.tap_and_play_rounded, fill: 1),
              label: Text(t.auth.useQuickConnect),
            ),
          ),
        ],
      ],
      if (errorText != null) ...[
        const SizedBox(height: 12),
        Text(errorText!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
      ],
    ];
  }

  Widget _buildServerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const AppIcon(Symbols.cloud_done_rounded, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(_serverInfo!.serverName, style: theme.textTheme.titleSmall),
                Text(
                  'Emby ${_serverInfo!.version}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          FocusableButton(
            focusNode: _changeServerFocus,
            useBackgroundFocus: true,
            onNavigateUp: () => _urlFocus.requestFocus(),
            onNavigateDown: () => _usernameFocus.requestFocus(),
            onPressed: busy
                ? null
                : () => setState(() {
                    _clearResolvedServer();
                  }),
            child: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      _clearResolvedServer();
                    }),
              child: Text(t.addServer.change),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLocalDiscoverySection(ThemeData theme) {
    if (_isDiscoveringLocalServers) {
      return [
        const SizedBox(height: 16),
        Row(
          children: [
            const LoadingIndicatorBox(size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.addServer.searchingLocalServers,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ];
    }

    if (_localServers.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      Text(t.addServer.localServers, style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      for (final server in _localServers) ...[
        _DiscoveredEmbyServerTile(
          server: server,
          focusNode: _discoveredServerFocusNodes[server.id],
          onNavigateUp: () {
            final index = _localServers.indexOf(server);
            if (index <= 0) {
              _urlFocus.requestFocus();
              return;
            }
            _discoveredServerFocusNodes[_localServers[index - 1].id]?.requestFocus();
          },
          onNavigateDown: () {
            final index = _localServers.indexOf(server);
            if (index < 0 || index == _localServers.length - 1) {
              _findServerFocus.requestFocus();
              return;
            }
            _discoveredServerFocusNodes[_localServers[index + 1].id]?.requestFocus();
          },
          onTap: busy ? null : () => unawaited(_useDiscoveredServer(server)),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _buildQuickConnectPanel(ThemeData theme) {
    final code = _qcInitiation!.code;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: .min,
        children: [
          Text(
            t.auth.quickConnectInstructions,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 32),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              // letterSpacing adds a trailing gap after the last glyph;
              // matching left padding keeps the code optically centered.
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                code,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: .bold,
                  letterSpacing: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: .min,
            children: [
              const LoadingIndicatorBox(size: 16),
              const SizedBox(width: 10),
              Text(t.auth.quickConnectWaiting, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: 32),
          FocusableButton(
            focusNode: _cancelQuickConnectFocus,
            useBackgroundFocus: true,
            onPressed: _cancelQuickConnect,
            child: OutlinedButton.icon(
              onPressed: _cancelQuickConnect,
              icon: const AppIcon(Symbols.close_rounded, fill: 1),
              label: Text(t.auth.quickConnectCancel),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 16),
            Text(
              errorText!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveredEmbyServerTile extends StatelessWidget {
  final DiscoveredEmbyServer server;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final VoidCallback? onTap;

  const _DiscoveredEmbyServerTile({
    required this.server,
    required this.focusNode,
    required this.onNavigateUp,
    required this.onNavigateDown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusableWrapper(
      focusNode: focusNode,
      disableScale: true,
      // Border drawn by CardFocusBorder so it paints over the opaque Material.
      delegateFocusBorder: true,
      descendantsAreFocusable: false,
      onSelect: onTap,
      onNavigateUp: onNavigateUp,
      onNavigateDown: onNavigateDown,
      child: CardFocusBorder(
        borderRadius: 12,
        strokeAlign: BorderSide.strokeAlignInside,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const AppIcon(Symbols.dns_rounded, fill: 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: .min,
                      children: [
                        Text(server.name, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          server.address,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
