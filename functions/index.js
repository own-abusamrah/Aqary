const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// ─── Helper ───────────────────────────────────────────────────────────────────

async function getUserRole(uid) {
  const doc = await db.collection("users").doc(uid).get();
  return doc.exists ? doc.data().role : null;
}

async function isAdmin(uid) {
  const role = await getUserRole(uid);
  return role === "admin";
}

// ─── sendPushOnNotificationCreate ────────────────────────────────────────────

exports.sendPushOnNotificationCreate = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap) => {
    const notification = snap.data();
    if (!notification.userId) return null;

    const userDoc = await db.collection("users").doc(notification.userId).get();
    if (!userDoc.exists) return null;

    const token = userDoc.data().fcmToken;
    if (!token) return null;

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: notification.title || "Aqary",
          body: notification.body || "",
        },
        data: {
          type: String(notification.type || ""),
          linkedId: String(notification.linkedId || ""),
        },
        android: { priority: "high" },
      });
    } catch (e) {
      console.error("FCM error:", e);
    }
    return null;
  });

// ─── registerOrLoginUser ──────────────────────────────────────────────────────

exports.registerOrLoginUser = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const uid = context.auth.uid;
  const { name, phone, email, role, fcmToken } = data;

  const userRef = db.collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (userDoc.exists) {
    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (fcmToken) updates.fcmToken = fcmToken;
    await userRef.update(updates);
    return { isNewUser: false, role: userDoc.data().role };
  }

  const validRoles = ["buyer", "seller", "provider"];
  const finalRole = validRoles.includes(role) ? role : "buyer";

  await userRef.set({
    name: name || "",
    email: email || "",
    phone: phone || "",
    role: finalRole,
    isBlocked: false,
    subscriptionPlan: "free",
    subscriptionStatus: "none",
    fcmToken: fcmToken || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { isNewUser: true, role: finalRole };
});

// ─── savePendingRegistration ──────────────────────────────────────────────────

exports.savePendingRegistration = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "Login required");

    const { name, email, phone, role } = data;
    await db
      .collection("pending_registrations")
      .doc(context.auth.uid)
      .set({
        name: name || "",
        email: email || "",
        phone: phone || "",
        role: role || "buyer",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { success: true };
  },
);

// ─── onLogout ─────────────────────────────────────────────────────────────────

exports.onLogout = functions.https.onCall(async (data, context) => {
  if (!context.auth) return { success: true };

  await db
    .collection("users")
    .doc(context.auth.uid)
    .update({
      fcmToken: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    })
    .catch(() => {});

  return { success: true };
});

// ─── getListings ──────────────────────────────────────────────────────────────

// إحداثيات مراكز المحافظات الأردنية
const GOVERNORATE_CENTERS = {
  Amman: { lat: 31.9539, lng: 35.9106, radiusKm: 40 },
  Zarqa: { lat: 32.0728, lng: 36.0878, radiusKm: 25 },
  Irbid: { lat: 32.5556, lng: 35.85, radiusKm: 30 },
  Aqaba: { lat: 29.5321, lng: 35.0063, radiusKm: 25 },
  Madaba: { lat: 31.7167, lng: 35.7933, radiusKm: 20 },
  Karak: { lat: 31.1833, lng: 35.7, radiusKm: 25 },
  Salt: { lat: 32.0392, lng: 35.7275, radiusKm: 20 },
  Mafraq: { lat: 32.3429, lng: 36.2035, radiusKm: 30 },
};

// حساب المسافة بين نقطتين بالكيلومتر (Haversine)
function distanceKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

