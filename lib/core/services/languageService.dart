import 'dart:convert';

import 'package:flutter/services.dart';

import '../constants/appStrings.dart';

class LanguageService {
  const LanguageService._(this._texts);

  final Map<String, String> _texts;

  static Future<LanguageService> loadDefault() {
    return load(locale: AppStrings.defaultLocale);
  }

  static Future<LanguageService> load({required String locale}) async {
    try {
      final content = await rootBundle.loadString('assets/i18n/$locale.json');
      final json = jsonDecode(content) as Map<String, dynamic>;
      return LanguageService._(
        json.map((key, value) => MapEntry(key, value.toString())),
      );
    } catch (_) {
      if (locale != AppStrings.fallbackLocale) {
        return load(locale: AppStrings.fallbackLocale);
      }
      return LanguageService.fallback();
    }
  }

  factory LanguageService.fallback() {
    return const LanguageService._({
      'app.name': 'Lokka',
      'landing.headline': 'Lokale Deals. Direkt in deiner Wallet.',
      'landing.subline':
          'Entdecke Shops, sammle Stempel und sichere dir Vorteile in deiner Nähe.',
      'landing.login': 'Einloggen',
      'landing.register': 'Noch kein Konto? Registrieren',
      'landing.demo': 'Demo ansehen',
      'auth.error.signInAgain': 'Bitte melde dich erneut an.',
      'landing.merchantLogin': 'Geschäftlich? Für Händler einloggen',
      'auth.merchantPending.approvedTitle':
          'Dein Geschäftskonto ist freigeschaltet.',
      'auth.merchantPending.approvedLine':
          'Du kannst jetzt dein Dashboard öffnen und deine Module vorbereiten.',
      'auth.merchantPending.rejectedTitle': 'Deine Anfrage wurde abgelehnt.',
      'auth.merchantPending.rejectedLine':
          'Bitte kontaktiere den Support, wenn du Rückfragen zur Prüfung hast.',
      'auth.merchantPending.blockedTitle': 'Dein Konto ist gesperrt.',
      'auth.merchantPending.blockedLine':
          'Bitte kontaktiere den Support, damit wir den nächsten Schritt klären können.',
      'auth.merchantPending.pausedTitle': 'Dein Konto ist pausiert.',
      'auth.merchantPending.pausedLine':
          'Dein Geschäftskonto ist aktuell nicht vollständig aktiv. Der Support hilft dir weiter.',
      'auth.merchantPending.pendingTitle': 'Deine Händlerprüfung läuft.',
      'auth.merchantPending.pendingLine1':
          'Wir prüfen dein Geschäftskonto und melden uns bald telefonisch oder per E-Mail bei dir.',
      'auth.merchantPending.pendingLine2':
          'In der Regel dauert die Freischaltung maximal einen Arbeitstag.',
      'auth.merchantPending.pendingLine3':
          'Danach schalten wir dein Konto frei.',
      'merchant.support.title': 'Support',
      'merchant.support.subtitle':
          'Schreib uns, wenn etwas nicht funktioniert oder du Hilfe brauchst.',
      'merchant.support.newTicket': 'Neue Anfrage',
      'merchant.support.whatsapp': 'WhatsApp Support',
      'merchant.support.emptyTitle': 'Noch keine Anfragen',
      'merchant.support.emptyMessage':
          'Wenn du Hilfe brauchst, erstelle eine kurze Anfrage oder schreibe uns per WhatsApp.',
      'merchant.support.sheetTitle': 'Wie können wir helfen?',
      'merchant.support.typeLabel': 'Art der Anfrage',
      'merchant.support.message': 'Nachricht',
      'merchant.support.reply': 'Antwort schreiben',
      'merchant.support.sendTicket': 'Anfrage senden',
      'merchant.support.send': 'Senden',
      'merchant.support.type.problem': 'Problem',
      'merchant.support.type.question': 'Frage',
      'merchant.support.type.billing': 'Rechnung',
      'merchant.support.type.featureRequest': 'Funktion wünschen',
      'merchant.support.status.open': 'Offen',
      'merchant.support.status.inProgress': 'In Arbeit',
      'merchant.support.status.closed': 'Geschlossen',
      'merchant.support.whatsappText':
          'Hallo Lokka, ich brauche Hilfe zu meinem Geschäftskonto ...',
      'merchant.invite.title': 'Einladen',
      'merchant.invite.subtitle':
          'Teile deinen persönlichen Link mit Kunden oder anderen Geschäften.',
      'merchant.invite.customerTitle': 'Kunden einladen',
      'merchant.invite.customerSubtitle':
          'Teile deine Kundenkarte und bringe Menschen in deine Wallet.',
      'merchant.invite.merchantTitle': 'Händler einladen',
      'merchant.invite.merchantSubtitle':
          'Empfiehl Lokka an andere lokale Geschäfte.',
      'merchant.invite.copy': 'Link kopieren',
      'merchant.invite.copied': 'Link kopiert.',
      'merchant.invite.whatsapp': 'WhatsApp',
      'merchant.invite.shareText': 'Schau dir Lokka an:',
      'merchant.invite.opens': 'Öffnungen',
      'merchant.invite.used': 'genutzt',
      'merchant.features.title': 'Meine Systeme',
      'merchant.features.subtitle': 'Wähle, was dein Shop heute wirklich nutzt.',
      'merchant.features.tooltip':
          'Aktive Systeme erscheinen im Dashboard. Ausgeschaltete Systeme bleiben für Kunden verborgen.',
      'merchant.features.enabled': 'Aktiv',
      'merchant.features.disabled': 'Aus',
      'merchant.features.required': 'Immer aktiv',
      'merchant.features.comingSoon': 'Demnaechst',
      'merchant.features.feedPosts': 'Beiträge & Aktionen',
      'merchant.features.feedPostsTip':
          'Beiträge sind die Basisfunktion und bleiben immer aktiv.',
      'merchant.features.loyaltyGroup': 'Kundenbindung',
      'merchant.features.loyaltyGroupTip':
          'Stempel und Punkte helfen Stammkunden beim Wiederkommen.',
      'merchant.features.stampCards': 'Stempelkarten',
      'merchant.features.stampCardsTip': 'Digitale Stempel für Stammkunden.',
      'merchant.features.pointsSystems': 'Punkte',
      'merchant.features.pointsSystemsTip':
          'Punkte pro Einkauf sammeln lassen.',
      'merchant.features.catalogGroup': 'Speisekarte & Katalog',
      'merchant.features.catalog': 'Speisekarte',
      'merchant.features.catalogTip':
          'Artikel, Speisen, Preise und optionale Bestellungen pflegen.',
      'merchant.features.futureTitle': 'Bald für deinen Shop',
      'merchant.features.futureTip':
          'Diese Systeme bleiben geschlossen, bis sie offiziell freigegeben sind.',
      'merchant.features.coupons': 'Gutscheine',
      'merchant.features.couponsPortal': 'Gutschein-Portal',
      'merchant.features.couponsTip': 'Rabatte und Vorteile verwalten.',
      'merchant.features.orders': 'Bestellungen',
      'merchant.features.ordersTip':
          'Bestellungen später im Merchant-Bereich verwalten.',
      'merchant.features.tables': 'Tische',
      'merchant.features.tablesTip':
          'Tischbereiche und QR-Links vorbereiten.',
      'merchant.features.campaigns': 'Gewinnspiel',
      'merchant.features.campaignsTip':
          'Organizer für Aktionen, bald verfügbar.',
      'merchant.features.shifts': 'Schichtplan',
      'merchant.features.shiftsTip': 'Teamplanung, bald verfügbar.',
      'merchant.features.deliveryService': 'Lieferservice (Westend Süd)',
      'merchant.features.deliveryServiceTip':
          'Vorbereitet, bleibt bis zur Freigabe geschlossen.',
      'merchant.features.reservations': 'Reservierung',
      'merchant.features.reservationsTip':
          'Reservierungen, Wartelisten und Plätze, bald verfügbar.',
      'merchant.features.release.midOctober': 'Mitte Oktober',
      'merchant.features.release.endSeptember': 'Ende September',
      'merchant.features.release.endOctoberWestend': 'Ende Oktober',
      'merchant.featureGate.title': 'Funktion ausgeschaltet',
      'merchant.featureGate.subtitle':
          'Aktiviere diese Funktion zuerst, damit der Bereich nutzbar wird.',
      'merchant.featureGate.tooltip':
          'Ausgeschaltete Funktionen bleiben geschuetzt und können in Funktionen aktiviert werden.',
      'merchant.featureGate.emptyTitle': 'Noch nicht aktiviert',
      'merchant.featureGate.emptyMessage':
          'Dieser Bereich ist vorbereitet, aber in deinem Dashboard aktuell ausgeschaltet.',
      'merchant.featureGate.action': 'Funktionen öffnen',
      'common.all': 'Alle',
      'common.ready': 'Bereit',
      'common.error': 'Fehler',
      'common.errorTitle': 'Das hat nicht geklappt.',
      'common.retry': 'Erneut versuchen',
      'common.loading': 'Lädt',
      'common.back': 'Zurück',
      'common.cancel': 'Abbrechen',
      'common.refresh': 'Aktualisieren',
      'common.active': 'Aktiv',
      'common.inactive': 'Inaktiv',
      'common.ok': 'Verstanden',
      'common.edit': 'Bearbeiten',
      'common.save': 'Speichern',
      'common.delete': 'Löschen',
      'common.private': 'Privat',
      'common.public': 'Öffentlich',
      'common.name': 'Name',
      'common.description': 'Beschreibung',
      'common.sortOrder': 'Reihenfolge',
      'common.moveUp': 'Nach oben',
      'common.moveDown': 'Nach unten',
      'common.activate': 'Aktivieren',
      'common.deactivate': 'Deaktivieren',
      'common.available': 'Verfügbar',
      'common.unavailable': 'Nicht verfügbar',
      'common.euro': 'Euro',
      'common.uploadImage': 'Bild hochladen',
      'common.replaceImage': 'Bild ersetzen',
      'common.copyLink': 'Link kopieren',
      'day.monday': 'Montag',
      'day.tuesday': 'Dienstag',
      'day.wednesday': 'Mittwoch',
      'day.thursday': 'Donnerstag',
      'day.friday': 'Freitag',
      'day.saturday': 'Samstag',
      'day.sunday': 'Sonntag',
      'merchant.dashboard.loadErrorTitle':
          'Dashboard konnte nicht geladen werden.',
      'merchant.dashboard.noMerchantTitle': 'Geschäftsdaten nicht gefunden',
      'merchant.dashboard.noMerchantMessage':
          'Melde dich ab und prüfe, ob dein Händlerkonto vollständig angelegt wurde.',
      'merchant.dashboard.shopPreview': 'Shop ansehen',
      'merchant.dashboard.scanner': 'Scanner',
      'merchant.dashboard.systems': 'Systeme',
      'merchant.dashboard.systemsTip':
          'Aktive Tools für dein lokales Geschäft.',
      'merchant.dashboard.management': 'Verwaltung',
      'merchant.dashboard.managementSubtitle': 'Sortiment, Shopdaten und Support.',
      'merchant.dashboard.managementSheetSubtitle':
          'Alles, was du im Alltag schnell bearbeiten willst.',
      'merchant.dashboard.catalogTools': 'Sortiment verwalten',
      'merchant.dashboard.catalogToolsSubtitle':
          'Kategorien, Artikel und Tische.',
      'merchant.dashboard.catalogToolsTip':
          'Hier findest du alles rund um dein Sortiment.',
      'merchant.dashboard.enableInFeatures': 'In Funktionen aktivieren.',
      'merchant.dashboard.preparedSoon':
          'Dieser Bereich ist vorbereitet und wird bald verbunden.',
      'merchant.dashboard.notConnected': 'Dieser Bereich ist vorbereitet.',
      'merchant.dashboard.disabledTitle': '{title} ist ausgeschaltet',
      'merchant.dashboard.disabledMessage':
          'Du hast diese Funktion nicht aktiviert. Sie ist deshalb im Dashboard gesperrt.',
      'merchant.dashboard.disabledShort': 'Ausgeschaltet',
      'merchant.dashboard.yourShop': 'Dein Geschäft',
      'merchant.dashboard.today': 'Heute im Blick',
      'merchant.dashboard.todaySubtitle':
          'Kurzstatus aus deinen echten Shop-Daten.',
      'merchant.dashboard.localPartner': 'Lokaler Partner',
      'merchant.dashboard.modules': 'Module',
      'merchant.dashboard.soon': 'Bald',
      'merchant.dashboard.scanCustomer': 'Kunde scannen',
      'merchant.dashboard.scanCustomerTip':
          'Punkte, Stempel oder Bestellung prüfen',
      'merchant.dashboard.startPost': 'Beitrag starten',
      'merchant.dashboard.feedHub': 'Beiträge & Aktionen',
      'merchant.dashboard.feedHubTip':
          'Beiträge bleiben immer aktiv und bringen Kunden in deinen Shop.',
      'merchant.dashboard.newPost': 'Neuer Beitrag',
      'merchant.dashboard.newPostTip':
          'News, Hinweise, neue Ware oder einfache Angebote posten.',
      'merchant.dashboard.newAction': 'Neue Aktion',
      'merchant.dashboard.newActionTip':
          'Aktionen mit Vorlagen starten. Der Editor hilft dir beim Aufbau.',
      'merchant.dashboard.feedManage': 'Verwaltung',
      'merchant.features.save': 'Änderungen speichern',
      'merchant.features.unsaved': 'Nicht gespeichert',
      'merchant.features.confirmTitle': 'Funktionen speichern?',
      'merchant.features.confirmMessage':
          'Änderungen können beeinflussen, was Kunden sehen und welche Bereiche dein Team nutzt. Prüfe kurz, ob alles passt.',
      'merchant.features.confirmSave': 'Ja, speichern',
      'merchant.features.catalogOnly': 'Nur Speisekarte',
      'merchant.features.catalogOnlyTip':
          'Kunden sehen Bilder, Zutaten und Preise. Es gibt keine Bestellung.',
      'merchant.features.catalogOrderQrCashier': 'QR-Bestellung an der Kasse',
      'merchant.features.catalogOrderQrCashierTip':
          'Beispiel: Kunde wählt Artikel und zeigt an der Kasse einen QR-Code vor.',
      'merchant.features.catalogOrderSendCashier': 'An Terminal senden',
      'merchant.features.catalogOrderSendCashierTip':
          'Beispiel: Kunde schickt die Auswahl an deine Bestellseite oder dein Kassengerät.',
      'merchant.features.catalogTableOrders': 'Tischbestellung',
      'merchant.features.catalogTableOrdersTip':
          'Kunden bestellen über einen Tisch-QR mit Tischbezug.',
      'merchant.features.catalogStaffMode': 'Mitarbeiter-Modus',
      'merchant.features.catalogStaffModeTip':
          'Nur dein Personal sendet Bestellungen – Kunden sehen keinen Senden-Button.',
      'merchant.features.catalogDineInTakeaway': 'Vor Ort / Mitnehmen',
      'merchant.features.catalogDineInTakeawayTip':
          'Kunden wählen im Warenkorb zwischen „Vor Ort" und „Mitnehmen".',
      'merchant.features.catalogPickupTime': 'Abholzeit',
      'merchant.features.catalogPickupTimeTip':
          'Bei „Mitnehmen" kann der Kunde eine gewünschte Abholzeit angeben.',
      'merchant.customers.title': 'Kunden',
      'merchant.customers.subtitle': 'Alle Teilnehmer aus deinem Kundenbereich.',
      'merchant.customers.tooltip':
          'Hier siehst du echte Kunden aus deiner Kunden-Collection.',
      'merchant.customers.emptyTitle': 'Noch keine Kunden',
      'merchant.customers.emptyMessage':
          'Sobald Kunden Stempel, Punkte, Coupons oder Bestellungen nutzen, erscheinen sie hier.',
      'merchant.customers.unknownName': 'Unbekannter Kunde',
      'merchant.customers.lastVisit': 'Letzter Besuch',
      'merchant.customers.noSystem': 'Noch kein System',
      'merchant.customers.filter.all': 'Alle',
      'merchant.customers.filter.stamps': 'Stempel',
      'merchant.customers.filter.points': 'Punkte',
      'merchant.customers.filter.coupons': 'Coupons',
      'merchant.customers.filter.orders': 'Bestellungen',
      'merchant.customers.filter.lastVisited': 'Zuletzt besucht',
      'merchant.customers.system.stamps': 'Stempel',
      'merchant.customers.system.points': 'Punkte',
      'merchant.customers.system.coupons': 'Coupons',
      'merchant.customers.system.orders': 'Bestellung',
      'merchant.stamps.title': 'Stempelkarten',
      'merchant.stamps.subtitle':
          'Erstelle digitale Karten, die Kunden gern vollmachen.',
      'merchant.stamps.tooltip':
          'Aktive Karten laufen sofort für Kunden. Entwürfe bleiben nur für dich sichtbar.',
      'merchant.stamps.emptyTitle': 'Noch keine Stempelkarte',
      'merchant.stamps.emptyMessage':
          'Starte mit einer einfachen Karte und veröffentliche sie erst, wenn alles passt.',
      'merchant.stamps.create': 'Stempelkarte erstellen',
      'merchant.stamps.editTitle': 'Stempelkarte bearbeiten',
      'merchant.stamps.editSubtitle':
          'Bedingung, Belohnung und Look in Ruhe vorbereiten.',
      'merchant.stamps.editTooltip':
          'Speichere als Entwurf oder veröffentliche nach Bestätigung.',
      'merchant.stamps.untitled': 'Unbenannte Karte',
      'merchant.stamps.previewTitle': 'Deine Stempelkarte',
      'merchant.stamps.previewReward': 'Belohnung nach voller Karte',
      'merchant.stamps.rewardPrefix': 'Belohnung:',
      'merchant.stamps.stamps': 'Stempel',
      'merchant.stamps.saveDraft': 'Entwurf speichern',
      'merchant.stamps.saved': 'Stempelkarte gespeichert.',
      'merchant.stamps.publish': 'Veröffentlichen',
      'merchant.stamps.pause': 'Pausieren',
      'merchant.stamps.archive': 'Archivieren',
      'merchant.stamps.custom': 'Eigene Anzahl',
      'merchant.stamps.customCount': 'Eigene Stempelanzahl',
      'merchant.stamps.status.draft': 'Entwurf',
      'merchant.stamps.status.active': 'Aktiv',
      'merchant.stamps.status.paused': 'Pausiert',
      'merchant.stamps.status.archived': 'Archiv',
      'merchant.stamps.condition.visit': 'Besuch',
      'merchant.stamps.condition.minimumAmount': 'Mindestbetrag',
      'merchant.stamps.condition.item': 'Bestimmter Artikel',
      'merchant.stamps.condition.custom': 'Eigene Regel',
      'merchant.stamps.reward.custom': 'Freitext',
      'merchant.stamps.reward.item': 'Artikel',
      'merchant.stamps.advancedDesign': 'Erweiterte Designoptionen',
      'merchant.stamps.gradient': 'Farbverlauf',
      'merchant.stamps.backgroundColor': 'Hintergrundfarbe',
      'merchant.stamps.gradientColor': 'Verlaufsfarbe',
      'merchant.stamps.accentColor': 'Stempelfarbe',
      'merchant.stamps.textColor': 'Textfarbe',
      'merchant.stamps.shape.circle': 'Rund',
      'merchant.stamps.shape.square': 'Eckig',
      'merchant.stamps.shape.softSquare': 'Weich eckig',
      'merchant.stamps.shape.diamond': 'Raute',
      'merchant.stamps.content.icon': 'Icon',
      'merchant.stamps.content.char': 'Zeichen',
      'merchant.stamps.icon.star': 'Stern',
      'merchant.stamps.icon.gift': 'Geschenk',
      'merchant.stamps.icon.coffee': 'Kaffee',
      'merchant.stamps.icon.food': 'Essen',
      'merchant.stamps.icon.heart': 'Herz',
      'merchant.stamps.icon.local': 'Lokal',
      'merchant.stamps.image.side': 'Seitlich',
      'merchant.stamps.image.top': 'Oben',
      'merchant.stamps.image.background': 'Hintergrund',
      'merchant.stamps.imageLocked': 'Bildposition bleibt: {placement}',
      'merchant.stamps.removeImage': 'Bild entfernen',
      'merchant.stamps.style.noir': 'Noir',
      'merchant.stamps.style.mint': 'Mint',
      'merchant.stamps.style.cream': 'Warm',
      'merchant.stamps.style.berry': 'Berry',
      'merchant.stamps.section.name': 'Name',
      'merchant.stamps.section.nameTip':
          'Kurz und klar, damit Kunden den Vorteil sofort verstehen.',
      'merchant.stamps.section.condition': 'Sammelbedingung',
      'merchant.stamps.section.conditionTip':
          'Lege fest, wann ein Kunde einen Stempel bekommen darf.',
      'merchant.stamps.section.stamps': 'Anzahl Stempel',
      'merchant.stamps.section.stampsTip':
          'Weniger Stempel fuehlen sich schneller erreichbar an.',
      'merchant.stamps.section.reward': 'Belohnung',
      'merchant.stamps.section.rewardTip':
          'Die Belohnung sollte klar genug sein, dass dein Team sie versteht.',
      'merchant.stamps.section.design': 'Design',
      'merchant.stamps.section.designTip':
          'Bilder werden vor dem Upload lokal verkleinert und komprimiert.',
      'merchant.stamps.section.preview': 'Vorschau',
      'merchant.stamps.section.previewTip':
          'So wirkt die Karte später in der Wallet.',
      'merchant.stamps.section.publish': 'Veröffentlichen',
      'merchant.stamps.section.publishTip':
          'Erst nach deiner Bestätigung wird die Karte aktiv.',
      'merchant.stamps.field.title': 'Name der Karte',
      'merchant.stamps.field.subtitle': 'Kurzer Untertitel',
      'merchant.stamps.field.minimumAmount': 'Mindestbetrag in Euro',
      'merchant.stamps.field.requiredItem': 'Artikel für Stempel',
      'merchant.stamps.field.conditionText': 'Eigene Sammelregel',
      'merchant.stamps.field.rewardItem': 'Belohnungsartikel',
      'merchant.stamps.field.rewardTitle': 'Belohnung',
      'merchant.stamps.field.rewardDescription': 'Hinweis zur Belohnung',
      'merchant.stamps.field.requiredStamps': 'Stempelanzahl',
      'merchant.stamps.field.stampContent': 'Zeichen oder Emoji',
      'merchant.stamps.publishInfo':
          'Du kannst mehrere aktive Karten gleichzeitig nutzen. Veränderungen an aktiven Karten bitte klar mit deinem Team abstimmen.',
      'merchant.stamps.publishTitle': 'Stempelkarte aktivieren?',
      'merchant.stamps.publishMessage':
          'Nach der Bestätigung wird die Karte aktiv.',
      'merchant.stamps.pauseTitle': 'Stempelkarte pausieren?',
      'merchant.stamps.pauseMessage':
          'Die Karte bleibt gespeichert, ist aber nicht aktiv.',
      'merchant.stamps.archiveTitle': 'Stempelkarte archivieren?',
      'merchant.stamps.archiveMessage':
          'Archivierte Karten bleiben für deine Historie erhalten und werden nicht mehr aktiv angezeigt.',
      'merchant.stamps.deleteTitle': 'Entwurf löschen?',
      'merchant.stamps.deleteMessage':
          'Dieser Entwurf wird dauerhaft entfernt.',
      'merchant.stamps.error.title':
          'Bitte gib einen Namen für die Karte ein.',
      'merchant.stamps.error.reward': 'Bitte gib eine Belohnung ein.',
      'merchant.stamps.error.minimumAmount':
          'Bitte gib einen gültigen Mindestbetrag ein.',
      'merchant.stamps.error.item': 'Bitte wähle einen Artikel aus.',
      'merchant.stamps.error.rewardItem':
          'Bitte wähle einen Belohnungsartikel aus.',
      'merchant.stamps.noItems':
          'Noch keine Artikel vorhanden. Du kannst Freitext nutzen oder später Artikel im Sortiment anlegen.',
      'merchant.points.title': 'Punkte',
      'merchant.points.subtitle':
          'Punkte sammeln lassen und Belohnungen vorbereiten.',
      'merchant.points.tooltip':
          'Ein Punktesystem kann aktiv sein. Belohnungen kannst du separat aktivieren.',
      'merchant.points.emptyTitle': 'Noch kein Punktesystem',
      'merchant.points.emptyMessage':
          'Lege fest, wie viele Punkte Kunden pro Euro sammeln.',
      'merchant.points.defaultSystem': 'Lokka Punkte',
      'merchant.points.pointsPerEuro': 'Punkt(e) pro Euro',
      'merchant.points.points': 'Punkte',
      'merchant.points.systemSection': 'Punktesystem',
      'merchant.points.rewardsSection': 'Belohnungen',
      'merchant.points.createSystem': 'System anlegen',
      'merchant.points.createReward': 'Belohnung anlegen',
      'merchant.points.saveDraft': 'Entwurf speichern',
      'merchant.points.saved': 'Gespeichert.',
      'merchant.points.activate': 'Aktivieren',
      'merchant.points.pause': 'Pausieren',
      'merchant.points.archive': 'Archivieren',
      'merchant.points.status.draft': 'Entwurf',
      'merchant.points.status.active': 'Aktiv',
      'merchant.points.status.paused': 'Pausiert',
      'merchant.points.status.archived': 'Archiv',
      'merchant.points.systemEditTitle': 'Punktesystem bearbeiten',
      'merchant.points.systemEditSubtitle':
          'Punkte pro Euro klar und einfach einstellen.',
      'merchant.points.systemEditTip':
          'Beim Aktivieren wird ein anderes aktives Punktesystem automatisch pausiert.',
      'merchant.points.rewardEditTitle': 'Belohnung bearbeiten',
      'merchant.points.rewardEditSubtitle':
          'Lege fest, wofür Kunden Punkte einloesen können.',
      'merchant.points.rewardEditTip':
          'Bilder werden vor dem Upload lokal zugeschnitten und komprimiert.',
      'merchant.points.field.systemTitle': 'Name',
      'merchant.points.field.pointsPerEuro': 'Punkte pro Euro',
      'merchant.points.field.rewardTitle': 'Belohnung',
      'merchant.points.field.requiredPoints': 'Benoetigte Punkte',
      'merchant.points.field.rewardItem': 'Artikel',
      'merchant.points.field.discountText': 'Rabatt, z. B. 10 Prozent',
      'merchant.points.reward.custom': 'Freitext',
      'merchant.points.reward.item': 'Artikel',
      'merchant.points.reward.discount': 'Rabatt',
      'merchant.points.rewardUntitled': 'Neue Belohnung',
      'merchant.points.rewardsEmptyTitle': 'Noch keine Belohnung',
      'merchant.points.rewardsEmptyMessage':
          'Lege eine einfache Belohnung an, zum Beispiel Kaffee, Rabatt oder Freitext.',
      'merchant.points.activateSystemTitle': 'Punktesystem aktivieren?',
      'merchant.points.activateSystemMessage':
          'Nur ein Punktesystem kann aktiv sein. Ein altes aktives System wird pausiert, bestehende Teilnehmer duerfen ihre Punkte weiter nutzen.',
      'merchant.points.pauseSystemTitle': 'Punktesystem pausieren?',
      'merchant.points.pauseSystemMessage':
          'Neue Kunden sammeln vorerst nicht weiter. Bestehende Teilnehmer duerfen ihre Punkte weiter nutzen.',
      'merchant.points.archiveSystemTitle': 'Punktesystem archivieren?',
      'merchant.points.archiveSystemMessage':
          'Das System bleibt gespeichert und wird nicht mehr aktiv genutzt.',
      'merchant.points.deleteSystemTitle': 'Entwurf löschen?',
      'merchant.points.deleteSystemMessage':
          'Dieser System-Entwurf wird dauerhaft entfernt.',
      'merchant.points.activateRewardTitle': 'Belohnung aktivieren?',
      'merchant.points.activateRewardMessage':
          'Nach der Bestätigung wird die Belohnung aktiv.',
      'merchant.points.pauseRewardTitle': 'Belohnung pausieren?',
      'merchant.points.pauseRewardMessage':
          'Die Belohnung bleibt gespeichert, ist aber nicht aktiv.',
      'merchant.points.archiveRewardTitle': 'Belohnung archivieren?',
      'merchant.points.archiveRewardMessage':
          'Archivierte Belohnungen bleiben für deine Historie erhalten.',
      'merchant.points.deleteRewardTitle': 'Entwurf löschen?',
      'merchant.points.deleteRewardMessage':
          'Dieser Belohnungs-Entwurf wird dauerhaft entfernt.',
      'merchant.points.error.systemTitle':
          'Bitte gib einen Namen für das Punktesystem ein.',
      'merchant.points.error.pointsPerEuro':
          'Bitte gib eine gültige Punktezahl pro Euro ein.',
      'merchant.points.error.rewardTitle':
          'Bitte gib einen Namen für die Belohnung ein.',
      'merchant.points.error.requiredPoints':
          'Bitte gib eine gültige Punktezahl ein.',
      'merchant.points.error.rewardItem': 'Bitte wähle einen Artikel aus.',
      'merchant.points.error.discountText':
          'Bitte beschreibe den Rabatt kurz.',
      'merchant.points.noItems':
          'Noch keine Artikel vorhanden. Nutze Freitext oder lege später Artikel im Sortiment an.',
      'merchant.points.mode.monthlyRewards': 'Monatliche Rewards',
      'merchant.points.mode.monthlyRewardsTip':
          'Kunden sammeln innerhalb eines Monats. Beispiel: Bei 50, 100 und 150 Punkten sieht der Kunde mehrere Stufen auf einer Skala. Am gewählten Tag startet der Monat neu.',
      'merchant.points.mode.pointsShopRewards': 'Punkteshop Rewards',
      'merchant.points.mode.pointsShopRewardsTip':
          'Kunden sammeln langfristig Punkte und loesen sie später gegen Rewards ein. Beispiel: 300 Punkte für einen Artikel oder 700 Punkte für ein groesseres Geschenk.',
      'merchant.points.monthlyResetDay': 'Reset-Tag',
      'merchant.points.monthlyResetDayTip':
          'Dieser Tag im Monat startet das monatliche Sammeln neu. Wenn ein Monat kuerzer ist, wird später sauber auf den Monatsletzten gelegt.',
      'merchant.points.modeSwitchWarningTitle': 'Modus wechseln?',
      'merchant.points.modeSwitchWarningMessage':
          'Bestehende Teilnehmer behalten ihre laufenden Punkte bis zur Frist. Neue Kunden nutzen danach den neuen Modus.',
      'merchant.points.modeSwitchConfirmTitle': 'Wirklich wechseln?',
      'merchant.points.modeSwitchConfirmMessage':
          'Der neue Modus gilt für neue Kunden. Bestehende Teilnehmer behalten ihre laufenden Punkte bis zur gesetzten Frist.',
      'merchant.points.modeSwitchConfirm': 'Ja, Modus wechseln',
      'merchant.points.deadlineDays': '{days} Tage',
      'merchant.points.rewardScale': 'Reward-Skala',
      'merchant.points.rewardScaleTip':
          'Die Zahl oben ist die benoetigte Punktzahl. Darunter steht kurz, was Kunden dafür bekommen.',
      'merchant.coupons.title': 'Gutscheine',
      'merchant.coupons.subtitle': 'Rabatte und Vorteile für deine Kunden.',
      'merchant.coupons.tooltip': 'Hier werden deine echten Gutscheine geladen.',
      'merchant.coupons.emptyTitle': 'Noch keine Gutscheine',
      'merchant.coupons.emptyMessage':
          'Sobald Gutscheine angelegt sind, erscheinen sie hier.',
      'merchant.coupons.create': 'Gutschein erstellen',
      'merchant.coupons.editTitle': 'Gutschein bearbeiten',
      'merchant.coupons.editSubtitle':
          'Code, Vorteil und Bild ruhig vorbereiten.',
      'merchant.coupons.editTooltip':
          'Gutscheine können als Entwurf gespeichert oder nach Bestätigung aktiviert werden.',
      'merchant.coupons.untitled': 'Unbenannter Gutschein',
      'merchant.coupons.previewTitle': 'Dein Gutschein',
      'merchant.coupons.previewValue': 'Vorteil für Kunden',
      'merchant.coupons.codes': 'Codes',
      'merchant.coupons.saveDraft': 'Entwurf speichern',
      'merchant.coupons.saved': 'Gutschein gespeichert.',
      'merchant.coupons.publish': 'Aktivieren',
      'merchant.coupons.pause': 'Pausieren',
      'merchant.coupons.archive': 'Archivieren',
      'merchant.coupons.type.percent': 'Prozent',
      'merchant.coupons.type.fixed': 'Euro Rabatt',
      'merchant.coupons.type.freeItem': 'Gratis Artikel',
      'merchant.coupons.type.custom': 'Eigener Vorteil',
      'merchant.coupons.status.draft': 'Entwurf',
      'merchant.coupons.status.active': 'Aktiv',
      'merchant.coupons.status.paused': 'Pausiert',
      'merchant.coupons.status.archived': 'Archiv',
      'merchant.coupons.section.base': 'Name',
      'merchant.coupons.section.baseTip':
          'Kurz und klar, damit Kunden den Vorteil sofort verstehen.',
      'merchant.coupons.section.value': 'Vorteil',
      'merchant.coupons.section.valueTip':
          'Beschreibe den Rabatt oder Vorteil so, dass dein Team ihn einloesen kann.',
      'merchant.coupons.section.codes': 'Codes',
      'merchant.coupons.section.codesTip':
          'Du kannst bis zu 100 Codes erzeugen. Einloesen wird später im Scanner angebunden.',
      'merchant.coupons.section.image': 'Bild',
      'merchant.coupons.section.imageTip':
          'Bilder werden vor dem Upload lokal zugeschnitten und komprimiert.',
      'merchant.coupons.section.publish': 'Aktivieren',
      'merchant.coupons.section.publishTip':
          'Aktiv wird der Gutschein erst nach deiner Bestätigung.',
      'merchant.coupons.field.title': 'Name des Gutscheins',
      'merchant.coupons.field.subtitle': 'Kurzer Untertitel',
      'merchant.coupons.field.valueText': 'Vorteil, z. B. 10 Prozent',
      'merchant.coupons.field.codePrefix': 'Code-Wunsch',
      'merchant.coupons.field.codeCount': 'Anzahl Codes, maximal 100',
      'merchant.coupons.oncePerCode': 'Einmal pro Code',
      'merchant.coupons.multiUse': 'Mehrfach nutzbar',
      'merchant.coupons.generateCodes': 'Codes erzeugen',
      'merchant.coupons.viewCodes': 'Alle Codes ansehen',
      'merchant.coupons.codesTitle': 'Alle Codes',
      'merchant.coupons.codesTip':
          'Markiere Codes, wenn sie eingeloest oder gesperrt sind.',
      'merchant.coupons.code.available': 'Verfügbar',
      'merchant.coupons.code.used': 'Eingeloest',
      'merchant.coupons.code.blocked': 'Gesperrt',
      'merchant.coupons.publishTitle': 'Gutschein aktivieren?',
      'merchant.coupons.publishMessage':
          'Nach der Bestätigung wird der Gutschein aktiv.',
      'merchant.coupons.archiveTitle': 'Gutschein archivieren?',
      'merchant.coupons.archiveMessage':
          'Archivierte Gutscheine bleiben für deine Historie erhalten und werden nicht mehr aktiv angezeigt.',
      'merchant.coupons.deleteTitle': 'Entwurf löschen?',
      'merchant.coupons.deleteMessage':
          'Dieser Gutschein-Entwurf wird dauerhaft entfernt.',
      'merchant.coupons.error.title':
          'Bitte gib einen Namen für den Gutschein ein.',
      'merchant.coupons.error.value': 'Bitte beschreibe den Vorteil kurz.',
      'merchant.orders.title': 'Bestellungen',
      'merchant.orders.subtitle': 'Bestellungen aus Speisekarte und Tischlinks.',
      'merchant.orders.tooltip':
          'Bestellungen sind nur aktiv, wenn du sie in Funktionen einschaltest.',
      'merchant.orders.emptyTitle': 'Noch keine Bestellungen',
      'merchant.orders.emptyMessage':
          'Sobald Kunden bestellen, erscheinen die Bestellungen hier.',
      'merchant.orders.summary.active': 'Aktiv',
      'merchant.orders.order': 'Bestellung',
      'merchant.orders.demoBadge': 'Test',
      'merchant.orders.filter.active': 'Aktiv',
      'merchant.orders.status.new': 'Neu',
      'merchant.orders.status.preparing': 'In Arbeit',
      'merchant.orders.status.done': 'Fertig',
      'merchant.orders.status.cancelled': 'Storniert',
      'merchant.orders.detailTitle': 'Bestellung',
      'merchant.orders.detailSubtitle':
          'Artikel prüfen und Status aktualisieren.',
      'merchant.orders.detailTooltip':
          'Bestellungen kommen aus aktiven Speisekarten-Systemen und können hier bearbeitet werden.',
      'merchant.orders.notFoundTitle': 'Bestellung nicht gefunden',
      'merchant.orders.notFoundMessage':
          'Diese Bestellung konnte nicht geladen werden.',
      'merchant.orders.total': 'Summe',
      'merchant.orders.items': 'Artikel',
      'merchant.orders.noItems': 'Keine Artikel gespeichert.',
      'merchant.orders.accept': 'Annehmen',
      'merchant.orders.markDone': 'Fertig markieren',
      'merchant.orders.cancelOrder': 'Stornieren',
      'merchant.orders.open': 'offen',
      'merchant.orders.searchHint': 'Code, Tisch oder Artikel suchen…',
      'merchant.orders.date.today': 'Heute',
      'merchant.orders.date.yesterday': 'Gestern',
      'merchant.orders.date.week': 'Woche',
      'merchant.orders.tableView': 'Tisch-Einsicht',
      'merchant.orders.tableViewSubtitle': 'Bestellungen pro Tisch ansehen.',
      'merchant.orders.tablesTitle': 'Tisch-Einsicht',
      'merchant.orders.tablesSubtitle': 'Bestellungen pro Tisch.',
      'merchant.orders.tablesTooltip': 'Alle Bestellungen gruppiert nach Tisch.',
      'merchant.orders.tablesEmptyTitle': 'Keine Tisch-Bestellungen',
      'merchant.orders.tablesEmptyMessage':
          'Sobald über einen Tischlink bestellt wird, erscheinen die Tische hier.',
      'merchant.orders.tableOrdersSubtitle': 'Alle Bestellungen dieses Tisches.',
      'merchant.orders.selectHint': 'Bestellung auswählen',
      'merchant.orders.fulfillmentQr': 'QR / Kasse',
      'merchant.catalog.title': 'Speisekarte',
      'merchant.catalog.subtitle':
          'Bilder, Zutaten, Preise und optionale Bestellungen.',
      'merchant.catalog.tooltip':
          'Ohne Bestellsystem ist die Speisekarte eine reine Ansicht.',
      'merchant.catalog.items': 'Artikel',
      'merchant.catalog.itemsTip':
          'Produkte, Speisen, Preise und Verfügbarkeit pflegen.',
      'merchant.catalog.itemsSubtitle':
          'Produkte, Preise und Verfügbarkeit.',
      'merchant.catalog.categories': 'Kategorien',
      'merchant.catalog.categoriesTip':
          'Gruppen helfen Kunden, Artikel schneller zu finden.',
      'merchant.catalog.categoriesSubtitle': 'Gruppen für dein Sortiment.',
      'merchant.catalog.tables': 'Tische',
      'merchant.catalog.tablesTip':
          'Tisch-QRs für spätere Bestellungen vorbereiten.',
      'merchant.catalog.tablesSubtitle': 'Bereiche, Tisch-QRs und Links.',
      'merchant.catalog.copyLink': 'Speisekarte-Link kopieren',
      'merchant.catalog.linkCopied': 'Link kopiert – bereit zum Teilen.',
      'merchant.catalog.design': 'Aussehen',
      'merchant.catalog.designSubtitle': 'Vorlage, Farbe und Darstellung.',
      'merchant.catalog.designTip':
          'Bestimme, wie Kunden deine Speisekarte sehen.',
      'merchant.menuDesign.title': 'Aussehen der Speisekarte',
      'merchant.menuDesign.subtitle': 'Wähle, wie Kunden deine Karte sehen.',
      'merchant.menuDesign.preview': 'Live-Vorschau öffnen',
      'merchant.catalog.qrCodes': 'QR-Codes & Links',
      'merchant.catalog.qrCodesSubtitle': 'Shop-Link, Tisch-QRs & Export.',
      'merchant.catalog.qrCodesTip': 'Teile deinen Shop oder zeige Tisch-QR-Codes.',
      'merchant.qr.title': 'QR-Codes & Links',
      'merchant.qr.subtitle': 'Links und QR-Codes zum Teilen und für die Tische.',
      'merchant.qr.tooltip': 'Teile den Shop-Link oder zeige Tisch-QR-Codes.',
      'merchant.qr.generalTitle': 'Allgemeiner Link',
      'merchant.qr.generalHint': 'Für Aushang, Theke oder zum Teilen.',
      'merchant.qr.tablesTitle': 'Tische',
      'merchant.qr.showQr': 'QR anzeigen',
      'merchant.qr.shareImage': 'Als Bild teilen',
      'merchant.runners.title': 'Runner',
      'merchant.runners.subtitle': 'Servicekräfte mit Name + PIN.',
      'merchant.runners.tooltip': 'Runner nehmen im Runner-Modus Bestellungen am Tisch auf.',
      'merchant.runners.add': 'Runner hinzufügen',
      'merchant.runners.edit': 'Runner bearbeiten',
      'merchant.runners.name': 'Name',
      'merchant.runners.pin': 'PIN',
      'merchant.runners.emptyTitle': 'Noch keine Runner',
      'merchant.runners.emptyMessage': 'Lege Servicekräfte mit Name und PIN an.',
      'merchant.runners.error.name': 'Bitte Name eingeben.',
      'merchant.runners.error.pin': 'Bitte einen PIN (mind. 4 Ziffern) eingeben.',
      'merchant.catalog.runners': 'Runner',
      'merchant.catalog.runnersSubtitle': 'Servicekräfte (Name + PIN).',
      'merchant.catalog.runnersTip': 'Verwalte deine Runner für den Tisch-Service.',
      'public.shop.runnerLogin': 'Runner anmelden',
      'public.shop.runnerLoginNeeded': 'Runner-Anmeldung nötig',
      'public.shop.runnerLoginAction': 'Anmelden',
      'public.shop.runnerLoggedIn': 'Angemeldet: {name}',
      'public.shop.runnerLogout': 'Abmelden',
      'public.shop.runnerPinHint': 'PIN eingeben',
      'public.shop.runnerWrongPin': 'Falscher PIN.',
      'merchant.features.catalogModeRunner': 'Runner-Modus',
      'merchant.features.catalogModeRunnerTip':
          'Nur Personal (Runner) nimmt Bestellungen am Tisch auf und sendet sie an Bestellungen.',
      'merchant.features.catalogModeTable': 'Bestellen am Tisch',
      'merchant.features.catalogModeTableTip':
          'Kunden scannen den Tisch-QR, bestellen selbst und senden direkt an Bestellungen.',
      'merchant.features.catalogModeCashier': 'Bestellen & an Kasse zeigen',
      'merchant.features.catalogModeCashierTip':
          'Kunde bekommt einen QR-Code; die Bestellung erscheint erst nach Bestätigung an der Kasse.',
      'merchant.features.catalogModeMenuOnly': 'Nur Speisekarte',
      'merchant.features.catalogModeMenuOnlyTip':
          'Reine Ansicht ohne Warenkorb; teilbarer QR-Code.',
      'merchant.orders.confirmCode': 'QR-Code bestätigen',
      'merchant.orders.confirmCodeHint': 'Bestellcode eingeben (z. B. LK-1234)',
      'merchant.orders.confirmCodeSubtitle': 'Vor-Kasse-Bestellung freigeben',
      'merchant.orders.confirmCodeDone': 'Bestellung freigegeben.',
      'merchant.orders.confirmCodeNotFound': 'Keine offene Bestellung mit diesem Code.',
      'merchant.itemTags.title': 'Hinweise',
      'merchant.itemTags.subtitle': 'Allergene und Zusatzstoffe.',
      'merchant.itemTags.tooltip':
          'Weise Artikeln Hinweise zu. Kunden sehen kompakte Codes mit Erklaerung.',
      'merchant.itemTags.allergens': 'Allergene',
      'merchant.itemTags.additives': 'Zusatzstoffe',
      'merchant.itemTags.add': 'Hinweis hinzufügen',
      'merchant.itemTags.code': 'Code',
      'merchant.itemTags.short': 'Hinweise',
      'merchant.itemTags.empty': 'Noch keine Hinweise.',
      'merchant.itemTags.standardTip': 'Standardhinweis, nicht löschbar.',
      'merchant.itemTags.showMore': 'Mehr anzeigen',
      'merchant.itemTags.showLess': 'Weniger anzeigen',
      'merchant.catalog.orders': 'Bestellungen',
      'merchant.catalog.ordersTip':
          'Bestellungen aus aktiven Speisekarten-Systemen ansehen.',
      'merchant.catalog.previewTitle': 'Kundensicht öffnen',
      'merchant.catalog.previewSubtitle':
          'Prüfe deine echte Speisekarte so, wie Kunden sie sehen.',
      'merchant.catalog.demoTitle': 'Kundensicht öffnen',
      'merchant.catalog.demoSubtitle':
          'Prüfe deine echte Speisekarte so, wie Kunden sie sehen.',
      'merchant.catalog.demoTip':
          'Diese Ansicht nutzt echte Kategorien und Artikel.',
      'merchant.catalog.demoEmptyTitle': 'Noch keine Artikel',
      'merchant.catalog.demoEmptyMessage':
          'Lege zuerst Kategorien und Artikel an.',
      'merchant.catalog.demoCart': 'Warenkorb',
      'merchant.catalog.demoCartEmpty': 'Noch nichts ausgewählt.',
      'merchant.catalog.demoOrder': 'Bestellung senden',
      'merchant.categories.subtitle':
          'Gruppen helfen Kunden, deine Artikel schneller zu finden.',
      'merchant.categories.add': 'Kategorie hinzufügen',
      'merchant.categories.edit': 'Kategorie bearbeiten',
      'merchant.categories.emptyTitle': 'Noch keine Kategorien',
      'merchant.categories.emptyMessage':
          'Lege deine erste Gruppe an, zum Beispiel Kaffee, Snacks oder Services.',
      'merchant.categories.emoji': 'Emoji',
      'merchant.categories.nameHint': 'z. B. Kaffee',
      'merchant.categories.emojiHint': 'z. B. Kaffee-Icon',
      'merchant.categories.iconUpload': 'Bild/Icon hochladen',
      'merchant.categories.iconReplace': 'Bild/Icon ersetzen',
      'merchant.categories.setPrivate': 'Privat setzen',
      'merchant.categories.deleteTitle': 'Kategorie löschen?',
      'merchant.categories.deleteHasItems':
          'Diese Kategorie enthält Artikel. Entferne oder verschiebe diese Artikel zuerst.',
      'merchant.categories.deleteMessage':
          'Diese Kategorie wird für Händler ausgeblendet.',
      'merchant.items.subtitle':
          'Hier pflegst du Produkte, Preise und Verfügbarkeit.',
      'merchant.items.add': 'Artikel hinzufügen',
      'merchant.items.edit': 'Artikel bearbeiten',
      'merchant.items.needCategory': 'Lege zuerst eine Kategorie an.',
      'merchant.items.chooseCategory': 'Bitte wähle eine Kategorie aus.',
      'merchant.items.emptyTitle': 'Noch keine Artikel',
      'merchant.items.emptyMessage':
          'Füge Produkte, Speisen oder Leistungen zu deinem Sortiment hinzu.',
      'merchant.items.price': 'Preis',
      'merchant.items.originalPrice': 'Alter Preis',
      'merchant.items.articleNumber': 'Artikelnummer',
      'merchant.items.oldPriceToggle': 'Aktionspreis (alter Preis)',
      'merchant.items.oldPriceTooltip':
          'Schalter an: Der alte Preis wird durchgestrichen über dem neuen Preis angezeigt – ideal für Rabatte und Aktionen.',
      'merchant.items.error.articleNumberTaken':
          'Diese Artikelnummer ist bereits vergeben. Bitte eine andere wählen.',
      'merchant.items.imageFormat': 'Bildformat',
      'merchant.items.imageSquare': '1:1 Quadrat',
      'merchant.items.imageWide': '16:9 Magazin',
      'merchant.items.options': 'Optionen',
      'merchant.items.optionsTip':
          'Lass Kunden wählen (z.B. Soße) oder Extras gegen Aufpreis dazubuchen. Mehrfachauswahl und Pflicht sind je Gruppe einstellbar.',
      'merchant.items.addOptionGroup': 'Optionsgruppe hinzufügen',
      'merchant.items.optionGroupTitle': 'Gruppentitel (z.B. Soße)',
      'merchant.items.optionMulti': 'Mehrfach',
      'merchant.items.optionRequired': 'Pflicht',
      'merchant.items.optionName': 'Option (z.B. Ketchup)',
      'merchant.items.optionPrice': 'Aufpreis',
      'merchant.items.addOption': 'Option hinzufügen',
      'merchant.items.preview': 'Artikelvorschau',
      'merchant.items.priceMissing': 'Preis fehlt',
      'merchant.items.deleteTitle': 'Artikel löschen?',
      'merchant.items.deleteMessage': '{name} wird aus deiner Ansicht entfernt.',
      'merchant.tables.subtitle':
          'Bereiche, Tisch-QRs und Links für deinen Katalog.',
      'merchant.tables.area': 'Bereich',
      'merchant.tables.chooseArea': 'Bitte wähle einen Bereich aus.',
      'merchant.tables.table': 'Tisch',
      'merchant.tables.addArea': 'Bereich hinzufügen',
      'merchant.tables.editArea': 'Bereich bearbeiten',
      'merchant.tables.deleteArea': 'Bereich löschen',
      'merchant.tables.addTable': 'Tisch hinzufügen',
      'merchant.tables.editTable': 'Tisch bearbeiten',
      'merchant.tables.deleteTable': 'Tisch löschen',
      'merchant.tables.emptyAreasTitle': 'Noch keine Bereiche',
      'merchant.tables.emptyAreasMessage':
          'Lege zuerst einen Bereich an, zum Beispiel Innenbereich, Außenbereich oder Terrasse.',
      'merchant.tables.emptyTitle': 'Noch keine Tische angelegt',
      'merchant.tables.emptyMessage':
          'Erstelle den ersten Tisch und teile danach den QR-Code.',
      'merchant.tables.areaHint': 'z. B. Terrasse',
      'merchant.tables.label': 'Bezeichnung',
      'merchant.tables.labelHint': 'z. B. Tisch 1',
      'merchant.tables.seats': 'Plätze optional',
      'merchant.tables.seatsValue': '{count} Plätze',
      'merchant.tables.showQr': 'QR anzeigen',
      'merchant.tables.publicLinkHint':
          'Die öffentliche Katalogseite wird später mit diesem Tischlink verbunden.',
      'merchant.campaigns.title': 'Gewinnspiel',
      'merchant.campaigns.subtitle': 'Organizer für Aktionen, bald verfügbar.',
      'merchant.campaigns.tooltip':
          'Diese Funktion ist vorbereitet und wird später aktiviert.',
      'merchant.campaigns.emptyTitle': 'Kommt bald',
      'merchant.campaigns.emptyMessage':
          'Gewinnspiele bleiben sichtbar, sind aber noch nicht nutzbar.',
      'merchant.shifts.title': 'Schichtplan',
      'merchant.shifts.subtitle': 'Teamplanung, bald verfügbar.',
      'merchant.shifts.tooltip':
          'Diese Funktion ist vorbereitet und wird später aktiviert.',
      'merchant.shifts.emptyTitle': 'Kommt bald',
      'merchant.shifts.emptyMessage':
          'Der Schichtplan bleibt sichtbar, ist aber noch nicht nutzbar.',
      'merchant.delivery.title': 'Lieferservice',
      'merchant.delivery.subtitle':
          'Kommt bald (wird nur am Westend Süd verfügbar).',
      'merchant.delivery.tooltip':
          'Lieferservice ist vorbereitet, aber noch geschlossen.',
      'merchant.reservations.title': 'Reservierung',
      'merchant.reservations.subtitle': 'Kommt bald.',
      'merchant.reservations.tooltip':
          'Reservierungen werden später aktiviert.',
      'merchant.feedCreate.title': 'Neuer Beitrag',
      'merchant.feedCreate.subtitle':
          'Veröffentliche echte Angebote, News oder Aktionen.',
      'merchant.feedCreate.tooltip':
          'Beiträge erscheinen im Feed, wenn sie aktiv und öffentlich sind.',
      'merchant.feedCreate.required': 'Titel und Bild sind Pflicht.',
      'merchant.feedCreate.step.type': 'Typ',
      'merchant.feedCreate.step.typeTip':
          'Wähle, was Kunden sofort verstehen sollen: Angebot, News, neue Ware oder kurzer Hinweis.',
      'merchant.feedCreate.step.basic': 'Basis',
      'merchant.feedCreate.step.basicTip':
          'Titel, Untertitel und Beschreibung werden später im Feed angezeigt.',
      'merchant.feedCreate.step.rules': 'Regeln',
      'merchant.feedCreate.step.rulesTip':
          'Optional: Preis, Mindestbetrag oder Button für einen klaren nächsten Schritt.',
      'merchant.feedCreate.step.schedule': 'Zeit',
      'merchant.feedCreate.step.scheduleTip':
          'Ohne Zeitraum bleibt der Beitrag aktiv, bis du ihn pausierst oder archivierst.',
      'merchant.feedCreate.step.visibility': 'Sichtbar',
      'merchant.feedCreate.step.visibilityTip':
          'Private Beiträge bleiben vorbereitet und erscheinen nicht im öffentlichen Feed.',
      'merchant.feedCreate.step.preview': 'Prüfen',
      'merchant.feedCreate.step.previewTip':
          'Prüfe den Beitrag vor dem Veröffentlichen noch einmal in Ruhe.',
      'merchant.feedCreate.aiTitle': 'KI-Vorschlag',
      'merchant.feedCreate.aiTip':
          'Beschreibe kurz deine Idee. Lokka füllt die Felder vor, du kannst alles überschreiben.',
      'merchant.feedCreate.aiInput': 'Was soll beworben werden?',
      'merchant.feedCreate.aiButton': 'Vorschlag holen ({count}/5 heute)',
      'merchant.feedCreate.aiInputRequired':
          'Bitte beschreibe kurz, wofür du einen Vorschlag willst.',
      'merchant.feedCreate.aiEndpointMissing':
          'KI ist noch nicht verbunden. Bitte Cloudflare Endpoint eintragen.',
      'merchant.feedCreate.aiFailed':
          'Der Vorschlag konnte nicht erstellt werden.',
      'merchant.feedCreate.aiLimitReached':
          'Heute sind 5 KI-Vorschlaege erreicht.',
      'merchant.feedCreate.type.offerTip':
          'Rabatt, Vorteil oder lokales Angebot.',
      'merchant.feedCreate.type.newsTip': 'Kurze Neuigkeit aus deinem Shop.',
      'merchant.feedCreate.type.newProductTip':
          'Neue Ware, neues Gericht oder neue Leistung.',
      'merchant.feedCreate.type.happyHourTip': 'Zeitlich begrenzte Aktion.',
      'merchant.feedCreate.type.quickSellTip': 'Etwas soll schnell raus.',
      'merchant.feedCreate.type.infoTip': 'Ein klarer Hinweis für Kunden.',
      'merchant.feedCreate.minAmount': 'Mindestbetrag optional',
      'merchant.feedCreate.oldPrice': 'Alter Preis',
      'merchant.feedCreate.newPrice': 'Neuer Preis',
      'merchant.feedCreate.hasButton': 'Button anzeigen',
      'merchant.feedCreate.hasButtonTip':
          'Gut für Reservieren, Anrufen, Ansehen oder spätere Links.',
      'merchant.feedCreate.ctaLabel': 'Button-Text',
      'merchant.feedCreate.startsAt': 'Start',
      'merchant.feedCreate.endsAt': 'Ende',
      'merchant.feedCreate.noEndDate': 'Kein Enddatum',
      'merchant.feedCreate.noDate': 'Nicht gesetzt',
      'merchant.feedCreate.publicVisible': 'Öffentlich anzeigen',
      'merchant.feedCreate.publicVisibleTip':
          'Ausgeschaltet bleibt der Beitrag privat vorbereitet.',
      'merchant.feedCreate.visibility': 'Sichtbarkeit',
      'merchant.feedCreate.previewTitle': 'So könnte dein Titel aussehen',
      'merchant.feedCreate.previewSubtitle': 'Kurzer Untertitel für Kunden',
      'merchant.feedCreate.cta.more': 'Mehr ansehen',
      'merchant.feedCreate.cta.secure': 'Jetzt sichern',
      'merchant.feedCreate.cta.menu': 'Zur Speisekarte',
      'merchant.feedCreate.cta.order': 'Jetzt bestellen',
      'merchant.feedCreate.cta.ask': 'Anfragen',
      'merchant.feedCreate.cta.shop': 'Shop öffnen',
      'merchant.feedCreate.externalUrl': 'Externer Link',
      'merchant.feedCreate.linkedPostId': 'Beitrags-ID',
      'merchant.feedCreate.targetAudience': 'Zielgruppe',
      'merchant.feedCreate.audience.all': 'Alle',
      'merchant.feedCreate.audience.regulars': 'Stammkunden',
      'merchant.feedCreate.linkType': 'Verknuepfung',
      'merchant.feedCreate.link.none': 'Keine',
      'merchant.feedCreate.link.external': 'Externer Link',
      'merchant.feedCreate.link.shop': 'Shop',
      'merchant.feedCreate.link.catalog': 'Speisekarte',
      'merchant.feedCreate.link.feedPost': 'Beitrag',
      'merchant.feedCreate.postNow': 'Jetzt posten',
      'merchant.feedCreate.scheduleLater': 'Spaeter planen',
      'merchant.feedCreate.error.ctaLabel':
          'Bitte gib einen Button-Text ein.',
      'merchant.feedCreate.error.externalUrl':
          'Bitte gib einen externen Link ein.',
      'merchant.feedCreate.externalWarningTitle': 'Externen Link prüfen',
      'merchant.feedCreate.externalWarningMessage':
          'Der Link öffnet außerhalb von Lokka in einem neuen Tab.',
      'merchant.feedCreate.openExternal': 'Link öffnen',
      'merchant.feedManage.title': 'Feed verwalten',
      'merchant.feedManage.shortTitle': 'Verwalten',
      'merchant.feedManage.tooltip':
          'Hier pausierst oder änderst du bereits veröffentlichte Beiträge.',
      'merchant.feedManage.emptyTitle': 'Noch keine Beiträge',
      'merchant.feedManage.emptyMessage':
          'Sobald du Aktionen veröffentlicht hast, kannst du sie hier pausieren oder archivieren.',
      'merchant.feedManage.emptyFilterTitle': 'Hier ist gerade nichts',
      'merchant.feedManage.emptyFilterMessage':
          'Wechsle den Filter oder lade alle Beiträge.',
      'merchant.feedManage.noTitle': 'Ohne Titel',
      'merchant.feedManage.post': 'Beitrag',
      'merchant.feedManage.archived': 'Archiviert',
      'merchant.feedManage.paused': 'Pausiert',
      'merchant.feedManage.scheduled': 'Geplant',
      'merchant.feedManage.publishNow': 'Jetzt veröffentlichen',
      'merchant.feedManage.pause': 'Pausieren',
      'merchant.feedManage.archive': 'Archivieren',
      'merchant.feedManage.archiveTitle': 'Beitrag archivieren?',
      'merchant.feedManage.archiveMessage':
          'Der Beitrag verschwindet aus dem aktiven Feed, bleibt aber nachvollziehbar.',
      'merchant.feedManage.views': 'Aufrufe',
      'merchant.feedManage.clicks': 'Klicks',
      'merchant.feedManage.redemptions': 'Einloesungen',
      'merchant.feedManage.editSoonTitle':
          'Bearbeiten kommt als eigener Editor',
      'merchant.feedManage.editSoonMessage':
          'Hier kannst du den Beitrag schon privat setzen, pausieren oder archivieren.',
      'merchant.feedManage.editTitle': 'Beitrag bearbeiten',
      'merchant.feedManage.editTip':
          'Ändere nur das, was Kunden wirklich sehen sollen.',
      'merchant.feedManage.titleLabel': 'Titel',
      'merchant.feedManage.subtitleLabel': 'Untertitel',
      'merchant.feedManage.descriptionLabel': 'Beschreibung',
      'merchant.feedManage.ctaLabel': 'Button-Text',
      'merchant.feedManage.saveChanges': 'Änderungen speichern',
      'merchant.shop.title': 'Shopdaten',
      'merchant.shop.subtitle': 'Profil, Bilder und Öffnungszeiten.',
      'merchant.shop.tooltip':
          'Diese Daten sehen Kunden in deinem öffentlichen Profil.',
      'merchant.shop.section.base': 'Basisdaten',
      'merchant.shop.section.address': 'Adresse',
      'merchant.shop.section.categoryArea': 'Kategorie & Area',
      'merchant.shop.section.openingHours': 'Öffnungszeiten',
      'merchant.shop.businessName': 'Firmenname',
      'merchant.shop.nameUnified': 'Shop-/Firmenname',
      'merchant.shop.publicNotice': 'Hinweis',
      'merchant.shop.country': 'Land',
      'merchant.shop.countryFixed': 'Land: Deutschland (DE)',
      'merchant.shop.editOpeningHours': 'Öffnungszeiten bearbeiten',
      'merchant.shop.geoTitle': 'Geoapify-Vorschau',
      'merchant.shop.geoQueryLabel': 'Wird gesendet',
      'merchant.shop.geoResolve': 'Adresse prüfen',
      'merchant.shop.geoNotFound': 'Adresse nicht gefunden',
      'merchant.shop.geoHint': 'Das wird als Adresse + Koordinaten gespeichert.',
      'merchant.shop.maxCategories': 'Maximal 2 Kategorien',
      'merchant.shop.save': 'Shopdaten speichern',
      'merchant.shop.images': 'Bilder',
      'merchant.shop.logoTitle': 'Logo bearbeiten',
      'merchant.shop.logoChange': 'Logo ändern',
      'merchant.shop.logoRemove': 'Logo entfernen',
      'merchant.shop.section.social': 'Social Media',
      'merchant.shop.social.website': 'Webseite',
      'merchant.shop.social.instagram': 'Instagram',
      'merchant.shop.social.tiktok': 'TikTok',
      'merchant.shop.social.facebook': 'Facebook',
      'merchant.shop.galleryHint':
          'Bis zu 5 Shop-Fotos. Eins davon ist dein Cover.',
      'merchant.shop.galleryCover': 'Cover',
      'merchant.shop.gallerySetCover': 'Als Cover',
      'merchant.shop.phoneNotVerified': 'Telefon: Nicht verifiziert',
      'merchant.shop.phoneWarning':
          'Bitte verifizieren, bevor dein Shop öffentlich sichtbar wird.',
      'merchant.shop.verifyPhone': 'Telefonnummer verifizieren',
      'merchant.shop.phoneMarked':
          'Telefonnummer als verifiziert markiert.',
      'merchant.shop.profilePublic':
          'Dein Shop kann öffentlich sichtbar sein.',
      'merchant.shop.profilePrivate':
          'Dein Shop bleibt privat, bis alles vollständig ist.',
      'merchant.shop.closed': 'Geschlossen',
      'merchant.shop.from': 'Von',
      'merchant.shop.to': 'Bis',
      'merchant.shop.addBreak': 'Pause / zweite Zeit hinzufügen',
      'merchant.shop.applyAll': 'Für alle Tage übernehmen',
      'merchant.shop.applyWorkdays': 'Werktage übernehmen',
      'merchant.shop.saved': 'Shopdaten gespeichert.',
      'merchant.shop.privateTitle': 'Shop bleibt privat',
      'merchant.shop.defaultShop': 'Dein Shop',
      'merchant.shop.logo': 'Logo',
      'merchant.shop.cover': 'Cover',
      'feed.type.offer': 'Angebot',
      'feed.type.news': 'Neuigkeit',
      'feed.type.newProduct': 'Neue Ware',
      'feed.type.happyHour': 'Happy Hour',
      'feed.type.quickSell': 'Schnell weg',
      'feed.type.info': 'Info',
      'public.shop.shop': 'Shop',
      'public.shop.notFoundTitle': 'Shop nicht gefunden',
      'public.shop.notFoundMessage':
          'Dieser Katalog ist aktuell nicht verfügbar.',
      'public.shop.emptyTitle': 'Noch keine Artikel',
      'public.shop.emptyMessage':
          'Dieser Shop hat den Katalog noch nicht gefüllt.',
      'public.shop.table': 'Tisch {table}',
      'public.shop.cartEmpty': 'Wähle Artikel aus der Karte.',
      'public.shop.menu': 'Speisekarte',
      'public.shop.language': 'Sprache',
      'public.shop.cart': 'Warenkorb',
      'public.shop.clear': 'Leeren',
      'public.shop.add': 'Hinzufügen',
      'public.shop.order': 'Bestellen',
      'public.shop.orderWithCount': 'Bestellen ({count})',
      'public.shop.orderSent': 'Bestellung ist angekommen.',
      'public.shop.note': 'Wunsch / Notiz',
      'public.shop.noteHint': 'z. B. ohne Zwiebeln',
      'public.shop.tableDelivery': 'Kommt an {table}',
      'public.shop.orderConfirmedTitle': 'Bestellung gesendet',
      'public.shop.orderConfirmedMessage': 'Deine Bestellung ist beim Betrieb angekommen.',
      'public.shop.qrConfirmTitle': 'Zeig diesen Code an der Kasse',
      'public.shop.qrConfirmMessage':
          'Deine Bestellung ist gespeichert. Zeig den Code oder QR an der Kasse zum Bezahlen.',
      'public.shop.orderCode': 'Bestellnummer',
      'public.shop.statusNew': 'Eingegangen',
      'public.shop.statusPreparing': 'In Arbeit',
      'public.shop.statusDone': 'Fertig',
      'public.shop.recommendTitle': 'Lust auf mehr?',
      'public.shop.recommendSubtitle': 'Swipe & leg direkt nach.',
      'public.shop.added': 'Hinzugefügt',
      'public.shop.backToShop': 'Zurück zum Shop',
      'public.shop.serviceType': 'Bestellart',
      'public.shop.dineIn': 'Vor Ort',
      'public.shop.takeaway': 'Mitnehmen',
      'public.shop.tableSection': 'Tisch / Platz',
      'public.shop.tableChoose': 'Tisch wählen',
      'public.shop.tableNone': 'Kein Tisch',
      'public.shop.pickupTime': 'Abholzeit',
      'public.shop.pickupTimeChoose': 'Abholzeit wählen',
      'public.shop.sendOrder': 'Bestellung senden',
      'public.shop.qrCashier': 'QR-Code für die Kasse',
      'public.shop.staffOrderHint': 'Deine Bestellung wird vom Personal aufgenommen.',
      'public.shop.chooseTableHint': 'Bitte wähle deinen Tisch, um die Bestellung abzuschicken.',
      'public.shop.itemNote': 'Extra / Notiz (optional)',
      'public.shop.itemNoteHint': 'z. B. ohne Zwiebeln',
      'public.shop.required': 'Pflicht',
      'public.shop.chooseRequired': 'Pflichtfeld wählen',
      'public.shop.pickup': 'Abholung',
      'public.shop.pickupNote': 'Abholung im Laden',
      'public.shop.tableDeliveryNote': 'Kommt an deinen Tisch',
      'public.shop.itemsLabel': 'Artikel',
      'public.shop.backToMenu': 'Zurück zur Karte',
      'public.shop.call': 'Anrufen',
      'public.shop.website': 'Website',
      'public.shop.directions': 'Karte',
      'public.shop.hoursTitle': 'Öffnungszeiten',
      'public.shop.closed': 'Geschlossen',
      'public.shop.impressumTitle': 'Impressum',
      'public.shop.impressumBusiness': 'Geschäft',
      'public.shop.impressumOwner': 'Inhaber',
      'public.shop.impressumAddress': 'Adresse',
      'public.shop.impressumPhone': 'Telefon',
      'public.shop.impressumEmail': 'E-Mail',
      'public.shop.impressumMissing': 'Noch keine Angaben hinterlegt.',
      'public.shop.catalogDisabledTitle': 'Katalog nicht aktiv',
      'public.shop.catalogDisabledMessage':
          'Dieser Shop zeigt seine Speisekarte aktuell nicht öffentlich.',
      'feed.cta.externalTitle': 'Externen Link öffnen?',
      'feed.cta.externalMessage':
          'Du verlässt Lokka und öffnest die Seite in einem neuen Tab.',
      'feed.cta.open': 'Öffnen',
      'feed.cta.openFailed':
          'Der Link konnte hier nicht automatisch geöffnet werden.',
      'feed.cta.unavailableTitle': 'Aktion',
      'feed.cta.unavailableMessage':
          'Diese Aktion ist vorbereitet, aber noch nicht vollständig verbunden.',
    });
  }

  String text(String key) => _texts[key] ?? key;
}
