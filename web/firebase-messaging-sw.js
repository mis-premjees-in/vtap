importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCtQf4e4hP8EYGcXX0LpPTnQCBbhP0RFP8",
  authDomain: "vtap-6958b.firebaseapp.com",
  projectId: "vtap-6958b",
  storageBucket: "vtap-6958b.firebasestorage.app",
  messagingSenderId: "712249917483",
  appId: "1:712249917483:web:6ff7ab164814691ad72a6e",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/favicon.png"
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
