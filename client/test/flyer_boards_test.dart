import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/flyer_design.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/faq_content.dart';
import 'package:community_access_client/site_information_page.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/event_editorial_view.dart';
import 'package:community_access_client/communities_page.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/account_recovery_page.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/access_flow_page.dart';
import 'package:community_access_client/ticketing_pages.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;
import 'directory_widget_test.dart' show DirectoryFixture, profileId;
import 'organizer_features_test.dart' show FeatureFixture;
import 'auth_account_widget_test.dart' show AuthAccountApi;
import 'access_flow_test.dart' show FlowApi;
import 'ticketing_widget_test.dart' show TicketFixture;
import 'event_editorial_test.dart' show demoEvent;

class FlyerBoardDiscovery extends DiscoveryFixture {
  FlyerBoardDiscovery() {
    events.last['access_mode'] = 'public';
    events.last['title'] = 'Demo Offenes Atelier';
    for (final event in events) {
      event.remove('reasons');
    }
  }
}

class FlyerBoardDirectory extends FeatureFixture {
  @override
  List<Map<String, dynamic>> get series => [];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'communities') {
      return {
        'signed_in': false,
        'items': [
          {'id': 'community', 'name': 'Demo Studio Zwischenraum'},
          {'id': 'two', 'name': 'Demo Raum für Alle'},
        ],
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

/// Optional visual evidence, rendered by the real Flutter widgets with named fixtures.
/// Run with CA_FLYER_BOARDS_DIR. No production APIs or provider accounts are used.
void main() {
  final out = Platform.environment['CA_FLYER_BOARDS_DIR'];
  if (out == null) return;
  setUpAll(() async {
    final font = FontLoader('Archivo')
      ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Archivo-Italic-Variable.ttf'));
    await font.load();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))).load();
    await (FontLoader(
      'packages/ca_design/CaIcons',
    )..addFont(rootBundle.load('packages/ca_design/fonts/CaIcons.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/forui_lucide/lucide')
          ..addFont(rootBundle.load('packages/forui_lucide/assets/lucide.ttf')))
        .load();
    await Directory(out).create(recursive: true);
  });
  Widget frame(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AccessDesign.theme(),
    home: LanguageScope(language: AppLanguage(), child: child),
  );
  Widget scroll(Widget child) => frame(
    Scaffold(
      appBar: AccessTopBar(
        title: const Text('Community Access'),
        leading: IconButton(
          onPressed: () {},
          icon: const AccessIcon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(child: AccessPageFrame(child: child)),
    ),
  );
  final cases = <String, Widget Function()>{
    'faq': () => scroll(const FaqContent()),
    'kontakt': () => frame(const SiteContactPage()),
    'datenschutz': () => frame(const SiteInformationPage(privacy: true)),
    'betreiber': () => frame(const SiteInformationPage(privacy: false)),
    'startseite': () => CommunityAccessApp(
      api: FlyerBoardDiscovery(),
      authOnly: true,
      showPublicHome: true,
    ),
    'programm': () => scroll(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FlyerBanner(title: 'Programm'),
          const SizedBox(height: 32),
          ProgramList(
            api: DirectoryFixture(),
            calendarLayout: true,
            program: {'events': FlyerBoardDiscovery().events, 'series': []},
          ),
        ],
      ),
    ),
    'communities': () => scroll(
      CommunitiesPage(
        api: FlyerBoardDirectory(),
        openAccount: () async {},
        onOrganizers: (_) {},
        onFaq: () {},
      ),
    ),
    'veranstalter': () => scroll(
      DirectoryBrowser(
        api: DirectoryFixture(),
        venues: false,
        openAccount: () async {},
      ),
    ),
    'veranstalterprofil': () => frame(
      OrganizerDetailPage(
        api: FlyerBoardDirectory()..allowed = true,
        id: profileId,
        openAccount: () async {},
      ),
    ),
    'veranstaltung': () {
      final event = demoEvent();
      event['event_content']['flyer_data'] =
          'data:image/webp;base64,${base64Encode(File('assets/images/kulturraum.webp').readAsBytesSync())}';
      event['event_content']['flyer_alt'] = 'Synthetisches Kulturmotiv';
      return scroll(
        EventEditorialView(
          event: event,
          participation: const Text(
            'Synthetisches Beispiel · Teilnahme noch offen',
          ),
        ),
      );
    },
    'anmelden': () => frame(GuestPage(api: AuthAccountApi(), authOnly: true)),
    'registrieren': () => frame(AccountRegistrationPage(api: AuthAccountApi())),
    'wiederherstellung': () => frame(
      AccountRecoveryPage(
        api: AuthAccountApi(),
        link: const AccountLinkData('forgot'),
      ),
    ),
    'mein-zugang': () => frame(AccessFlowPage(api: FlowApi())),
    'veranstalterverwaltung': () =>
        frame(OrganizerManagementPage(api: FlyerBoardDirectory())),
    'meine-tickets': () =>
        frame(MyTicketsPage(api: TicketFixture()..paid = true)),
    'ticketbestellung': () => frame(
      TicketCheckoutPage(
        api: TicketFixture(),
        initialOrder: TicketFixture().order,
      ),
    ),
  };
  for (final width in [1440.0, 390.0]) {
    for (final item in cases.entries) {
      testWidgets('export ${item.key} at $width', (tester) async {
        tester.view.physicalSize = Size(width, width == 390 ? 2200 : 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: item.value()));
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp).first);
          await precacheImage(const AssetImage(FlyerStyle.scene), context);
          await precacheImage(
            MemoryImage(
              File('assets/images/kulturraum.webp').readAsBytesSync(),
            ),
            context,
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$out/${item.key}-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
