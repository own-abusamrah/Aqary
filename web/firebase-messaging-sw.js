importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyC_K8wXHdCnVq09793_rGOoLZHcpG67DWE",
  authDomain: "aqary-app-e2cf4.firebaseapp.com",
  projectId: "aqary-app-e2cf4",
  messagingSenderId: "162532144093",
  appId: "1:162532144093:web:93c2f5ac68186df5007c34",
  storageBucket: "aqary-app-e2cf4.firebasestorage.app",
  measurementId: "G-YLHY7LQS80"
});

const messaging = firebase.messaging();