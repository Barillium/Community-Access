import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/faq_content.dart';
import 'package:community_access_client/communities_page.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/site_information_page.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/account_recovery_page.dart';
import 'package:community_access_client/access_flow_page.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/ticketing_pages.dart';
import 'package:community_access_client/event_editorial_view.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;
import 'auth_account_widget_test.dart' show AuthAccountApi;
import 'directory_widget_test.dart' show DirectoryFixture, profileId;
import 'organizer_features_test.dart' show FeatureFixture;
import 'access_flow_test.dart' show FlowApi;
import 'ticketing_widget_test.dart' show TicketFixture;
import 'event_editorial_test.dart' show demoEvent;

class StructureDirectory extends DirectoryFixture {
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
          {'id': 'demo', 'name': 'Demo Gemeinschaft'},
        ],
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

class EmptyStructureDiscovery extends DiscoveryFixture {
  EmptyStructureDiscovery({this.catalogFailure = false});
  final bool catalogFailure;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (catalogFailure) throw const ApiFailure('Synthetischer Katalogfehler.');
    return {
      'signed_in': false,
      'hero': [],
      'events': [],
      'communities': [],
      'series': [],
    };
  }
}

class PendingStructureDiscovery extends DiscoveryFixture {
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) => pending.future;
}

List<SemanticsData> headingData(
  WidgetTester tester, {
  bool headingsOnly = true,
}) {
  final result = <SemanticsData>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (!headingsOnly || data.headingLevel > 0) result.add(data);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return result;
}

void main() {
  test('type roles retain strict hierarchy at every supported width', () {
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      final sizes = [
        AccessTypography.hero(width),
        AccessTypography.page(width),
        AccessTypography.section(width),
        AccessTypography.card(width),
        AccessTypography.leadSize,
        AccessTypography.bodySize,
        AccessTypography.captionSize,
        AccessTypography.labelSize,
      ];
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i - 1], greaterThan(sizes[i]));
      }
      expect(AccessTypography.bodySize, greaterThanOrEqualTo(16));
    }
  });

  test('audited content components use named font roles', () {
    // Date numerals, image provenance and icon dimensions are separate roles.
    for (final file in [
      'faq_content',
      'communities_page',
      'event_editorial_view',
      'event_carousel',
      'public_home_page',
      'directory_pages',
    ]) {
      expect(
        RegExp(r'fontSize:\s*\d')
            .hasMatch(File('lib/$file.dart').readAsStringSync()),
        isFalse,
        reason: '$file must use AccessTypography, not local font-size literals',
      );
    }
  });

  Widget frame(Widget body) => MaterialApp(
    theme: AccessDesign.theme(),
    home: LanguageScope(language: AppLanguage(), child: body),
  );
  Widget content(Widget body) => Scaffold(
    body: SingleChildScrollView(child: AccessPageFrame(child: body)),
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('loading home retains page hierarchy at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          CommunityAccessApp(
            api: PendingStructureDiscovery(),
            authOnly: true,
            showPublicHome: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(
          headingData(tester).where((h) => h.headingLevel == 1),
          hasLength(1),
        );
        final primary = tester.widget<AccessHeading>(
          find.byWidgetPredicate((w) => w is AccessHeading && w.level == 1),
        );
        expect(primary.role, AccessHeadingRole.page);
        expect(
          headingData(
            tester,
            headingsOnly: false,
          ).where((data) => data.role == SemanticsRole.main),
          hasLength(1),
        );
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
  for (final width in [320.0, 768.0]) {
    testWidgets(
      'long English title wraps without shrinking at $width and double text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
        );
        const longTitle =
            'Discover shared experiences across independent cultural communities';
        await tester.pumpWidget(
          frame(
            content(
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccessHeading(
                    longTitle,
                    role: AccessHeadingRole.page,
                    level: 1,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'A synthetic, deliberately longer English introduction.',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text(longTitle));
        expect(
          text.style!.fontSize,
          greaterThanOrEqualTo(AccessTypography.pageMin),
        );
        expect(
          tester.getSize(find.text(longTitle)).height,
          greaterThan(text.style!.fontSize! * 2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  final cases = <String, Widget Function()>{
    'home-empty': () => CommunityAccessApp(
      api: EmptyStructureDiscovery(),
      authOnly: true,
      showPublicHome: true,
    ),
    'home-error': () => CommunityAccessApp(
      api: EmptyStructureDiscovery(catalogFailure: true),
      authOnly: true,
      showPublicHome: true,
    ),
    'home': () => CommunityAccessApp(
      api: DiscoveryFixture(),
      authOnly: true,
      showPublicHome: true,
    ),
    'faq': () => frame(content(const FaqContent())),
    'communities': () => frame(
      content(
        CommunitiesPage(
          api: StructureDirectory(),
          openAccount: () async {},
          onOrganizers: (_) {},
          onFaq: () {},
        ),
      ),
    ),
    'organizers': () => frame(
      content(
        DirectoryBrowser(
          api: DirectoryFixture(),
          venues: false,
          openAccount: () async {},
        ),
      ),
    ),
    'organizer-profile': () => frame(
      OrganizerDetailPage(
        api: FeatureFixture()..allowed = true,
        id: profileId,
        openAccount: () async {},
      ),
    ),
    'event': () => frame(content(EventEditorialView(event: demoEvent()))),
    'contact': () => frame(const SiteContactPage()),
    'privacy': () => frame(const SiteInformationPage(privacy: true)),
    'operator': () => frame(const SiteInformationPage(privacy: false)),
    'login': () => frame(GuestPage(api: AuthAccountApi(), authOnly: true)),
    'registration': () => frame(AccountRegistrationPage(api: AuthAccountApi())),
    'recovery': () => frame(
      AccountRecoveryPage(
        api: AuthAccountApi(),
        link: const AccountLinkData('forgot'),
      ),
    ),
    'access': () => frame(AccessFlowPage(api: FlowApi())),
    'organizer-management': () =>
        frame(OrganizerManagementPage(api: FeatureFixture())),
    'tickets': () => frame(MyTicketsPage(api: TicketFixture()..paid = true)),
    'checkout': () => frame(
      TicketCheckoutPage(
        api: TicketFixture(),
        initialOrder: TicketFixture().order,
      ),
    ),
  };
  for (final width in [390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final entry in cases.entries) {
        testWidgets(
          '${entry.key}: one H1 and no skipped heading levels at $width / $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 1600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(entry.value());
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final headings = headingData(tester);
              if (entry.key == 'home-empty' || entry.key == 'home-error') {
                final primary = tester.widget<AccessHeading>(
                  find.byWidgetPredicate(
                    (w) => w is AccessHeading && w.level == 1,
                  ),
                );
                expect(primary.role, AccessHeadingRole.page);
              }
              expect(
                headingData(
                  tester,
                  headingsOnly: false,
                ).where((data) => data.role == SemanticsRole.main),
                hasLength(1),
                reason:
                    'Exactly one main content landmark, without nested mains',
              );
              expect(
                headings.where((h) => h.headingLevel == 1),
                hasLength(1),
                reason:
                    '${entry.key}: ${headings.map((h) => '${h.headingLevel}:${h.label}')}',
              );
              var previous = 0;
              for (final heading in headings) {
                expect(
                  heading.headingLevel,
                  lessThanOrEqualTo(previous + 1),
                  reason: 'Skipped level before ${heading.label}',
                );
                previous = heading.headingLevel;
              }
            } finally {
              semantics.dispose();
            }
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