exports.getListings = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const {
    area,
    landType,
    minPrice,
    maxPrice,
    minSize,
    maxSize,
    lastDocId,
    pageSize = 20,
  } = data;

  let query = db.collection("listings").where("status", "==", "active");

  // فلتر المحافظة بالمسافة الجغرافية بدل المقارنة النصية
  const govCenter =
    area && area !== "All Areas" ? GOVERNORATE_CENTERS[area] : null;

  if (landType) query = query.where("landType", "==", landType);

  const hasPriceFilter = minPrice != null || maxPrice != null;
  const hasSizeFilter = minSize != null || maxSize != null;

  if (hasPriceFilter) {
    if (minPrice != null) query = query.where("price", ">=", minPrice);
    if (maxPrice != null) query = query.where("price", "<=", maxPrice);
    query = query.orderBy("price", "asc").orderBy("createdAt", "desc");
  } else if (hasSizeFilter) {
    if (minSize != null) query = query.where("size", ">=", minSize);
    if (maxSize != null) query = query.where("size", "<=", maxSize);
    query = query.orderBy("size", "asc").orderBy("createdAt", "desc");
  } else {
    query = query.orderBy("createdAt", "desc");
  }

  // نجيب أكثر للفلترة الجغرافية لأننا سنفلتر بعد الجلب
  const fetchLimit = govCenter ? (pageSize + 1) * 5 : pageSize + 1;
  query = query.limit(fetchLimit);

  if (lastDocId) {
    const lastDoc = await db.collection("listings").doc(lastDocId).get();
    if (lastDoc.exists) query = query.startAfter(lastDoc);
  }

  const snap = await query.get();
  let docs = snap.docs;

  // فلترة جغرافية بالمسافة
  if (govCenter) {
    docs = docs.filter((d) => {
      const listing = d.data();
      if (listing.latitude == null || listing.longitude == null) return false;
      const dist = distanceKm(
        govCenter.lat,
        govCenter.lng,
        listing.latitude,
        listing.longitude,
      );
      return dist <= govCenter.radiusKm;
    });
  }

  const hasMore = docs.length > pageSize;
  const finalDocs = hasMore ? docs.slice(0, pageSize) : docs;

  return {
    listings: finalDocs.map((d) => ({ id: d.id, ...d.data() })),
    nextDocId: hasMore ? finalDocs[finalDocs.length - 1].id : null,
    hasMore,
  };
});

// ─── softDeleteListing ────────────────────────────────────────────────────────

exports.softDeleteListing = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const { listingId } = data;
  if (!listingId)
    throw new functions.https.HttpsError(
      "invalid-argument",
      "listingId required",
    );

  const ref = db.collection("listings").doc(listingId);
  const doc = await ref.get();
  if (!doc.exists)
    throw new functions.https.HttpsError("not-found", "Listing not found");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (doc.data().sellerId !== context.auth.uid && !userIsAdmin)
    throw new functions.https.HttpsError(
      "permission-denied",
      "Not your listing",
    );

  const batch = db.batch();

  // 1. حذف الإشعارات المرتبطة بهذا اللستنج
  const notifsSnap = await db
    .collection("notifications")
    .where("linkedId", "==", listingId)
    .get();
  notifsSnap.forEach((d) => batch.delete(d.ref));

  // 2. حذف contact requests المرتبطة وإشعاراتها
  const requestsSnap = await db
    .collection("contact_requests")
    .where("listingId", "==", listingId)
    .get();
  for (const reqDoc of requestsSnap.docs) {
    batch.delete(reqDoc.ref);
    const reqNotifsSnap = await db
      .collection("notifications")
      .where("linkedId", "==", reqDoc.id)
      .get();
    reqNotifsSnap.forEach((d) => batch.delete(d.ref));
  }

  // 3. حذف من favorites عند كل المشترين
  const favsSnap = await db
    .collection("favorites")
    .where("listingId", "==", listingId)
    .get();
  favsSnap.forEach((d) => batch.delete(d.ref));

  // 4. حذف الـ listing نفسه
  batch.delete(ref);

  await batch.commit();
  return { success: true };
});

// ─── setListingStatus ─────────────────────────────────────────────────────────

