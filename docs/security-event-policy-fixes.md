# Sicherheitskorrekturen der Eventpolicy · 05.10.2026

Umfang: die drei reproduzierten P2-Befunde SA-01 bis SA-03 des beauftragten Security Auditors im lokalen synthetischen Flutter-/Better-Auth-/PostgreSQL-Prototyp. Verwendete Anweisungen: globale und Projekt-`AGENTS.md`, [Produktspezifikation](product-spec.md), [Setup](setup.md), [Git-Workflow](workflow.md), [Codex-Workflow](codex-workflow.md), Skill `ecc:security-review` sowie [gemeinsame Eventpolicy](unified-event-policy.md). Keine Unterordner-Overrides gefunden. Manueller Arbeitsablauf, keine Änderung am geschützten Aufgabenrunner oder seinen Freigaberegeln.

## Änderungen

| Befund | Korrektur |
| --- | --- |
| SA-01: abgeleitete Werte verraten verborgenen Beginn/Ende | Gemeinsame Policy für Anfrage, Rückzug und Besuch. `before_start` bleibt bei fehlender Zeitfreigabe `null`; Besuch ist nur bei bestätigter Teilnahme und freigegebener, vergangener Endzeit möglich. Bei verborgenen Zeiten hängt das Anfrage-/Rückzugsfenster ausschließlich von der öffentlichen Anfragefrist ab. Verborgene Zeitverschiebungen ändern weder Metadaten noch Fehlerantworten. |
| SA-02: fremder Rückzug verrät Eventzustand | Eigene aktive Anfrage und aktuell sichtbares Event sind Voraussetzung. Private, unbekannte, entzogene oder fremde Ziele und bereits abgeschlossene Anfragen erhalten einheitlich `404 NOT_FOUND`, ohne einen zeitabhängigen Fehler. |
| SA-03: Ranking verrät entzogene Profil-/Reihenzuordnungen | Profil-/Reihenmarker und Veranstalterbesuche beeinflussen Ranking und Gründe nur bei aktueller Sichtbarkeit ihrer Zuordnung. Community-Folgen braucht öffentliche Community. Das direkte Merken eines erlaubten Events funktioniert unabhängig weiter. Die gemeinsame Abfrage schützt sowohl Startseite als auch persönliche Suche. |

Die Nutzerentscheidung dieses Tages ergänzt ausdrücklich die öffentliche Anfragefrist `request_deadline_at`. Das lokale additive Bootstrap-Schema ergänzt eine nullable Datumsspalte; vorhandene Events erhalten keine aus geheimen Zeiten abgeleitete Frist. Neue oder bearbeitete veröffentlichte semi-öffentliche Events verlangen eine ausdrücklich eingetragene Frist. Bei verborgenen Zeiten und fehlender Frist bleiben Anfrage und Rückzug geschlossen. Gastgeber können nur vor dem tatsächlichen Beginn zusagen. Bei freigegebenem Beginn bleibt die bestehende Grenze vor Beginn bestehen; sichtbare Rückzüge bleiben bis zum Beginn möglich.

Der Gastgebereditor lädt und speichert die Frist als eigenen Wert und erklärt ihre Veröffentlichung. Gespeicherte und ungespeicherte Vorschau sowie Eventseiten zeigen sie getrennt von Datum und Ort. Detail, öffentliche Archivsuche, persönliche Suche, Startseite, Programm und Merkliste liefern denselben gespeicherten öffentlichen Wert. Der Gastclient verwendet die Backendflags `can_request` und `can_withdraw`, statt den geschützten Beginn vorauszusetzen. Keine neuen Abhängigkeiten oder externen Dienste.

Betroffene Produktdateien: `server/event_policy.mjs`, `server/catalog.mjs`, `server/discovery.mjs`, `server/discovery.sql`, `server/directory.mjs`; `client/lib/organizer_management_page.dart`, `client/lib/event_interest_panel.dart`, `client/lib/event_editorial_view.dart`, `client/lib/better_auth_api.dart`. Neue Sicherheitsregressionen in `server/security_event_policy.test.mjs` und `client/test/security_event_policy_test.dart`; vorhandene synthetische Fixtures wurden an die ausdrücklich eingetragene Frist und die Berechtigungsprüfung angepasst.

## Tatsächlich ausgeführte Prüfungen

