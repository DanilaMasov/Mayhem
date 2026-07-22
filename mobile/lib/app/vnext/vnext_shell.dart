import 'package:flutter/material.dart';

import '../../core/design_system/components/components.dart';
import '../../core/localization/mayhem_strings.dart';
import '../../core/feature_flags/feature_flags.dart';
import '../../features/feed/presentation/vnext_feed_screen.dart';
import '../../features/profile/presentation/vnext_you_screen.dart';
import '../../features/progress/presentation/vnext_journey_screen.dart';
import '../../features/progress/presentation/vnext_rank_path_screen.dart';
import '../../features/progress/presentation/vnext_rank_style_collection_screen.dart';
import '../../features/settings/presentation/vnext_settings_screen.dart';
import '../../features/season/presentation/vnext_season_screen.dart';
import 'vnext_runtime.dart';
import '../composition/remote_runtime_diagnostics.dart';

enum VNextTab { feed, journey, you }

class VNextShell extends StatefulWidget {
  const VNextShell({
    super.key,
    required this.runtime,
    required this.onResetLocalData,
    this.remoteDiagnostics,
  });

  final VNextRuntime runtime;
  final Future<void> Function() onResetLocalData;
  final RemoteRuntimeDiagnostics? remoteDiagnostics;

  @override
  State<VNextShell> createState() => _VNextShellState();
}

class _VNextShellState extends State<VNextShell> {
  final _navigatorKeys = {
    for (final tab in VNextTab.values) tab: GlobalKey<NavigatorState>(),
  };
  var _selected = VNextTab.feed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return MayhemScaffold(
      body: IndexedStack(
        index: _selected.index,
        children: [for (final tab in VNextTab.values) _navigator(tab)],
      ),
      bottomNavigation: MayhemBottomNavigation(
        semanticLabel: '${strings.feed}, ${strings.journey}, ${strings.you}',
        destinations: [
          MayhemNavigationDestination(
            icon: MayhemGlyph.feed,
            label: strings.feed,
          ),
          MayhemNavigationDestination(
            icon: MayhemGlyph.journey,
            label: strings.journey,
          ),
          MayhemNavigationDestination(
            icon: MayhemGlyph.profile,
            label: strings.you,
          ),
        ],
        selectedIndex: _selected.index,
        onSelected: _select,
      ),
    );
  }

  Widget _navigator(VNextTab tab) {
    return Navigator(
      key: _navigatorKeys[tab],
      initialRoute: _rootRoute(tab),
      onGenerateRoute: (settings) => _route(tab, settings),
    );
  }

  Route<void> _route(VNextTab tab, RouteSettings settings) {
    final snapshot = widget.runtime.journey.snapshot;
    final routeName = settings.name ?? _rootRoute(tab);
    final Widget child = switch ((tab, routeName)) {
      (VNextTab.feed, _) => VNextFeedScreen(
        controller: widget.runtime.feed,
        challengeController: widget.runtime.feedChallenge,
      ),
      (VNextTab.journey, JourneyRoutes.traits) when snapshot != null =>
        VNextTraitsDetailScreen(snapshot: snapshot),
      (VNextTab.journey, JourneyRoutes.ranks) when snapshot != null =>
        VNextRankPathScreen(
          snapshot: snapshot,
          settings: widget.runtime.settings,
        ),
      (VNextTab.journey, JourneyRoutes.styles) when snapshot != null =>
        VNextRankStyleCollectionScreen(
          snapshot: snapshot,
          settings: widget.runtime.settings,
        ),
      (VNextTab.journey, JourneyRoutes.momentum) when snapshot != null =>
        VNextMomentumDetailScreen(snapshot: snapshot),
      (VNextTab.journey, JourneyRoutes.history) when snapshot != null =>
        VNextHistoryScreen(snapshot: snapshot),
      (VNextTab.journey, JourneyRoutes.season) => VNextSeasonScreen(
        controller: widget.runtime.season,
      ),
      (VNextTab.journey, _) => VNextJourneyScreen(
        controller: widget.runtime.journey,
        season: widget.runtime.season,
        settings: widget.runtime.settings,
      ),
      (VNextTab.you, YouRoutes.settings) ||
      (VNextTab.you, YouRoutes.privacy) ||
      (VNextTab.you, YouRoutes.accessibility) ||
      (VNextTab.you, YouRoutes.account) => VNextSettingsScreen(
        controller: widget.runtime.settings,
        featureFlags: widget.runtime.featureFlags,
        remoteAccount: widget.runtime.remoteAccount,
        onResetLocalData: widget.onResetLocalData,
      ),
      (VNextTab.you, YouRoutes.diagnostics) => VNextDiagnosticsScreen(
        featureFlags: widget.runtime.featureFlags,
        remoteDiagnostics: widget.remoteDiagnostics,
        remoteAccount: widget.runtime.remoteAccount,
      ),
      (VNextTab.you, _) => VNextYouScreen(
        anonymousHandle: widget.runtime.anonymousHandle,
        journey: widget.runtime.journey,
        artifacts: widget.runtime.artifacts,
        artifactsEnabled:
            widget.runtime.featureFlags.isEnabled(
              MayhemFeatureFlag.seasonZeroEnabled,
            ) &&
            widget.runtime.featureFlags.isEnabled(
              MayhemFeatureFlag.bossRaidEnabled,
            ),
      ),
    };
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => child,
    );
  }

  String _rootRoute(VNextTab tab) => switch (tab) {
    VNextTab.feed => '/feed',
    VNextTab.journey => JourneyRoutes.root,
    VNextTab.you => YouRoutes.root,
  };

  void _select(int index) {
    final next = VNextTab.values[index];
    if (next == _selected) {
      _navigatorKeys[next]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _selected = next);
  }
}