exports.setListingStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const { listingId, status } = data;
  const validStatuses = ["active", "hidden", "deleted"];
  if (!listingId || !validStatuses.includes(status))
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid arguments",
    );

  const ref = db.collection("listings").doc(listingId);
  const doc = await ref.get();
  if (!doc.exists)
    throw new functions.https.HttpsError("not-found", "Listing not found");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (doc.data().sellerId !== context.auth.uid && !userIsAdmin)
    throw new functions.https.HttpsError(
      "permission-denied",
      "Not your listing",
    );

  await ref.update({
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

// ─── onListingCreated ─────────────────────────────────────────────────────────

exports.onListingCreated = functions.firestore
  .document("listings/{listingId}")
  .onCreate(async (snap, context) => {
    const listing = snap.data();
    const listingId = context.params.listingId;

    const buyersSnap = await db
      .collection("users")
      .where("role", "==", "buyer")
      .where("isBlocked", "==", false)
      .get();

    const batch = db.batch();
    for (const buyer of buyersSnap.docs) {
      const notifRef = db.collection("notifications").doc();
      batch.set(notifRef, {
        userId: buyer.id,
        title: "New Listing Available",
        body: `${listing.area} — ${listing.price} JD`,
        type: "new_listing",
        linkedId: listingId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return null;
  });

// ─── onListingUpdated ─────────────────────────────────────────────────────────

exports.onListingUpdated = functions.firestore
  .document("listings/{listingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === "active" && after.status !== "active") {
      const notifSnap = await db
        .collection("notifications")
        .where("linkedId", "==", context.params.listingId)
        .where("type", "==", "new_listing")
        .get();

      const batch = db.batch();
      for (const doc of notifSnap.docs) batch.delete(doc.ref);
      await batch.commit();
    }
    return null;
  });

// ─── onContactRequestCreated ──────────────────────────────────────────────────

exports.onContactRequestCreated = functions.firestore
  .document("contact_requests/{requestId}")
  .onCreate(async (snap) => {
    const req = snap.data();

    await db.collection("notifications").add({
      userId: req.sellerId,
      title: "New Contact Request",
      body: "A buyer is interested in your listing.",
      type: "contact_request",
      linkedId: snap.id,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  });

// ─── onContactRequestUpdated ──────────────────────────────────────────────────

exports.onContactRequestUpdated = functions.firestore
  .document("contact_requests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return null;

    const statusMsg =
      after.status === "approved"
        ? "Your contact request was approved! 🎉"
        : "Your contact request was rejected.";

    await db.collection("notifications").add({
      userId: after.buyerId,
      title: "Contact Request Update",
      body: statusMsg,
      type: "contact_request_update",
      linkedId: change.after.id,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  });

// ─── getNearbyProviders ───────────────────────────────────────────────────────

exports.getNearbyProviders = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const { lat, lng, type, radiusKm = 50 } = data;

  // جلب كل البروفايدرز مع فلتر النوع إذا موجود
  let query = db.collection("providers").where("isHidden", "==", false);
  if (type) query = query.where("type", "==", type);

  const snap = await query.get();
  let providers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // إذا في موقع نحسب المسافة ونرتب، وإذا ما رجع أحد نرجع الكل
  if (lat != null && lng != null) {
    const delta = radiusKm / 111;
    const lngDelta = radiusKm / (111 * Math.cos((lat * Math.PI) / 180));

    const nearby = providers
      .filter(
        (p) =>
          p.latitude != null &&
          p.longitude != null &&
          Math.abs(p.latitude - lat) <= delta &&
          Math.abs(p.longitude - lng) <= lngDelta,
      )
      .map((p) => {
        const dLat = p.latitude - lat;
        const dLng = p.longitude - lng;
        p.distanceKm = Math.sqrt(dLat * dLat + dLng * dLng) * 111;
        return p;
      })
      .sort((a, b) => a.distanceKm - b.distanceKm);

    // لو في نتائج قريبة نستخدمها، وإلا نرجع الكل
    if (nearby.length > 0) providers = nearby;
  }

  return { providers };
});

// ─── setProviderHidden ────────────────────────────────────────────────────────

exports.setProviderHidden = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const { providerId, isHidden } = data;
  const userIsAdmin = await isAdmin(context.auth.uid);
  if (!userIsAdmin)
    throw new functions.https.HttpsError("permission-denied", "Admins only");

  await db
    .collection("providers")
    .doc(providerId)
    .update({ isHidden: !!isHidden });
  return { success: true };
});

// ─── updateBuyerLocation ──────────────────────────────────────────────────────

exports.updateBuyerLocation = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const { lat, lng } = data;
  if (lat == null || lng == null)
    throw new functions.https.HttpsError(
      "invalid-argument",
      "lat and lng required",
    );

  await db.collection("users").doc(context.auth.uid).update({
    lastLat: lat,
    lastLng: lng,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

// ─── setUserBlocked ───────────────────────────────────────────────────────────

exports.setUserBlocked = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (!userIsAdmin)
    throw new functions.https.HttpsError("permission-denied", "Admins only");

  const { targetUid, isBlocked } = data;
  await db
    .collection("users")
    .doc(targetUid)
    .update({ isBlocked: !!isBlocked });

  if (isBlocked) {
    await auth.revokeRefreshTokens(targetUid).catch(() => {});
  }
  return { success: true };
});

// ─── deleteUser ───────────────────────────────────────────────────────────────

exports.deleteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (!userIsAdmin)
    throw new functions.https.HttpsError("permission-denied", "Admins only");

  const { targetUid } = data;
  await db.collection("users").doc(targetUid).update({ isBlocked: true });
  await auth.deleteUser(targetUid).catch(() => {});
  return { success: true };
});

