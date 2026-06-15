/* Lokka Web-Push – Background Service Worker.
 *
 * 1) Firebase-Web-Config unten eintragen (Firebase Console → Projekt-
 *    einstellungen → Deine Web-App → SDK-Konfiguration).
 * 2) Diese Datei MUSS unter web/firebase-messaging-sw.js liegen und wird
 *    automatisch mit der Web-App ausgeliefert.
 */
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'TODO',
  authDomain: 'TODO',
  projectId: 'TODO',
  messagingSenderId: 'TODO',
  appId: 'TODO',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'Lokka', {
    body: n.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const route = data.route || '/';
  event.waitUntil(clients.openWindow(route));
});