| Prüfung | Ergebnis |
| --- | --- |
| `python3 -I scripts/local_auth.py --test-directory` | **Bestanden:** 56 Tests, darunter sieben neue negative Sicherheitsregressionen; keine fehlgeschlagen oder übersprungen. Frische synthetische PostgreSQL, HTTP und signierte Sitzungen. |
| `python3 -I scripts/local_auth.py --test-access` | **Bestanden:** 14 Tests, einschließlich Konkurrenz-/Entzugsfällen, getrennter Teilnahme und Adresse sowie der bestehenden exakten 168-Stunden-Speicherfrist. |
| `node --test server/http.test.mjs server/event_content.test.mjs` | **Bestanden:** vier Tests. |
| Clientformatierung und `flutter analyze --no-pub` | **Bestanden:** 71 Dartdateien bereits formatiert, keine Analysebefunde. |
| `flutter test --no-pub --reporter expanded` | **Bestanden:** 169 Tests, darunter drei neue Widgetregressionen für Frist, Anfrage/Rückzug und Gastgebereditor. |
| Regulärer Flutter-Webbuild ohne Paketdownloads und ohne Renderer-CDN | **Bestanden:** `/private/tmp/community-access-security-web`. Bestehende Cupertino-Fontwarnung und Abkündigung des PWA-Parameters bleiben. |
| Unabhängiger Security-Auditor-Recheck mit eigenen temporären synthetischen Fixtures | **Bestanden:** Die drei ursprünglichen Angriffe nicht mehr reproduzierbar. Positive Gegenproben für Anfrage, Rückzug, Besuch und genaue Adresse bestanden. [Dauerhafter Probeauszug](qa/security-event-policy-recheck-20261005.log). |
| Eigener Änderungsvergleich, neue Testdateien, Dokumentationslinks und `git diff --check` | **Bestanden.** |
| Lasttest, Remote-Schema und Produktionskonfiguration | **Noch nicht geprüft.** |

Frühere Zwischenläufe scheiterten an anzupassenden Fixtures/Testfindern sowie einmal an lokalen Sandbox-Ports. Diese wurden korrigiert; die Tabelle nennt die vollständigen abschließenden Läufe. Keine fehlgeschlagene Pflichtprüfung wurde als bestanden übernommen.

Die tatsächlichen Flutterkomponenten wurden zusätzlich in einem eigenen Build mit synthetischer Anzeigefixture auf `127.0.0.1:8361` angesehen. Die öffentliche Frist erscheint neben dem weiterhin verborgenen Datum/Ort; Anfrage und Rückzug funktionieren in dieser Prüfansicht. Die abgefragte Browserkonsole enthielt keine Warnungen oder Fehler. [Frist und geschützte Angaben](screenshots/security-event-deadline-20261005.png), [Anfragestatus mit Rückzug](screenshots/security-event-request-20261005.png). Dies ist eine Darstellungs-/Interaktionsprüfung mit Anzeigefixture, kein durchgängiger Browsernachweis gegen das Backend; dessen Nachweis stammt aus den getrennten Datenbank-/HTTP-Tests. Eigener statischer Server, Prüftab und frische Backendtestprozesse wurden beendet. Bestehender Backendprozess bleibt unverändert.

## Verbleibende Grenzen

Fortschreibung 05.10.2026: separate API-/Kontobegrenzungen, Backendparallelität und Datenbankzeitlimits sind ergänzt; [Sicherheitsnachtrag und Nachweise](website-security.md). Die nachstehende Aussage zu damals fehlenden Anfragegrenzen beschreibt den früheren Auditstand. Vollständige Rangfolge vor Seitenaufteilung, globale Schreibsperren und fehlende Lastabnahme bleiben offen.

Der Auditpunkt zur Verfügbarkeit bleibt bestehen: vollständiges Laden und Sortieren des berechtigten Bestands vor Seitenaufteilung, fehlende separate Begrenzung der Verzeichnisanfragen und Bereinigungen mit globalen Schreibsperren. Kein tatsächlicher Ausfall wurde reproduziert; eine Lastabnahme für große Eventbestände ist offen. Redaktionelle Freitexte werden nicht automatisch auf geschützte Orts-/Zeitangaben geprüft. Bereits ausgelieferte Informationen können nicht aus Empfängerkopien zurückgerufen werden. Die exakt 168 Stunden nach tatsächlichem Ende geltende Speicherfrist bleibt nach bestehender Nutzerentscheidung bestehen.

Die gezielte Nachprüfung bestätigt die Behebung dieser drei Befunde im lokalen Umfang. Sie ist keine allgemeine Sicherheits- oder Produktionsfreigabe. Keine Remote-Migration, Veröffentlichung, Installation, Staging, Commit oder Push. Vorhandene Arbeit wurde erhalten; eigene Änderungen auf `codex/security-event-policy-fixes`.