// ─── adminGetUsers ────────────────────────────────────────────────────────────

exports.adminGetUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (!userIsAdmin)
    throw new functions.https.HttpsError("permission-denied", "Admins only");

  const { role, isBlocked } = data || {};
  let query = db.collection("users");
  if (role) query = query.where("role", "==", role);
  if (isBlocked != null) query = query.where("isBlocked", "==", isBlocked);

  const snap = await query.get();
  const users = snap.docs.map((d) => ({ uid: d.id, ...d.data() }));
  return { users };
});

// ─── adminDeleteListing ───────────────────────────────────────────────────────

exports.adminDeleteListing = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (!userIsAdmin)
    throw new functions.https.HttpsError("permission-denied", "Admins only");

  const { listingId } = data;
  await db.collection("listings").doc(listingId).update({
    status: "deleted",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

// ─── sendBroadcast (admin) ────────────────────────────────────────────────────

exports.sendBroadcast = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const userIsAdmin = await isAdmin(context.auth.uid);
  if (!userIsAdmin)
    throw new functions.https.HttpsError("permission-denied", "Admins only");

  const { title, body, targetRole } = data;
  let query = db.collection("users").where("isBlocked", "==", false);
  if (targetRole && targetRole !== "all")
    query = query.where("role", "==", targetRole);

  const snap = await query.get();
  const batch = db.batch();
  for (const user of snap.docs) {
    batch.set(db.collection("notifications").doc(), {
      userId: user.id,
      title,
      body,
      type: "broadcast",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return { sent: snap.size, total: snap.size };
});

// ─── sellerSendBroadcast ──────────────────────────────────────────────────────

exports.sellerSendBroadcast = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const role = await getUserRole(context.auth.uid);
  if (role !== "seller")
    throw new functions.https.HttpsError("permission-denied", "Sellers only");

  const { title, body } = data;
  const buyersSnap = await db
    .collection("users")
    .where("role", "==", "buyer")
    .where("isBlocked", "==", false)
    .get();

  const batch = db.batch();
  for (const user of buyersSnap.docs) {
    batch.set(db.collection("notifications").doc(), {
      userId: user.id,
      title,
      body,
      type: "seller_broadcast",
      linkedId: context.auth.uid,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return { sent: buyersSnap.size };
});

// ─── providerSendBroadcastNearby ──────────────────────────────────────────────

exports.providerSendBroadcastNearby = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "Login required");

    const role = await getUserRole(context.auth.uid);
    if (role !== "provider")
      throw new functions.https.HttpsError(
        "permission-denied",
        "Providers only",
      );

    const { title, body } = data;
    const providerDoc = await db
      .collection("providers")
      .doc(context.auth.uid)
      .get();
    if (!providerDoc.exists)
      throw new functions.https.HttpsError(
        "not-found",
        "Provider profile not found",
      );

    const { latitude, longitude } = providerDoc.data();
    const radiusKm = 30;
    const delta = radiusKm / 111;

    const buyersSnap = await db
      .collection("users")
      .where("role", "==", "buyer")
      .where("isBlocked", "==", false)
      .where("lastLat", ">=", latitude - delta)
      .where("lastLat", "<=", latitude + delta)
      .get();

    const lngDelta = radiusKm / (111 * Math.cos((latitude * Math.PI) / 180));
    const nearbyBuyers = buyersSnap.docs.filter((d) => {
      const u = d.data();
      return u.lastLng != null && Math.abs(u.lastLng - longitude) <= lngDelta;
    });

    const batch = db.batch();
    for (const user of nearbyBuyers) {
      batch.set(db.collection("notifications").doc(), {
        userId: user.id,
        title,
        body,
        type: "provider_broadcast",
        linkedId: context.auth.uid,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return { sent: nearbyBuyers.length };
  },
);

// ─── requestPremiumSubscription ───────────────────────────────────────────────

exports.requestPremiumSubscription = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "Login required");

    const uid = context.auth.uid;
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists)
      throw new functions.https.HttpsError("not-found", "User not found");

    const user = userDoc.data();
    if (!["buyer", "seller", "provider"].includes(user.role))
      throw new functions.https.HttpsError("permission-denied", "Not allowed");

    await db.collection("users").doc(uid).update({
      subscriptionStatus: "pending",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const adminsSnap = await db
      .collection("users")
      .where("role", "==", "admin")
      .get();
    const batch = db.batch();
    for (const adminDoc of adminsSnap.docs) {
      batch.set(db.collection("notifications").doc(), {
        userId: adminDoc.id,
        title: "Premium Request",
        body: `${user.name || user.email} requested a premium subscription.`,
        type: "premium_request",
        linkedId: uid,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return { success: true };
  },
);

// ─── adminGetPremiumRequests ──────────────────────────────────────────────────

exports.adminGetPremiumRequests = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "Login required");

    const userIsAdmin = await isAdmin(context.auth.uid);
    if (!userIsAdmin)
      throw new functions.https.HttpsError("permission-denied", "Admins only");

    const { statuses } = data || {};

    // Show premium requests from ALL users regardless of role
    // (buyer, provider, seller, ...) — not just buyers.
    const snap = await db.collection("users").get();
    let users = snap.docs.map((d) => ({ uid: d.id, ...d.data() }));

    if (statuses && statuses.length > 0) {
      users = users.filter((u) => statuses.includes(u.subscriptionStatus));
    } else {
      // No statuses requested: still only return users who actually have
      // a subscription status set (avoid dumping every user in the app).
      users = users.filter((u) => !!u.subscriptionStatus);
    }

    return { users };
  },
);

// ─── adminSetPremiumSubscription ──────────────────────────────────────────────

exports.adminSetPremiumSubscription = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "Login required");

    const userIsAdmin = await isAdmin(context.auth.uid);
    if (!userIsAdmin)
      throw new functions.https.HttpsError("permission-denied", "Admins only");

    const { targetUid, action, reason } = data;
    const validActions = ["approve", "reject", "revoke"];
    if (!validActions.includes(action))
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid action",
      );

    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    let notifBody = "";

    if (action === "approve") {
      updates.subscriptionPlan = "premium";
      updates.subscriptionStatus = "active";
      notifBody = "Your premium subscription has been approved! 🎉";
    } else if (action === "reject") {
      updates.subscriptionStatus = "rejected";
      notifBody = reason
        ? `Your request was rejected: ${reason}`
        : "Your premium request was rejected.";
    } else if (action === "revoke") {
      updates.subscriptionPlan = "free";
      updates.subscriptionStatus = "none";
      notifBody = "Your premium subscription has been revoked.";
    }

    await db.collection("users").doc(targetUid).update(updates);

    await db.collection("notifications").add({
      userId: targetUid,
      title: "Subscription Update",
      body: notifBody,
      type: "subscription_update",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  },
);

