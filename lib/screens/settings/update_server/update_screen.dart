import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as html;
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String? _htmlChangelog;

  /// The changelog the card was parsed from, so the page knows when the server
  /// has handed it different notes.
  String? _parsedChangelog;

  void processChangelog() {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    final String? changelog = serversProvider.updateAvailable.data?.changelog;
    if (changelog == _parsedChangelog) return;
    _parsedChangelog = changelog;

    if (changelog == null) {
      // Notes that belong to another release are not notes for this one, and
      // the heading above the card names the release the data is at now.
      if (_htmlChangelog != null) setState(() => _htmlChangelog = null);
      return;
    }
    parseChangelog(changelog);
  }

  Future<void> parseChangelog(String changelog) async {
    final markdownResult = await compute(md.markdownToHtml, changelog);
    final htmlParsedResult = await compute(html.parse, markdownResult);
    // Two awaits deep, and the user is free to leave the screen during them.
    if (!mounted) return;
    setState(() => _htmlChangelog = htmlParsedResult.outerHtml);
  }

  @override
  void initState() {
    super.initState();
    processChangelog();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The check on the bar replaces the release notes on the provider, and a
    // parse that ran once when the page opened would leave the card waiting on
    // notes the page already holds.
    processChangelog();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final width = MediaQuery.sizeOf(context).width;

    // The check has three outcomes the screen has to tell apart: it is still
    // running, it never got an answer, and it got the answer "this server does
    // not do updates". The last two used to fall into the same arm as a
    // finished check, so a server that never answered was shown as "Server is
    // up to date" behind a shield, and a server with the update check switched
    // off showed a changelog spinner that had nothing to wait for.
    final LoadStatus loadStatus = serversProvider.updateAvailable.loadStatus;
    final bool isLoading = loadStatus == LoadStatus.loading;
    final bool checkFailed = loadStatus == LoadStatus.error;
    final bool updatesDisabled =
        loadStatus == LoadStatus.loaded &&
        serversProvider.updateAvailable.data?.disabled == true;

    final bool canAutoupdate = serversProvider.updateAvailable.data?.canAutoupdate == true;
    final bool isUpdating = serversProvider.updatingServer == true;

    void checkUpdates() {
      final server = serversProvider.selectedServer;
      if (server != null) {
        serversProvider.checkServerUpdatesAvailable(server: server);
      }
    }

    void update() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.requestingUpdate);

      final result = await serversProvider.apiClient2!.requestUpdateServer();

      processModal.close();
      
      if (!context.mounted) return;
      if (result.successful == true) {
        serversProvider.recheckPeriodServerUpdated();
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: AppLocalizations.of(context)!.requestStartUpdateSuccessful,
          color: p.green,
          labelColor: Colors.white,
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: AppLocalizations.of(context)!.requestStartUpdateFailed,
          color: p.red,
          labelColor: Colors.white,
        );
      }
    }  

    // Where the server stands reads as one row of the design layer: a badge
    // carrying the verdict and a line naming what the verdict is about. The
    // row is left out when there is no verdict to carry, because the failure
    // and the "this server does not update" states below say it themselves.
    Widget? statusRow;
    if (!checkFailed && !updatesDisabled) {
      final String statusTitle = isLoading
        ? l.checkingUpdates
        : canAutoupdate
          ? l.updateAvailable
          : l.serverUpdated;
      final String? statusDetail = isLoading
        ? null
        : canAutoupdate
          ? "${l.newVersion}: ${serversProvider.updateAvailable.data?.newVersion ?? 'N/A'}"
          : "${l.installedVersion}: ${serversProvider.updateAvailable.data?.currentVersion ?? '—'}";

      statusRow = AppleListTile(
        title: statusTitle,
        subtitle: statusDetail,
        // A check that is still running has no verdict to badge, so the row
        // turns with the spinner the page used to hide in its header.
        leading: isLoading
          ? const SizedBox(
              width: 29,
              height: 29,
              child: Center(child: CupertinoActivityIndicator(radius: 8)),
            )
          : null,
        icon: isLoading
          ? null
          : canAutoupdate
            ? CupertinoIcons.arrow_down_circle_fill
            : CupertinoIcons.checkmark_shield_fill,
        iconColor: canAutoupdate ? p.tint : p.green,
        showChevron: false,
      );
    }

    final String changelogVersion = canAutoupdate
      ? serversProvider.updateAvailable.data?.newVersion ?? ''
      : serversProvider.updateAvailable.data?.currentVersion ?? '';

    return AppleScreen(
      title: l.updates,
      subtitle: l.updatesDescription,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        IconButton(
          onPressed: checkUpdates,
          icon: const Icon(CupertinoIcons.arrow_clockwise),
          tooltip: l.refresh,
        ),
        // Updating is the one action this page exists to offer, so the word
        // sits on the bar rather than floating over the text it acts on, the
        // way the old button did before it hid itself on the first scroll.
        if (!isUpdating && canAutoupdate)
          AppleHeaderAction(label: l.updateNow, onPressed: update),
      ],
      slivers: [
        if (statusRow != null)
          SliverToBoxAdapter(
            child: AppleListSection(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              children: [ statusRow ],
            ),
          ),
        if (checkFailed)
          SliverToBoxAdapter(
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.unknownStatus,
              // The refresh handle on the bar is above a screen of nothing, so
              // the state offers the retry itself, the way every other page of
              // the app does.
              message: l.serverInfoNotLoaded,
              action: AppleFormButton(
                label: l.checkUpdates,
                background: p.tint,
                foreground: Colors.white,
                onPressed: checkUpdates,
              ),
              color: p.red,
            ),
          )
        else if (updatesDisabled)
          SliverToBoxAdapter(
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.autoupdateUnavailable,
              message: l.autoupdateUnavailableDescription,
              color: p.orange,
            ),
          )
        else if (_htmlChangelog != null) ...[
          SliverToBoxAdapter(
            child: AppleGroupHeader(title: "Changelog $changelogVersion"),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: AppleCard(
                child: HtmlWidget(
                  _htmlChangelog!,
                  onTapUrl: (url) {
                    openUrl(url);
                    return true;
                  },
                ),
              ),
            ),
          ),
        ] else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: AppleLoading(label: l.loadingChangelog),
            ),
          ),
      ],
    );
  }
}
