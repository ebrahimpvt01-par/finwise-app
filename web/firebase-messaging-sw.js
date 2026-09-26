// This file must live at: web/firebase-messaging-sw.js
// It lets notifications show up even when the FinWise tab isn't focused
// or is closed. Firebase's messaging SDK looks for this file automatically.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// Same config as in firebase_options.dart's `web` FirebaseOptions block.
// Copy the values over exactly - apiKey, appId, messagingSenderId, projectId.
firebase.initializeApp({
  apiKey: 'AIzaSyAIG918HZ_xjwGF4GdqOn9j2CdeZ_eMI2g',
  authDomain: 'finwise-app-1a295.firebaseapp.com',
  projectId: 'finwise-app-1a295',
  storageBucket: 'finwise-app-1a295.firebasestorage.app',
  messagingSenderId: '605356301232',
  appId: '1:605356301232:web:4ae7bd46ded375123a1475',
});

const messaging = firebase.messaging();

// Shows the notification when the app/tab is in the background.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Portfolio Update';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});