// ─── getMyPremiumPins ─────────────────────────────────────────────────────────

exports.getMyPremiumPins = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const snap = await db
    .collection("users")
    .doc(context.auth.uid)
    .collection("premium_alert_pins")
    .get();

  const pins = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { pins };
});

// ─── upsertPremiumPin ─────────────────────────────────────────────────────────

exports.upsertPremiumPin = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const uid = context.auth.uid;
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists)
    throw new functions.https.HttpsError("not-found", "User not found");

  const user = userDoc.data();
  if (
    user.subscriptionPlan !== "premium" ||
    user.subscriptionStatus !== "active"
  )
    throw new functions.https.HttpsError(
      "permission-denied",
      "Premium subscription required",
    );

  const { pinId, latitude, longitude, radiusKm, label } = data;
  const pinData = {
    latitude,
    longitude,
    radiusKm,
    label: label || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const pinsRef = db
    .collection("users")
    .doc(uid)
    .collection("premium_alert_pins");

  if (pinId) {
    await pinsRef.doc(pinId).update(pinData);
    return { pinId };
  } else {
    pinData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    const ref = await pinsRef.add(pinData);
    return { pinId: ref.id };
  }
});

// ─── deletePremiumPin ─────────────────────────────────────────────────────────

exports.deletePremiumPin = functions.https.onCall(async (data, context) => {
  if (!context.auth)
    throw new functions.https.HttpsError("unauthenticated", "Login required");

  const { pinId } = data;
  await db
    .collection("users")
    .doc(context.auth.uid)
    .collection("premium_alert_pins")
    .doc(pinId)
    .delete();
  return { success: true };
});
