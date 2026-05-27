const { auth } = require("firebase-functions/v1");
const { logger } = require("firebase-functions/v2");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { geohashQueryBounds, distanceBetween } = require("geofire-common");

const GOOGLE_MAPS_API_KEY = defineSecret("GOOGLE_MAPS_API_KEY");
const WEATHER_API_KEY = defineSecret("WEATHER_API_KEY");
const COMETCHAT_APP_ID = defineSecret("COMETCHAT_APP_ID");
const COMETCHAT_REGION = defineSecret("COMETCHAT_REGION");
const COMETCHAT_AUTH_KEY = defineSecret("COMETCHAT_AUTH_KEY");

const COMETCHAT_SECRETS = [
  COMETCHAT_APP_ID,
  COMETCHAT_REGION,
  COMETCHAT_AUTH_KEY,
];

function cometChatApiBase(appId, region) {
  return `https://${appId}.api-${region}.cometchat.io/v3`;
}

async function cometChatCreateUserRest(uid, name, authKey, appId, region) {
  const response = await fetch(`${cometChatApiBase(appId, region)}/users`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: authKey,
    },
    body: JSON.stringify({ uid, name }),
  });
  if (response.ok) {
    return;
  }
  const body = await response.json().catch(() => ({}));
  const message = body?.error?.message || body?.message || response.statusText;
  const alreadyExists =
    response.status === 409 ||
    (typeof message === "string" &&
      /already\s*exist|duplicate|ERR_UID/i.test(message));
  if (alreadyExists) {
    return;
  }
  throw new HttpsError(
    "internal",
    `CometChat create user failed: ${message || response.status}`
  );
}

async function cometChatCreateAuthTokenRest(uid, authKey, appId, region) {
  const response = await fetch(
    `${cometChatApiBase(appId, region)}/users/${encodeURIComponent(uid)}/auth_tokens`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: authKey,
      },
      body: JSON.stringify({}),
    }
  );
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = body?.error?.message || body?.message || response.statusText;
    throw new HttpsError(
      "internal",
      `CometChat auth token failed: ${message || response.status}`
    );
  }
  const authToken = body?.data?.authToken;
  if (!authToken || typeof authToken !== "string") {
    throw new HttpsError("internal", "CometChat auth token missing in response.");
  }
  return authToken;
}

// Initialize the Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

const DEFAULT_INSTITUTION_ID = "eduvos_01";

/**
 * Returns true if the email's domain is listed on institutions/{id}.allowed_domains.
 */
async function emailDomainAllowed(email, institutionId = DEFAULT_INSTITUTION_ID) {
  if (!email || typeof email !== "string" || !email.includes("@")) {
    return false;
  }
  const domain = email.split("@").pop().trim().toLowerCase();
  const instSnap = await db.collection("institutions").doc(institutionId).get();
  if (!instSnap.exists) {
    return false;
  }
  const allowed = instSnap.data().allowed_domains;
  if (!Array.isArray(allowed)) {
    return false;
  }
  return allowed.some((d) => String(d).trim().toLowerCase() === domain);
}

// --- Discover feed helpers ---
/** Sort events without map coords after located events (must be finite for JSON). */
const DISCOVER_NO_COORD_DISTANCE_KM = 99999;
const DISCOVER_TABS = new Set(["All", "Community", "Music", "Film", "Arts", "Fitness", "Food", "Education"]);
const DISCOVER_TAG_BY_TAB = {
  Community: "community",
  Music: "music",
  Film: "film",
  Arts: "arts",
  Fitness: "fitness",
  Food: "food",
  Education: "education",
};

const EDUCATION_TAGS = ["education", "law", "stem", "coding", "biology", "technology", "engineering", "science", "math", "history"];

function parseFirestoreDate(field) {
  if (!field) return null;
  if (typeof field.toDate === "function") return field.toDate();
  return new Date(field);
}

function readLatLngFromLocation(location) {
  if (!location) return null;
  const lat = location.latitude ?? location._latitude;
  const lng = location.longitude ?? location._longitude;
  if (typeof lat === "number" && typeof lng === "number") {
    return { lat, lng };
  }
  return null;
}

function isEventUpcoming(eventData, now) {
  const startDate = parseFirestoreDate(eventData.timing?.startDate);
  const endDate = parseFirestoreDate(eventData.timing?.endDate);
  const effectiveEndDate =
    endDate || (startDate ? new Date(startDate.getTime() + 24 * 60 * 60 * 1000) : null);
  if (effectiveEndDate && effectiveEndDate < now) return false;
  return true;
}

async function loadUserDiscoverContext(uid) {
  const [userSnap, connectionsSnap, invitesSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("users").doc(uid).collection("connections").where("status", "==", "connected").get(),
    db.collection("users").doc(uid).collection("invites").get(),
  ]);

  const friendsSet = new Set();
  connectionsSnap.docs.forEach((doc) => friendsSet.add(doc.id));

  const invitesSet = new Set();
  invitesSnap.docs.forEach((doc) => invitesSet.add(doc.id));

  let gender = null;
  if (userSnap.exists) {
    const raw = userSnap.data().gender;
    if (raw && typeof raw === "string") {
      const normalized = raw.trim().toLowerCase();
      if (normalized === "male" || normalized === "female") {
        gender = normalized;
      }
    }
  }

  return { gender, friendsSet, invitesSet };
}

async function getHostFriendsSet(hostId, cache) {
  if (cache.has(hostId)) return cache.get(hostId);
  const hostFriends = new Set();
  const snap = await db
    .collection("users")
    .doc(hostId)
    .collection("connections")
    .where("status", "==", "connected")
    .get();
  snap.docs.forEach((doc) => hostFriends.add(doc.id));
  cache.set(hostId, hostFriends);
  return hostFriends;
}

function getCoHostIds(eventData) {
  const ids = eventData.co_host_ids || eventData.coHostIds || [];
  return Array.isArray(ids) ? ids.filter((id) => typeof id === "string" && id.length > 0) : [];
}

function isDirectFriendOfHostOrCohosts(friendsSet, hostId, coHostIds) {
  if (friendsSet.has(hostId)) return true;
  for (const coId of coHostIds) {
    if (friendsSet.has(coId)) return true;
  }
  return false;
}

function setsIntersect(setA, setB) {
  for (const id of setA) {
    if (setB.has(id)) return true;
  }
  return false;
}

async function passesVisibilityFilter(eventData, eventId, ctx, hostFriendsCache) {
  const visibility = eventData.audience?.visibility || "public";
  const hostId = eventData.metadata?.hostId || eventData.metadata?.host_id;
  if (!hostId) return false;

  if (visibility === "public") return true;

  if (visibility === "private") {
    const invitedUserIds =
      eventData.invitedUserIds ||
      eventData.invited_user_ids ||
      eventData.invitations ||
      eventData.audience?.invitedUserIds ||
      eventData.audience?.invited_user_ids ||
      [];
    const explicitlyInvited =
      Array.isArray(invitedUserIds) && invitedUserIds.includes(ctx.currentUserId);
    return ctx.invitesSet.has(eventId) || explicitlyInvited;
  }

  const coHostIds = getCoHostIds(eventData);

  if (visibility === "friendsOnly" || visibility === "friends_only") {
    return isDirectFriendOfHostOrCohosts(ctx.friendsSet, hostId, coHostIds);
  }

  if (visibility === "friendsOfFriends" || visibility === "friends_of_friends") {
    if (isDirectFriendOfHostOrCohosts(ctx.friendsSet, hostId, coHostIds)) {
      return true;
    }

    const idsToCheck = [...new Set([hostId, ...coHostIds])];
    const friendSets = await Promise.all(
      idsToCheck.map((id) => getHostFriendsSet(id, hostFriendsCache))
    );
    for (const hostFriends of friendSets) {
      if (setsIntersect(ctx.friendsSet, hostFriends)) return true;
    }
    return false;
  }

  if (visibility === "maleOnly" || visibility === "male_only") {
    return ctx.gender === "male";
  }

  if (visibility === "femaleOnly" || visibility === "female_only") {
    return ctx.gender === "female";
  }

  return false;
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function eventMatchesTab(eventData, tab) {
  if (tab === "All") return true;
  const tag = DISCOVER_TAG_BY_TAB[tab];
  if (!tag) return false;
  const tags = (eventData.tags || []).map((t) => String(t).toLowerCase());
  const category = eventData.category ? String(eventData.category).toLowerCase() : null;
  return tags.includes(tag) || category === tag;
}

function isWeekendEvent(eventData, now) {
  const startDate = parseFirestoreDate(eventData.timing?.startDate);
  if (!startDate) return false;

  const jsDay = now.getDay();
  const dartWeekday = jsDay === 0 ? 7 : jsDay;
  let daysToFriday = 5 - dartWeekday;
  if (dartWeekday === 6) daysToFriday = -1;
  if (dartWeekday === 7) daysToFriday = -2;

  const weekendStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  weekendStart.setDate(weekendStart.getDate() + daysToFriday);
  const weekendEnd = new Date(weekendStart);
  weekendEnd.setDate(weekendEnd.getDate() + 2);
  weekendEnd.setHours(23, 59, 59, 999);

  const end =
    parseFirestoreDate(eventData.timing?.endDate) ||
    new Date(startDate.getTime() + 24 * 60 * 60 * 1000);

  return startDate < weekendEnd && end > weekendStart;
}

function eventHasTag(eventData, tag) {
  const tags = (eventData.tags || []).map((t) => String(t).toLowerCase());
  const category = eventData.category ? String(eventData.category).toLowerCase() : null;
  return tags.includes(tag) || category === tag;
}

async function resolveHostProfiles(hostIds, hostDataCache) {
  const unique = [...new Set(hostIds.filter(Boolean))];
  await Promise.all(
    unique.map(async (hostId) => {
      if (hostDataCache.has(hostId)) return;
      const hSnap = await db.collection("users").doc(hostId).get();
      if (hSnap.exists) {
        const hData = hSnap.data();
        hostDataCache.set(hostId, {
          username: hData.username || hData.name || "",
          avatar: hData.profile_image_url || hData.avatar_url || "",
        });
      } else {
        hostDataCache.set(hostId, { username: "", avatar: "" });
      }
    })
  );
}

function sanitizeDistanceKm(distanceKm) {
  if (typeof distanceKm !== "number" || !Number.isFinite(distanceKm)) {
    return DISCOVER_NO_COORD_DISTANCE_KM;
  }
  return Math.round(distanceKm * 100) / 100;
}

function formatDiscoverCard(eventDoc, distanceKm, hostDataCache) {
  const eventData = eventDoc.data();
  const hostId =
    eventData.metadata?.hostId || eventData.metadata?.host_id || "";
  const cached = hostDataCache.get(hostId) || { username: "", avatar: "" };
  const startDate = parseFirestoreDate(eventData.timing?.startDate);

  return {
    id: eventDoc.id,
    title: eventData.title || "",
    poster_url: eventData.visuals?.posterUrl || eventData.visuals?.poster_url || "",
    start_time: startDate ? startDate.getTime() : null,
    location_name: eventData.location?.displayName || eventData.location?.display_name || "",
    distance_km: sanitizeDistanceKm(distanceKm),
    aurora_colors: eventData.visuals?.auroraColors || eventData.visuals?.aurora_colors || [],
    host_id: hostId,
    host_username: cached.username,
    host_avatar_url: cached.avatar,
    _eventData: eventData,
  };
}

function normalizedEventTags(eventData) {
  const tags = Array.isArray(eventData?.tags)
    ? eventData.tags.map((t) => String(t).toLowerCase())
    : [];
  const category = eventData?.category
    ? String(eventData.category).toLowerCase()
    : null;
  if (category && !tags.includes(category)) {
    tags.push(category);
  }
  return tags;
}

function stripInternalFields(card) {
  const { _eventData, ...rest } = card;
  return {
    ...rest,
    tags: normalizedEventTags(_eventData),
  };
}

function sortByDistance(cards) {
  return cards.sort((a, b) => a.distance_km - b.distance_km);
}

function takeTopNByDistance(cards, n) {
  return sortByDistance([...cards]).slice(0, n);
}

// 1. Request OTP Function (Locked to JHB)
exports.requestOtp = onCall(
  { region: "africa-south1" },
  async (request) => {
    const email = request.data.email;
    const authFlow = request.data.authFlow;

    // Security Layer 1: Domain Check (dynamic whitelist)
    if (!email || !(await emailDomainAllowed(email))) {
      throw new HttpsError("invalid-argument", "Must use a valid student email.");
    }

    const normalized = email.trim().toLowerCase();

    // Pre-flight profile check (optional: omitted on older clients / legacy deploys)
    if (authFlow === "login" || authFlow === "signup") {
      const snap = await db
        .collection("users")
        .where("email", "==", normalized)
        .limit(1)
        .get();
      const profileExists = !snap.empty;
      if (authFlow === "login" && !profileExists) {
        throw new HttpsError(
          "failed-precondition",
          "No account found. Please create one."
        );
      }
      if (authFlow === "signup" && profileExists) {
        throw new HttpsError(
          "failed-precondition",
          "Account already exists. Please log in."
        );
      }
    }

    // Generate a 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Store OTP in Firestore with a 5-minute expiration
    const expiration = new Date();
    expiration.setMinutes(expiration.getMinutes() + 5);

    await db.collection("otps").doc(normalized).set({
      otp: otp,
      expiresAt: expiration,
    });

    // Dev/testing: visible in Cloud Functions logs (remove before production launch).
    logger.info(`[TESTING] The OTP for ${normalized} is: ${otp}`);

    return { success: true };
  }
);

// 2. Verify OTP Function (Locked to JHB)
exports.verifyOtp = onCall(
  { region: "africa-south1" },
  async (request) => {
    const email = request.data.email;
    const otp = String(request.data.otp ?? "").trim();

    if (!email || !otp) {
      throw new HttpsError("invalid-argument", "Email and OTP are required.");
    }

    const normalized = email.trim().toLowerCase();

    // Fetch OTP (prefer normalized id; fall back to raw email for older requestOtp writes)
    let otpDocRef = db.collection("otps").doc(normalized);
    let otpDoc = await otpDocRef.get();
    if (!otpDoc.exists && email !== normalized) {
      otpDocRef = db.collection("otps").doc(email);
      otpDoc = await otpDocRef.get();
    }

    if (!otpDoc.exists) {
      throw new HttpsError("not-found", "No OTP requested for this email.");
    }

    const otpData = otpDoc.data();

    // Security Layer 2: Expiration Check
    const expiresAt = otpData.expiresAt;
    const expiresMs =
      expiresAt && typeof expiresAt.toDate === "function"
        ? expiresAt.toDate().getTime()
        : new Date(expiresAt).getTime();
    if (expiresMs < Date.now()) {
      throw new HttpsError("failed-precondition", "OTP has expired.");
    }

    // Security Layer 3: Value Check
    if (String(otpData.otp).trim() !== otp) {
      throw new HttpsError("invalid-argument", "Incorrect OTP.");
    }

    // OTP is valid! Delete the document
    await otpDocRef.delete();

    let userRecord;
    let isNewUser = false;

    try {
      // Check if user already exists in Firebase Auth
      userRecord = await admin.auth().getUserByEmail(normalized);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // User doesn't exist, create them in Auth
        userRecord = await admin.auth().createUser({
          email: normalized,
          emailVerified: true,
        });
        isNewUser = true;
      } else {
        throw new HttpsError("internal", "Error checking user status.");
      }
    }

    // Security Layer 4: Create a custom token
    const customToken = await admin.auth().createCustomToken(userRecord.uid);

    return {
      token: customToken,
      isNewUser: isNewUser
    };
  }
);

// 7. Weather Proxy Function
exports.weatherProxy = onCall(
  {
    region: "africa-south1",
    enforceAppCheck: true,
    secrets: [WEATHER_API_KEY]
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const { lat, lon, timestamp } = request.data;
    if (lat === undefined || lon === undefined || timestamp === undefined) {
      throw new HttpsError("invalid-argument", "lat, lon, and timestamp are required.");
    }

    const apiKey = WEATHER_API_KEY.value();
    
    // Using OpenWeatherMap One Call API 3.0 (provides 8 days of daily forecast)
    // If you don't have One Call 3.0, you can use the 5-day forecast API:
    // https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric
    const url = `https://api.openweathermap.org/data/3.0/onecall?lat=${lat}&lon=${lon}&exclude=minutely,hourly,alerts&appid=${apiKey}&units=metric`;

    try {
      const response = await fetch(url);
      if (!response.ok) {
        // Fallback to 5-day forecast if One Call 3.0 fails (e.g., if not subscribed)
        const fallbackUrl = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric`;
        const fallbackResponse = await fetch(fallbackUrl);
        const data = await fallbackResponse.json();
        
        if (!fallbackResponse.ok) {
           throw new Error(data.message || "Failed to fetch weather data");
        }

        // Process 5-day forecast data
        const eventDate = new Date(timestamp * 1000);
        const forecastList = data.list;
        
        // Find forecast closest to the timestamp
        const closest = forecastList.reduce((prev, curr) => {
          return (Math.abs(curr.dt - timestamp) < Math.abs(prev.dt - timestamp) ? curr : prev);
        });

        const diffDays = Math.ceil((eventDate - new Date()) / (1000 * 60 * 60 * 24));
        if (diffDays > 5) {
          return { is_distant_future: true };
        }

        return {
          averageTemp: Math.round(closest.main.temp),
          highTemp: Math.round(closest.main.temp_max),
          lowTemp: Math.round(closest.main.temp_min),
          conditionText: closest.weather[0].main,
          conditionCode: closest.weather[0].icon,
          is_distant_future: false
        };
      }

      const data = await response.json();
      const eventDate = new Date(timestamp * 1000);
      const today = new Date();
      
      // Calculate day difference
      const diffTime = eventDate - today;
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      // One Call 3.0 daily array has 8 days (index 0 to 7)
      if (diffDays < 0 || diffDays >= data.daily.length) {
        return { is_distant_future: true };
      }

      const forecast = data.daily[diffDays];
      
      return {
        averageTemp: Math.round(forecast.temp.day),
        highTemp: Math.round(forecast.temp.max),
        lowTemp: Math.round(forecast.temp.min),
        conditionText: forecast.weather[0].main,
        conditionCode: forecast.weather[0].icon,
        is_distant_future: false
      };

    } catch (error) {
      console.error("Weather API Proxy Error:", error);
      throw new HttpsError("internal", "Failed to fetch data from Weather API.");
    }
  }
);

// 3. Validate Student Email
exports.validateStudentEmail = onCall(
  { region: "africa-south1" },
  async (request) => {
    const email = request.data.email;
    if (!email) {
      throw new HttpsError("invalid-argument", "Email is required.");
    }

    const normalized = email.trim().toLowerCase();

    // Check Domain
    const domainAllowed = await emailDomainAllowed(normalized);
    if (!domainAllowed) {
      throw new HttpsError("permission-denied", "Please use your Student Email");
    }

    // Check User Existence
    let userExists = false;
    try {
      await admin.auth().getUserByEmail(normalized);
      userExists = true;
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        userExists = false;
      } else {
        throw new HttpsError("internal", "Error checking user status.");
      }
    }

    if (userExists) {
      throw new HttpsError("already-exists", "This email is already in use.");
    }
    return { success: true };
  }
);

// 4. Validate Username
exports.validateUsername = onCall(
  { region: "africa-south1" },
  async (request) => {
    const username = request.data.username;
    if (!username || typeof username !== "string") {
      throw new HttpsError("invalid-argument", "Username is required.");
    }

    const normalized = username.trim().toLowerCase();

    const snap = await db.collection("users").where("username", "==", normalized).limit(1).get();

    if (!snap.empty) {
      throw new HttpsError("already-exists", "This username is already taken.");
    }

    return { success: true };
  }
);

// Accept friend request — updates both users atomically (Admin SDK).
exports.acceptConnection = onCall(
  { region: "africa-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be signed in to accept a friend request."
      );
    }

    const currentUid = request.auth.uid;
    const targetUid = request.data?.targetUserId;

    if (!targetUid || typeof targetUid !== "string" || !targetUid.trim()) {
      throw new HttpsError("invalid-argument", "targetUserId is required.");
    }
    if (targetUid === currentUid) {
      throw new HttpsError("invalid-argument", "Cannot accept a request from yourself.");
    }

    const currentConnRef = db
      .collection("users")
      .doc(currentUid)
      .collection("connections")
      .doc(targetUid);
    const targetConnRef = db
      .collection("users")
      .doc(targetUid)
      .collection("connections")
      .doc(currentUid);

    const [currentConnSnap, targetConnSnap] = await Promise.all([
      currentConnRef.get(),
      targetConnRef.get(),
    ]);

    if (!currentConnSnap.exists) {
      throw new HttpsError("not-found", "No friend request found.");
    }

    const currentData = currentConnSnap.data() || {};
    if (currentData.status !== "pending") {
      throw new HttpsError("failed-precondition", "This request is no longer pending.");
    }
    if (currentData.initiated_by === currentUid) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot accept a request you sent."
      );
    }
    if (currentData.initiated_by && currentData.initiated_by !== targetUid) {
      throw new HttpsError("failed-precondition", "Invalid friend request.");
    }

    if (!targetConnSnap.exists) {
      throw new HttpsError(
        "not-found",
        "Friend request is incomplete. Ask them to send the request again."
      );
    }

    const targetData = targetConnSnap.data() || {};
    if (targetData.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "Friend request is out of sync on the other account."
      );
    }

    const batch = db.batch();
    const connectedAt = admin.firestore.FieldValue.serverTimestamp();

    batch.update(currentConnRef, { status: "connected", timestamp: connectedAt });
    batch.update(targetConnRef, { status: "connected", timestamp: connectedAt });
    batch.update(db.collection("users").doc(currentUid), {
      "counts.friends": admin.firestore.FieldValue.increment(1),
    });
    batch.update(db.collection("users").doc(targetUid), {
      "counts.friends": admin.firestore.FieldValue.increment(1),
    });

    await batch.commit();

    return { success: true };
  }
);

// 5. Initialize User Profile (Auth Trigger)
exports.initializeUserProfile = auth.user().onCreate(async (user) => {
  if (!user) return;

  const uid = user.uid;
  const email = user.email || "";

  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();

  // Only initialize if the document doesn't already exist
  if (!snap.exists) {
    await userRef.set({
      uid: uid,
      email: email.toLowerCase(),
      avatar_url: "",
      username: "",
      name: "",
      bio: "",
      social_links: {
        instagram: "",
        x: "",
        snapchat: "",
      },
      counts: {
        friends: 0,
        hosted: 0,
        joined: 0,
      },
      interests: [],
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`Initialized profile for user: ${uid}`);
  }
});

// 5b. Cleanup User Profile (Auth Delete Trigger)
exports.cleanupUserOnDelete = auth.user().onDelete(async (user) => {
  if (!user) return;
  const uid = user.uid;
  
  // Delete user document
  await db.collection("users").doc(uid).delete();
  
  // Optional: Delete other subcollections or associated data
  const scheduleSnap = await db.collection("users").doc(uid).collection("schedule").get();
  const batch = db.batch();
  scheduleSnap.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  console.log(`Cleaned up profile and schedule for deleted user: ${uid}`);
});

// 11. Delete User Account (Explicit Rollback)
exports.deleteUserAccount = onCall({ region: "africa-south1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to delete account.");
  }

  const uid = request.auth.uid;
  const normalizedEmail = request.auth.token.email ? request.auth.token.email.toLowerCase() : "";

  try {
    // 1. Delete Firestore records
    await db.collection("users").doc(uid).delete();
    if (normalizedEmail) {
      await db.collection("otps").doc(normalizedEmail).delete();
    }

    // 2. Delete Auth record
    await admin.auth().deleteUser(uid);
    
    console.log(`Successfully rolled back registration for user: ${uid}`);
    return { success: true };
  } catch (error) {
    console.error("Error deleting user account:", error);
    throw new HttpsError("internal", "Failed to delete user account.");
  }
});

// 6. Google Maps Proxy Function
exports.googleMapsProxy = onCall(
  { 
    region: "africa-south1",
    enforceAppCheck: false, // Set to false for monitoring/debugging; still secured by Auth below
    secrets: [GOOGLE_MAPS_API_KEY]
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const { endpoint, params } = request.data;
    if (!endpoint || !params) {
      throw new HttpsError("invalid-argument", "Endpoint and params are required.");
    }

    const apiKey = GOOGLE_MAPS_API_KEY.value();

    if (endpoint === "staticmap") {
      const scale = params.scale || 2;
      const zoom = params.zoom || 15;
      const size = params.size || '600x300';
      const maptype = params.maptype || 'roadmap';
      const color = params.color || 'AD83FE';
      const center = params.center;

      if (!center) {
        throw new HttpsError("invalid-argument", "Center parameter is required for staticmap.");
      }

      const staticMapUrl = `https://maps.googleapis.com/maps/api/staticmap?center=${encodeURIComponent(center)}&zoom=${zoom}&size=${size}&scale=${scale}&maptype=${maptype}&markers=color:0x${color}%7C${encodeURIComponent(center)}&key=${apiKey}`;

      try {
        const response = await fetch(staticMapUrl);
        if (!response.ok) {
          throw new Error(`Google Maps Static API responded with status ${response.status}`);
        }
        const buffer = await response.arrayBuffer();
        const base64 = Buffer.from(buffer).toString('base64');
        return { status: 'OK', image: base64 };
      } catch (error) {
        console.error("Google Maps Static Map Proxy Error:", error);
        throw new HttpsError("internal", `Failed to fetch static map: ${error.message}`);
      }
    }

    let url = "";

    switch (endpoint) {
      case "autocomplete":
        url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(params.input)}&key=${apiKey}`;
        break;
      case "details":
        url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${params.place_id}&fields=name,formatted_address,geometry&key=${apiKey}`;
        break;
      case "geocode":
        url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${params.latlng}&key=${apiKey}`;
        break;
      default:
        throw new HttpsError("invalid-argument", "Invalid endpoint.");
    }

    try {
      const response = await fetch(url);
      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Google Maps API Proxy Error:", error);
      throw new HttpsError("internal", "Failed to fetch data from Google Maps API.");
    }
  }
);

// 8. Sync User Schedule Trigger
// Watches for RSVP changes and populates the user's personal schedule
exports.syncUserSchedule = onDocumentWritten(
  {
    document: "events/{eventId}/guests/{userId}",
    region: "africa-south1",
  },
  async (event) => {
    const eventId = event.params.eventId;
    const userId = event.params.userId;
    const afterSnap = event.data.after;
    const beforeSnap = event.data.before;
    
    const data = afterSnap.exists ? afterSnap.data() : null;
    const previousData = beforeSnap.exists ? beforeSnap.data() : null;

    const scheduleRef = db.collection("users").doc(userId).collection("schedule").doc(eventId);
    const syncStatuses = ["going", "maybe", "interested"];
    const status = data?.status;
    const prevStatus = previousData?.status;

    // Case 1: RSVP removed or status should not appear on calendar schedule
    if (!afterSnap.exists || !syncStatuses.includes(status)) {
      if (beforeSnap.exists && syncStatuses.includes(prevStatus)) {
        await scheduleRef.delete();
        console.log(`Removed event ${eventId} from user ${userId} schedule (status: ${data ? data.status : 'deleted'})`);
        if (prevStatus === "going") {
          await promoteFromWaitlist(eventId);
        }
      }
      return;
    }

    // Case 2: RSVP status is going, maybe, or interested
    // Fetch parent event details to denormalize
    const eventSnap = await db.collection("events").doc(eventId).get();
    if (!eventSnap.exists) {
      console.error(`Parent event ${eventId} not found for RSVP sync`);
      return;
    }

    const eventData = eventSnap.data();
    const hostId = eventData.metadata.hostId;

    let hostName = "Host";
    let hostImageUrl = "";

    try {
      const hostSnap = await db.collection("users").doc(hostId).get();
      if (hostSnap.exists) {
        const hostData = hostSnap.data();
        hostName = hostData.name || hostData.username || "Host";
        hostImageUrl = hostData.profile_image_url || hostData.avatar_url || "";
      }
    } catch (err) {
      console.error(`Error syncing host info for event schedule: ${err}`);
    }
    
    // Denormalize as per GitHub task requirements
    // We use both snake_case (requested) and camelCase (for model compatibility)
    await scheduleRef.set({
      event_id: eventId,
      eventId: eventId,
      title: eventData.title,
      start_time: eventData.timing.startDate,
      startTime: eventData.timing.startDate,
      end_time: eventData.timing.endDate || null,
      endTime: eventData.timing.endDate || null,
      poster_url: eventData.visuals.posterUrl || "",
      posterUrl: eventData.visuals.posterUrl || "",
      subtitle_info: eventData.location?.displayName || eventData.title,
      locationName: eventData.location?.displayName || "",
      host_id: hostId,
      hostId: hostId,
      host_name: hostName,
      hostName: hostName,
      host_image_url: hostImageUrl,
      hostImageUrl: hostImageUrl,
      aurora_colors: eventData.visuals.auroraColors || [],
      auroraColors: eventData.visuals.auroraColors || [],
      co_host_ids: eventData.co_host_ids || eventData.coHostIds || [],
      coHostIds: eventData.co_host_ids || eventData.coHostIds || [],
      rsvp_status: status,
      rsvpStatus: status,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Synced event ${eventId} to user ${userId} schedule (${status})`);
  }
);

/**
 * Automatically promotes the next person on the waitlist to 'going' status.
 */
async function promoteFromWaitlist(eventId) {
  try {
    const eventSnap = await db.collection("events").doc(eventId).get();
    if (!eventSnap.exists) return;
    const eventData = eventSnap.data();

    // Only proceed if waitlist is actually enabled for this event
    if (!eventData.audience || !eventData.audience.waitlistEnabled) {
      return;
    }

    // Find the oldest waitlisted user (First In, First Out)
    const waitlistSnap = await db.collection("events").doc(eventId)
      .collection("guests")
      .where("status", "==", "waitlisted")
      .orderBy("updatedAt", "asc")
      .limit(1)
      .get();

    if (waitlistSnap.empty) return;

    const nextGuestDoc = waitlistSnap.docs[0];
    const nextUserId = nextGuestDoc.id;

    console.log(`Promoting user ${nextUserId} from waitlist for event ${eventId}`);

    // Update guest status to 'going'
    // This will trigger syncUserSchedule for THIS user, populating their calendar
    await nextGuestDoc.ref.update({
      status: "going",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify the user via FCM if they have a token
    const userSnap = await db.collection("users").doc(nextUserId).get();
    const userData = userSnap.data();
    
    if (userData && userData.fcm_token) {
      const message = {
        notification: {
          title: "You're in!",
          body: `A spot opened up for "${eventData.title}". You've been promoted from the waitlist!`,
        },
        data: {
          eventId: eventId,
          type: "waitlist_promotion",
        },
        token: userData.fcm_token,
      };

      await admin.messaging().send(message);
      console.log(`Sent waitlist promotion notification to user ${nextUserId}`);
    }
  } catch (error) {
    console.error("Waitlist Promotion Error:", error);
  }
}

function buildSchedulePatchFromEvent(eventData, eventId, hostName, hostImageUrl, extra = {}) {
  const hostId = eventData.metadata?.hostId || "";
  const coHostIds = getCoHostIds(eventData);
  return {
    event_id: eventId,
    eventId: eventId,
    title: eventData.title,
    start_time: eventData.timing?.startDate,
    startTime: eventData.timing?.startDate,
    end_time: eventData.timing?.endDate || null,
    endTime: eventData.timing?.endDate || null,
    poster_url: eventData.visuals?.posterUrl || "",
    posterUrl: eventData.visuals?.posterUrl || "",
    subtitle_info: eventData.location?.displayName || eventData.title,
    locationName: eventData.location?.displayName || "",
    host_id: hostId,
    hostId: hostId,
    host_name: hostName,
    hostName: hostName,
    host_image_url: hostImageUrl,
    hostImageUrl: hostImageUrl,
    aurora_colors: eventData.visuals?.auroraColors || [],
    auroraColors: eventData.visuals?.auroraColors || [],
    co_host_ids: coHostIds,
    coHostIds: coHostIds,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  };
}

// 9. Update Propagation Trigger
// When event details change, update host/cohost and guest schedules
exports.onEventUpdate = onDocumentWritten(
  {
    document: "events/{eventId}",
    region: "africa-south1",
  },
  async (event) => {
    const eventId = event.params.eventId;
    const afterSnap = event.data.after;
    const beforeSnap = event.data.before;

    if (!afterSnap.exists || !beforeSnap.exists) return;

    const after = afterSnap.data();
    const before = beforeSnap.data();

    const titleChanged = after.title !== before.title;
    const timingChanged = JSON.stringify(after.timing) !== JSON.stringify(before.timing);
    const posterChanged = after.visuals?.posterUrl !== before.visuals?.posterUrl;
    const locationChanged = after.location?.displayName !== before.location?.displayName;
    const coHostChanged =
      JSON.stringify(getCoHostIds(before).sort()) !== JSON.stringify(getCoHostIds(after).sort());

    if (!titleChanged && !timingChanged && !posterChanged && !locationChanged && !coHostChanged) {
      return;
    }

    console.log(`Event ${eventId} changed. Propagating schedule updates...`);

    const hostId = after.metadata?.hostId || "";
    let hostName = "Host";
    let hostImageUrl = "";
    try {
      const hostSnap = await db.collection("users").doc(hostId).get();
      if (hostSnap.exists) {
        const hostData = hostSnap.data();
        hostName = hostData.name || hostData.username || "Host";
        hostImageUrl = hostData.profile_image_url || hostData.avatar_url || "";
      }
    } catch (err) {
      console.error(`Error loading host profile for schedule propagation: ${err}`);
    }

    const schedulePatch = buildSchedulePatchFromEvent(after, eventId, hostName, hostImageUrl);
    const batch = db.batch();
    let opCount = 0;

    const afterCoHosts = getCoHostIds(after);
    const hostAndCoHostIds = new Set([hostId, ...afterCoHosts].filter((id) => id));

    for (const uid of hostAndCoHostIds) {
      const scheduleRef = db.collection("users").doc(uid).collection("schedule").doc(eventId);
      batch.set(scheduleRef, schedulePatch, { merge: true });
      opCount++;
    }

    const beforeCoHosts = new Set(getCoHostIds(before));
    for (const uid of beforeCoHosts) {
      if (!afterCoHosts.includes(uid) && uid !== hostId) {
        batch.delete(db.collection("users").doc(uid).collection("schedule").doc(eventId));
        opCount++;
      }
    }

    const guestsSnap = await db.collection("events").doc(eventId).collection("guests").get();
    const syncStatuses = ["going", "maybe", "interested"];

    guestsSnap.docs.forEach((guestDoc) => {
      const status = guestDoc.data()?.status;
      if (!syncStatuses.includes(status)) return;
      const scheduleRef = db.collection("users").doc(guestDoc.id).collection("schedule").doc(eventId);
      batch.set(
        scheduleRef,
        buildSchedulePatchFromEvent(after, eventId, hostName, hostImageUrl, {
          rsvp_status: status,
          rsvpStatus: status,
        }),
        { merge: true }
      );
      opCount++;
    });

    if (opCount > 0) {
      await batch.commit();
    }

    console.log(`Propagated schedule updates for event ${eventId} (${opCount} writes)`);
  }
);

// 10. Daily Cleanup Trigger (TTL)
// Automatically archives events older than 30 days to keep schedules snappy
exports.cleanupPastEvents = onSchedule(
  {
    schedule: "every 24 hours",
    region: "europe-west1", // africa-south1 does not support Cloud Scheduler yet
  },
  async (event) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const cutoff = admin.firestore.Timestamp.fromDate(thirtyDaysAgo);

    console.log("Running daily schedule cleanup...");

    // Query across all users for schedule items that ended > 30 days ago
    const pastSchedules = await db.collectionGroup("schedule")
      .where("endTime", "<", cutoff)
      .limit(450) // Stay under batch limits
      .get();

    if (pastSchedules.empty) {
      console.log("Cleanup complete: No old events found.");
      return;
    }

    const batch = db.batch();
    let count = 0;

    for (const doc of pastSchedules.docs) {
      const scheduleData = doc.data();
      const eventId = doc.id;
      // Extract userId from path: users/{userId}/schedule/{eventId}
      const userId = doc.ref.parent.parent.id;

      const archiveRef = db.collection("users").doc(userId).collection("schedule_archive").doc(eventId);
      
      // Move to archive
      batch.set(archiveRef, {
        ...scheduleData,
        archived_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Delete from active schedule
      batch.delete(doc.ref);
      count++;
    }

    await batch.commit();
    console.log(`Cleanup complete: Archived ${count} past events.`);
  }
);

// 12. Friend Recommendations Engine
exports.getFriendRecommendations = onCall({ region: "africa-south1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to get recommendations.");
  }

  const currentUserId = request.auth.uid;
  const recommendations = [];
  const recommendedUids = new Set([currentUserId]); // Exclude self
  const limit = 10;

  try {
    // Helper to add user if not already added
    const addUser = async (uid, contextString) => {
      if (recommendedUids.has(uid) || recommendations.length >= limit) return false;

      const userSnap = await db.collection("users").doc(uid).get();
      if (!userSnap.exists) return false;

      const data = userSnap.data();
      recommendations.push({
        uid: uid,
        username: data.username || "Unknown",
        profile_image_url: data.profile_image_url || data.avatar_url || "",
        known_from: contextString,
      });
      recommendedUids.add(uid);
      return true;
    };

    // Pre-fetch current user's active connections to exclude them from discovery
    const connectionsSnap = await db.collection("users").doc(currentUserId).collection("connections").get();
    connectionsSnap.docs.forEach(doc => {
      const data = doc.data();
      // Exclude if already connected or if current user initiated the request
      if (data.status === 'connected' || data.initiated_by === currentUserId) {
        recommendedUids.add(doc.id);
      }
    });

    // --- STEP 1: Pending Requests ---
    const pendingSnap = await db.collection("users").doc(currentUserId).collection("connections")
      .where("status", "==", "pending")
      .get();

    for (const doc of pendingSnap.docs) {
      if (recommendations.length >= limit) break;
      await addUser(doc.id, "Requested to be your friend");
    }

    // --- STEP 2: Shared Past Events (3-Event Cap) ---
    if (recommendations.length < limit) {
      const now = admin.firestore.Timestamp.now();
      const scheduleSnap = await db.collection("users").doc(currentUserId).collection("schedule")
        .where("start_time", "<", now)
        .orderBy("start_time", "desc")
        .limit(3)
        .get();

      for (const eventDoc of scheduleSnap.docs) {
        if (recommendations.length >= limit) break;
        const eventId = eventDoc.id;
        const eventTitle = eventDoc.data().title || "an event";

        // Query guests for this event
        const guestsSnap = await db.collection("events").doc(eventId).collection("guests")
          .where("status", "==", "going")
          .get();

        for (const guestDoc of guestsSnap.docs) {
          if (recommendations.length >= limit) break;
          await addUser(guestDoc.id, `Was at ${eventTitle}`);
        }
      }
    }

    // --- STEP 3: Campus Fallback ---
    if (recommendations.length < limit) {
      const currentUserSnap = await db.collection("users").doc(currentUserId).get();
      if (currentUserSnap.exists) {
        const campusId = currentUserSnap.data().campus_id || currentUserSnap.data().campus; // Check both just in case
        if (campusId) {
          // Assuming campus_id or campus string maps to the context name
          const campusName = currentUserSnap.data().campus || campusId;
          const campusSnap = await db.collection("users")
            .where("campus_id", "==", campusId) // Try searching by campus_id first
            .limit(limit * 2)
            .get();

          if (!campusSnap.empty) {
            for (const userDoc of campusSnap.docs) {
              if (recommendations.length >= limit) break;
              await addUser(userDoc.id, campusName);
            }
          } else {
             // Fallback to query by 'campus'
             const campusStrSnap = await db.collection("users")
               .where("campus", "==", campusName)
               .limit(limit * 2)
               .get();
             for (const userDoc of campusStrSnap.docs) {
               if (recommendations.length >= limit) break;
               await addUser(userDoc.id, campusName);
             }
          }
        }
      }
    }

    return recommendations;
  } catch (error) {
    console.error("Error getting friend recommendations:", error);
    throw new HttpsError("internal", "Failed to get recommendations.");
  }
});

// 12. Event Deletion Cleanup Trigger
// When an event is deleted, clean up all guests' schedules, broadcasts, and other related metadata
exports.onEventDelete = onDocumentWritten(
  {
    document: "events/{eventId}",
    region: "africa-south1",
  },
  async (event) => {
    const eventId = event.params.eventId;
    const beforeSnap = event.data.before;
    const afterSnap = event.data.after;

    // We only care about deletion (document existed before, but not after)
    if (beforeSnap.exists && !afterSnap.exists) {
      console.log(`Event ${eventId} has been deleted. Starting full Firebase-side cleanup...`);

      const before = beforeSnap.data();
      
      // 1. Delete all guest schedule entries
      const guestsSnap = await db.collection("events").doc(eventId)
        .collection("guests")
        .get();

      if (!guestsSnap.empty) {
        const docs = guestsSnap.docs;
        const chunkSize = 400;
        let updatedCount = 0;

        for (let i = 0; i < docs.length; i += chunkSize) {
          const batch = db.batch();
          const chunk = docs.slice(i, i + chunkSize);

          chunk.forEach((guestDoc) => {
            const userId = guestDoc.id;
            const scheduleRef = db.collection("users").doc(userId).collection("schedule").doc(eventId);
            batch.delete(scheduleRef);
            
            // Also delete the guest document under the deleted event (although the parent is deleted, subcollections might still exist)
            batch.delete(guestDoc.ref);
            updatedCount++;
          });

          await batch.commit();
        }
        console.log(`Cleaned up ${updatedCount} guest schedules for deleted event ${eventId}`);
      }

      // 2. Delete broadcasts subcollection documents
      const broadcastsSnap = await db.collection("events").doc(eventId)
        .collection("broadcasts")
        .get();

      if (!broadcastsSnap.empty) {
        const batch = db.batch();
        broadcastsSnap.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(`Cleaned up broadcasts for deleted event ${eventId}`);
      }

      // 3. Decrement hosted count for the host (just in case the client failed to decrement)
      const hostId = before.metadata?.hostId;
      if (hostId) {
        const hostRef = db.collection("users").doc(hostId);
        try {
          await db.runTransaction(async (transaction) => {
            const hostDoc = await transaction.get(hostRef);
            if (hostDoc.exists) {
              const currentHosted = hostDoc.data().counts?.hosted || 0;
              if (currentHosted > 0) {
                transaction.update(hostRef, {
                  "counts.hosted": admin.firestore.FieldValue.increment(-1)
                });
              }
            }
          });
          console.log(`Decremented hosted event count for host ${hostId}`);
        } catch (e) {
          console.error(`Failed to adjust hosted count for user ${hostId}: ${e}`);
        }
      }

      // 4. Delete the poster image from Firebase Storage
      const posterUrl = before.visuals?.posterUrl;
      if (posterUrl) {
        try {
          const bucket = admin.storage().bucket();
          const filePath = `posters/${eventId}/poster.webp`;
          const file = bucket.file(filePath);
          const [exists] = await file.exists();
          if (exists) {
            await file.delete();
            console.log(`Deleted event poster from Storage: ${filePath}`);
          }
        } catch (e) {
          console.error(`Failed to delete poster from Storage: ${e}`);
        }
      }
    }
  }
);

// 13. Secure "For You" Discovery Engine
exports.getForYouFeed = onCall(
  { region: "africa-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const currentUserId = request.auth.uid;
    
    // 1. Profile Data Loading
    const userSnap = await db.collection("users").doc(currentUserId).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }
    const userData = userSnap.data();
    const userInterests = Array.isArray(userData.interests) ? userData.interests : [];
    const userGender = userData.gender || null;

    // Load user's active connections (friends)
    const currentUserFriends = new Set();
    const connectionsSnap = await db.collection("users").doc(currentUserId).collection("connections").where("status", "==", "connected").get();
    connectionsSnap.docs.forEach(doc => currentUserFriends.add(doc.id));

    // Load user's active invites
    const currentUserInvites = new Set();
    const invitesSnap = await db.collection("users").doc(currentUserId).collection("invites").get();
    invitesSnap.docs.forEach(doc => currentUserInvites.add(doc.id));

    // 2. Fetch Active Events (with 300 records scaling cap)
    const activeEventsSnap = await db.collection("events")
      .where("metadata.status", "==", "active")
      .limit(300)
      .get();
    
    const now = new Date();
    // Cache for host friends to avoid duplicate queries
    const hostFriendsCache = new Map();
    // Cache for host documents
    const hostDataCache = new Map();

    const candidateEvents = [];

    // 3. Hard Filtering
    for (const eventDoc of activeEventsSnap.docs) {
      const eventData = eventDoc.data();
      const eventId = eventDoc.id;

      // --- Time-Expiry Check ---
      const startDate = eventData.timing?.startDate ? (typeof eventData.timing.startDate.toDate === 'function' ? eventData.timing.startDate.toDate() : new Date(eventData.timing.startDate)) : null;
      const endDate = eventData.timing?.endDate ? (typeof eventData.timing.endDate.toDate === 'function' ? eventData.timing.endDate.toDate() : new Date(eventData.timing.endDate)) : null;
      
      // Fallback: If endDate is not specified, default to 24 hours after startDate.
      const effectiveEndDate = endDate || (startDate ? new Date(startDate.getTime() + 24 * 60 * 60 * 1000) : null);
      if (effectiveEndDate && effectiveEndDate < now) {
        continue; // Skip past/ended events
      }

      // --- Privacy & Social Visibility (shared with getDiscoverFeed) ---
      const hostId = eventData.metadata?.hostId || eventData.metadata?.host_id;

      if (!hostId) continue; // Invalid event data
      if (hostId === currentUserId) continue; // Skip events hosted by the current user

      const forYouCtx = {
        currentUserId,
        gender: userGender,
        friendsSet: currentUserFriends,
        invitesSet: currentUserInvites,
      };
      const visible = await passesVisibilityFilter(
        eventData,
        eventId,
        forYouCtx,
        hostFriendsCache
      );
      if (!visible) continue;

      // 4. Scoring
      // Match Score
      const eventTags = eventData.tags || [];
      let matchScore = 0;
      for (const interest of userInterests) {
        if (eventTags.includes(interest)) {
          matchScore++;
        }
      }

      // Popularity Score
      let popularityScore = eventData.popularity_score || eventData.popularityScore;
      if (typeof popularityScore !== 'number') {
        const goingCount = eventData.counts?.going || eventData.counts?.attendees || eventData.rsvpCounts?.going || eventData.rsvp_counts?.going || 0;
        const interestedCount = eventData.counts?.interested || eventData.rsvpCounts?.interested || eventData.rsvp_counts?.interested || 0;
        const viewCount = eventData.counts?.views || eventData.viewCount || eventData.view_count || 0;
        
        popularityScore = (goingCount * 3) + (interestedCount * 2) + viewCount;
      }

      candidateEvents.push({
        id: eventId,
        title: eventData.title || "",
        poster_url: eventData.visuals?.posterUrl || "",
        start_time: eventData.timing?.startDate ? (typeof eventData.timing.startDate.toMillis === 'function' ? eventData.timing.startDate.toMillis() : null) : null,
        location_name: eventData.location?.displayName || "",
        aurora_colors: eventData.visuals?.auroraColors || [],
        hostId: hostId, // Temporarily keep to fetch host payload fields later
        matchScore: matchScore,
        popularityScore: popularityScore
      });
    }

    // Sort and Rank
    candidateEvents.sort((a, b) => {
      if (b.matchScore !== a.matchScore) {
        return b.matchScore - a.matchScore; // Primary: matchScore desc
      }
      return b.popularityScore - a.popularityScore; // Secondary: popularityScore desc
    });

    // Performance Capping
    const topEvents = candidateEvents.slice(0, 10);

    // Payload Minimization (resolve host fields)
    const payload = [];
    for (const event of topEvents) {
      let hostName = "";
      let hostAvatar = "";

      if (event.hostId) {
        if (!hostDataCache.has(event.hostId)) {
          const hSnap = await db.collection("users").doc(event.hostId).get();
          if (hSnap.exists) {
            const hData = hSnap.data();
            hostDataCache.set(event.hostId, {
              username: hData.username || "",
              avatar: hData.profile_image_url || ""
            });
          } else {
            hostDataCache.set(event.hostId, { username: "", avatar: "" });
          }
        }
        
        const cachedHost = hostDataCache.get(event.hostId);
        hostName = cachedHost.username;
        hostAvatar = cachedHost.avatar;
      }

      payload.push({
        id: event.id,
        title: event.title,
        poster_url: event.poster_url,
        start_time: event.start_time,
        location_name: event.location_name,
        aurora_colors: event.aurora_colors,
        host_id: event.hostId,
        host_username: hostName,
        host_avatar_url: hostAvatar
      });
    }

    return payload;
  }
);

// 14. Discover feed (geospatial + visibility + social graph)
exports.getDiscoverFeed = onCall(
  { region: "africa-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const currentUserId = request.auth.uid;
    const latitude = request.data?.latitude;
    const longitude = request.data?.longitude;
    const tab = request.data?.tab ?? "All";

    if (typeof latitude !== "number" || typeof longitude !== "number") {
      throw new HttpsError("invalid-argument", "latitude and longitude are required.");
    }
    if (!DISCOVER_TABS.has(tab)) {
      throw new HttpsError("invalid-argument", "Invalid tab.");
    }

    const ctxBase = await loadUserDiscoverContext(currentUserId);
    const ctx = {
      currentUserId,
      gender: ctxBase.gender,
      friendsSet: ctxBase.friendsSet,
      invitesSet: ctxBase.invitesSet,
    };

    const activeEventsSnap = await db
      .collection("events")
      .where("metadata.status", "==", "active")
      .limit(500)
      .get();

    const now = new Date();
    const hostFriendsCache = new Map();
    const hostDataCache = new Map();
    const candidates = [];

    for (const eventDoc of activeEventsSnap.docs) {
      const eventData = eventDoc.data();

      if (!isEventUpcoming(eventData, now)) continue;

      const hostId =
        eventData.metadata?.hostId || eventData.metadata?.host_id;
      if (hostId === currentUserId) continue;

      const coHostIds = getCoHostIds(eventData);
      if (coHostIds.includes(currentUserId)) continue;

      const visible = await passesVisibilityFilter(
        eventData,
        eventDoc.id,
        ctx,
        hostFriendsCache
      );
      if (!visible) continue;

      const loc = eventData.location || {};
      const lat = loc.latitude ?? loc.lat;
      const lng = loc.longitude ?? loc.lng;
      const hasCoords =
        typeof lat === "number" && typeof lng === "number";
      const distanceKm = hasCoords
        ? haversineKm(latitude, longitude, lat, lng)
        : DISCOVER_NO_COORD_DISTANCE_KM;

      candidates.push({ eventDoc, distanceKm, eventData });
    }

    candidates.sort((a, b) => a.distanceKm - b.distanceKm);

    const hostIds = candidates.map((c) => c.eventData.metadata?.hostId).filter(Boolean);
    await resolveHostProfiles(hostIds, hostDataCache);

    let cards = candidates.map((c) =>
      formatDiscoverCard(c.eventDoc, c.distanceKm, hostDataCache)
    );

    if (tab !== "All") {
      cards = cards.filter((card) => eventMatchesTab(card._eventData, tab));
      return cards.map(stripInternalFields);
    }

    const allCards = cards;
    const weekendCards = allCards.filter(
      (card) => isWeekendEvent(card._eventData, now) && card.distance_km <= 100
    );

    const feed = allCards.map(stripInternalFields);
    const weekend_forecast = weekendCards.map(stripInternalFields);
    const community = takeTopNByDistance(
      allCards.filter((c) => eventHasTag(c._eventData, "community")),
      10
    ).map(stripInternalFields);
    const music = takeTopNByDistance(
      allCards.filter((c) => eventHasTag(c._eventData, "music")),
      10
    ).map(stripInternalFields);
    const arts = takeTopNByDistance(
      allCards.filter((c) => eventHasTag(c._eventData, "arts")),
      10
    ).map(stripInternalFields);
    const fitness = takeTopNByDistance(
      allCards.filter((c) => eventHasTag(c._eventData, "fitness")),
      10
    ).map(stripInternalFields);
    const food = takeTopNByDistance(
      allCards.filter((c) => eventHasTag(c._eventData, "food")),
      10
    ).map(stripInternalFields);
    const film = takeTopNByDistance(
      allCards.filter((c) => eventHasTag(c._eventData, "film")),
      10
    ).map(stripInternalFields);
    const education = takeTopNByDistance(
      allCards.filter((c) => EDUCATION_TAGS.some(tag => eventHasTag(c._eventData, tag))),
      10
    ).map(stripInternalFields);

    return {
      weekend_forecast,
      community,
      music,
      arts,
      fitness,
      food,
      film,
      education,
      feed,
    };
  }
);

// 15. Events in user's area (geohash query + visibility)
const EVENTS_IN_AREA_RADIUS_KM = 40;
const EVENTS_IN_AREA_MAX_RESULTS = 50;

exports.getEventsInArea = onCall(
  { region: "africa-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to get events in area.");
    }

    const currentUserId = request.auth.uid;

    try {
      const userSnap = await db.collection("users").doc(currentUserId).get();
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile not found.");
      }

      const reqLat = request.data?.latitude;
      const reqLng = request.data?.longitude;
      let lat;
      let lng;

      if (typeof reqLat === "number" && typeof reqLng === "number") {
        lat = reqLat;
        lng = reqLng;
      } else {
        const coords = readLatLngFromLocation(userSnap.data().location);
        if (!coords) {
          return [];
        }
        lat = coords.lat;
        lng = coords.lng;
      }

      const ctxBase = await loadUserDiscoverContext(currentUserId);
      const ctx = {
        currentUserId,
        gender: ctxBase.gender,
        friendsSet: ctxBase.friendsSet,
        invitesSet: ctxBase.invitesSet,
      };

      const activeEventsSnap = await db
        .collection("events")
        .where("metadata.status", "==", "active")
        .limit(500)
        .get();

      const now = new Date();
      const hostFriendsCache = new Map();
      const hostDataCache = new Map();
      const candidates = [];

      for (const eventDoc of activeEventsSnap.docs) {
        const eventData = eventDoc.data();
        if (!isEventUpcoming(eventData, now)) continue;

        const hostId =
          eventData.metadata?.hostId || eventData.metadata?.host_id;
        if (!hostId) continue;
        if (hostId === currentUserId) continue;

        const coHostIds = getCoHostIds(eventData);
        if (coHostIds.includes(currentUserId)) continue;

        const visible = await passesVisibilityFilter(
          eventData,
          eventDoc.id,
          ctx,
          hostFriendsCache
        );
        if (!visible) continue;

        const loc = eventData.location || {};
        const eventLat = loc.latitude ?? loc.lat;
        const eventLng = loc.longitude ?? loc.lng;
        if (typeof eventLat !== "number" || typeof eventLng !== "number") {
          continue;
        }

        const distanceInKm = haversineKm(lat, lng, eventLat, eventLng);
        if (distanceInKm > EVENTS_IN_AREA_RADIUS_KM) continue;

        const startDate = parseFirestoreDate(eventData.timing?.startDate);

        candidates.push({
          id: eventDoc.id,
          title: eventData.title || "",
          poster_url:
            eventData.visuals?.posterUrl ||
            eventData.visuals?.poster_url ||
            "",
          start_time: startDate ? startDate.getTime() : null,
          location_name:
            eventData.location?.displayName ||
            eventData.location?.display_name ||
            eventData.location?.formattedAddress ||
            eventData.location?.formatted_address ||
            "",
          aurora_colors:
            eventData.visuals?.auroraColors ||
            eventData.visuals?.aurora_colors ||
            [],
          hostId,
          distance_km: Math.round(distanceInKm * 10) / 10,
        });
      }

      candidates.sort((a, b) => (a.start_time || 0) - (b.start_time || 0));
      const topCandidates = candidates.slice(0, EVENTS_IN_AREA_MAX_RESULTS);

      const hostIds = topCandidates.map((e) => e.hostId).filter(Boolean);
      await resolveHostProfiles(hostIds, hostDataCache);

      return topCandidates.map((event) => {
        const cached = hostDataCache.get(event.hostId) || {
          username: "",
          avatar: "",
        };
        return {
          id: event.id,
          title: event.title,
          poster_url: event.poster_url,
          start_time: event.start_time,
          location_name: event.location_name,
          aurora_colors: event.aurora_colors,
          distance_km: event.distance_km,
          host_id: event.hostId,
          host_username: cached.username,
          host_avatar_url: cached.avatar,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Get Events In Area Error:", error);
      throw new HttpsError("internal", "Failed to get events in area.");
    }
  }
);

// CometChat credentials: Google Cloud Secret Manager (firebase functions:secrets:set).
exports.getCometChatClientConfig = onCall(
  {
    region: "africa-south1",
    secrets: COMETCHAT_SECRETS,
  },
  async () => {
    const appId = COMETCHAT_APP_ID.value();
    const region = COMETCHAT_REGION.value();
    if (!appId || !appId.trim() || appId === "YOUR_APP_ID") {
      throw new HttpsError(
        "failed-precondition",
        "CometChat App ID is not configured. Set COMETCHAT_APP_ID in Secret Manager and redeploy."
      );
    }
    if (!region || !region.trim()) {
      throw new HttpsError(
        "failed-precondition",
        "CometChat region is not configured. Set COMETCHAT_REGION in Secret Manager and redeploy."
      );
    }
    return { appId: appId.trim(), region: region.trim() };
  }
);

exports.cometChatCreateUser = onCall(
  {
    region: "africa-south1",
    secrets: COMETCHAT_SECRETS,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const name = request.data?.name;
    if (!name || typeof name !== "string" || !name.trim()) {
      throw new HttpsError("invalid-argument", "name is required.");
    }

    const uid = request.auth.uid;
    const appId = COMETCHAT_APP_ID.value();
    const region = COMETCHAT_REGION.value();
    const authKey = COMETCHAT_AUTH_KEY.value();

    await cometChatCreateUserRest(uid, name.trim(), authKey, appId, region);
    const authToken = await cometChatCreateAuthTokenRest(
      uid,
      authKey,
      appId,
      region
    );

    return { authToken };
  }
);

exports.cometChatGetAuthToken = onCall(
  {
    region: "africa-south1",
    secrets: COMETCHAT_SECRETS,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const uid = request.auth.uid;
    const appId = COMETCHAT_APP_ID.value();
    const region = COMETCHAT_REGION.value();
    const authKey = COMETCHAT_AUTH_KEY.value();

    let authToken;
    try {
      authToken = await cometChatCreateAuthTokenRest(
        uid,
        authKey,
        appId,
        region
      );
    } catch {
      // Accounts created before CometChat may not exist in CometChat yet.
      const userSnap = await db.collection("users").doc(uid).get();
      const profile = userSnap.data() || {};
      const name =
        (typeof profile.name === "string" && profile.name.trim()) ||
        (typeof profile.username === "string" && profile.username.trim()) ||
        "Bloom User";
      await cometChatCreateUserRest(uid, name, authKey, appId, region);
      authToken = await cometChatCreateAuthTokenRest(
        uid,
        authKey,
        appId,
        region
      );
      logger.info(`CometChat user provisioned on login for ${uid}`);
    }

    return { authToken };
  }
);

// 8. Event Rich Preview (Open Graph)
exports.generateEventPreview = onRequest(
  { region: "africa-south1" },
  async (req, res) => {
    // Attempt to parse eventId from query (?eventId=...) or path segment
    let eventId = req.query.eventId;
    if (!eventId) {
      const parts = req.path.split('/').filter(Boolean);
      eventId = parts[parts.length - 1];
    }
    
    if (!eventId || eventId === 'event') {
      return res.status(400).send("Missing Event ID");
    }

    try {
      const eventSnap = await db.collection("events").doc(eventId).get();
      if (!eventSnap.exists) {
        return res.status(404).send("Event not found");
      }

      const eventData = eventSnap.data();
      const title = eventData.title || "Bloom Event";
      const posterUrl = eventData.visuals?.posterUrl || eventData.visuals?.poster_url || "https://bloomapp.software/default_poster.png";
      const startDate = parseFirestoreDate(eventData.timing?.startDate);
      
      let dateStr = "";
      if (startDate) {
        // e.g., "Mon, 25 May 20:00"
        dateStr = startDate.toLocaleString('en-US', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute:'2-digit' });
      }
      
      const location = eventData.location?.displayName || eventData.location?.display_name || "";
      
      let description = "";
      if (dateStr && location) {
        description = `${dateStr} • ${location}`;
      } else {
        description = dateStr || location || "Join us on Bloom!";
      }

      const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>${title}</title>
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    <meta property="og:image" content="${posterUrl}" />
    <meta property="al:android:package" content="com.yourcompany.bloom" />
    <meta property="al:ios:url" content="bloom://event/${eventId}" />
    <meta property="al:android:url" content="bloom://event/${eventId}" />
    <script>
      window.onload = function() {
        var timer = setTimeout(function() {
          window.location = "https://play.google.com/store/apps/details?id=com.yourcompany.bloom";
        }, 2500);
        window.location = "bloom://event/${eventId}";
      };
    </script>
  </head>
  <body>
    <p>Redirecting to Bloom...</p>
  </body>
</html>`;
      
      res.set('Cache-Control', 'public, max-age=300, s-maxage=600');
      res.status(200).send(html);
    } catch (error) {
      logger.error("Error generating event preview", error);
      res.status(500).send("Internal error");
    }
  }
);

// 9. Automated RSVP & Waitlist Manager
exports.onGuestRSVPUpdate = onDocumentWritten(
  {
    document: "events/{eventId}/guests/{guestId}",
    region: "africa-south1",
  },
  async (event) => {
    const eventId = event.params.eventId;
    const guestId = event.params.guestId;
    
    const beforeData = event.data.before.exists ? event.data.before.data() : null;
    const afterData = event.data.after.exists ? event.data.after.data() : null;

    const beforeStatus = beforeData ? beforeData.status : null;
    const afterStatus = afterData ? afterData.status : null;
    const beforePlusOnes = beforeData && beforeData.plusOnesCount ? parseInt(beforeData.plusOnesCount) : 0;
    const afterPlusOnes = afterData && afterData.plusOnesCount ? parseInt(afterData.plusOnesCount) : 0;

    // If status and plus ones didn't change, no capacity updates needed
    if (beforeStatus === afterStatus && beforePlusOnes === afterPlusOnes) return null;

    const eventRef = db.collection("events").doc(eventId);

    return db.runTransaction(async (transaction) => {
      const eventDoc = await transaction.get(eventRef);
      if (!eventDoc.exists) return null;

      const eventData = eventDoc.data();
      const liveCounts = eventData.live_counts || eventData.liveCounts || { going: 0, maybe: 0, interested: 0 };
      const audience = eventData.audience || eventData.settings || {};
      const waitlistEnabled = audience.waitlistEnabled || audience.waitlist_enabled || false;
      const capacity = audience.capacity ? parseInt(audience.capacity) : null;

      let newGoing = parseInt(liveCounts.going || 0);
      let newMaybe = parseInt(liveCounts.maybe || 0);
      let newInterested = parseInt(liveCounts.interested || 0);

      // 1. Decrement old counts
      if (beforeStatus === "going") {
        newGoing -= (1 + beforePlusOnes);
      } else if (beforeStatus === "maybe") {
        newMaybe -= 1;
      } else if (beforeStatus === "interested") {
        newInterested -= 1;
      }

      // 2. Increment new counts
      let revertToWaitlist = false;
      if (afterStatus === "going") {
        newGoing += (1 + afterPlusOnes);
        
        // Anti-race condition: if this RSVP put us over capacity, revert it
        if (capacity !== null && waitlistEnabled && newGoing > capacity) {
           revertToWaitlist = true;
           newGoing -= (1 + afterPlusOnes);
        }
      } else if (afterStatus === "maybe") {
        newMaybe += 1;
      } else if (afterStatus === "interested") {
        newInterested += 1;
      }

      // 3. Waitlist Promotion (if we dropped below capacity)
      let waitlistPromotedGuestRefs = [];
      if (waitlistEnabled && capacity !== null && newGoing < capacity) {
        const waitlistQuery = db.collection("events").doc(eventId).collection("guests")
          .where("status", "==", "waitlisted")
          .orderBy("updatedAt", "asc")
          .limit(5); // Check first 5 to see who fits
        
        const waitlistSnap = await transaction.get(waitlistQuery);
        for (const doc of waitlistSnap.docs) {
           if (doc.id === guestId) continue; // Skip current user
           const promotedPlusOnes = doc.data().plusOnesCount ? parseInt(doc.data().plusOnesCount) : 0;
           if (newGoing + 1 + promotedPlusOnes <= capacity) {
               waitlistPromotedGuestRefs.push(doc.ref);
               newGoing += (1 + promotedPlusOnes);
           }
        }
      }

      // Ensure counts don't drop below 0
      newGoing = Math.max(0, newGoing);
      newMaybe = Math.max(0, newMaybe);
      newInterested = Math.max(0, newInterested);

      // 4. Perform Updates
      transaction.update(eventRef, {
        "live_counts.going": newGoing,
        "live_counts.maybe": newMaybe,
        "live_counts.interested": newInterested,
        "liveCounts.going": newGoing,
        "liveCounts.maybe": newMaybe,
        "liveCounts.interested": newInterested,
      });

      if (revertToWaitlist && event.data.after.exists) {
        transaction.update(event.data.after.ref, {
          status: "waitlisted",
          updatedAt: FieldValue.serverTimestamp()
        });
      }

      for (const ref of waitlistPromotedGuestRefs) {
        transaction.update(ref, {
          status: "going",
          updatedAt: FieldValue.serverTimestamp()
        });
      }
    });
  }
);

// 16. Friends & Mutuals Discovery Engine
exports.getFriendsAndMutualsFeed = onCall(
  { region: "africa-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to get friends and mutuals feed.");
    }

    const currentUserId = request.auth.uid;
    const reqLat = request.data?.latitude;
    const reqLng = request.data?.longitude;

    try {
      const userSnap = await db.collection("users").doc(currentUserId).get();
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile not found.");
      }

      let lat;
      let lng;
      if (typeof reqLat === "number" && typeof reqLng === "number") {
        lat = reqLat;
        lng = reqLng;
      } else {
        const coords = readLatLngFromLocation(userSnap.data().location);
        if (coords) {
          lat = coords.lat;
          lng = coords.lng;
        }
      }

      const friendsAndMutualsUids = new Set();
      
      // 1. Fetch direct friends
      const connectionsSnap = await db
        .collection("users")
        .doc(currentUserId)
        .collection("connections")
        .where("status", "==", "connected")
        .get();

      const directFriendIds = connectionsSnap.docs.map(doc => doc.id);
      for (const fid of directFriendIds) {
        friendsAndMutualsUids.add(fid);
      }

      // 2. Fetch mutuals (friends of friends), limit to prevent excessive reads
      const maxDirectFriendsToTraverse = 30; // To keep execution time reasonable
      const friendsToTraverse = directFriendIds.slice(0, maxDirectFriendsToTraverse);
      
      // We can parallelize some of this safely
      const mutualPromises = friendsToTraverse.map(fid => 
        db.collection("users").doc(fid).collection("connections").where("status", "==", "connected").get()
          .then(snap => snap.docs.map(doc => doc.id))
          .catch(e => { console.error(`Error fetching connections for ${fid}:`, e); return []; })
      );
      
      const mutualResults = await Promise.all(mutualPromises);
      for (const mutualIds of mutualResults) {
        for (const mid of mutualIds) {
           if (mid !== currentUserId) {
             friendsAndMutualsUids.add(mid);
           }
        }
      }

      if (friendsAndMutualsUids.size === 0) {
        return []; // No friends or mutuals found
      }

      // 3. Load Discover Context
      const ctxBase = await loadUserDiscoverContext(currentUserId);
      const ctx = {
        currentUserId,
        gender: ctxBase.gender,
        friendsSet: ctxBase.friendsSet,
        invitesSet: ctxBase.invitesSet,
      };

      // 4. Fetch Active Events
      const activeEventsSnap = await db
        .collection("events")
        .where("metadata.status", "==", "active")
        .limit(500)
        .get();

      const now = new Date();
      const hostFriendsCache = new Map();
      const hostDataCache = new Map();
      const candidates = [];

      for (const eventDoc of activeEventsSnap.docs) {
        const eventData = eventDoc.data();
        if (!isEventUpcoming(eventData, now)) continue;

        const hostId = eventData.metadata?.hostId || eventData.metadata?.host_id;
        if (!hostId) continue;
        if (hostId === currentUserId) continue; // Exclude user's own events
        if (!friendsAndMutualsUids.has(hostId)) continue; // Must be hosted by friend or mutual

        const coHostIds = getCoHostIds(eventData);
        if (coHostIds.includes(currentUserId)) continue; // Exclude if user is co-hosting

        const visible = await passesVisibilityFilter(
          eventData,
          eventDoc.id,
          ctx,
          hostFriendsCache
        );
        if (!visible) continue;

        const loc = eventData.location || {};
        const eventLat = loc.latitude ?? loc.lat;
        const eventLng = loc.longitude ?? loc.lng;
        let distanceInKm = DISCOVER_NO_COORD_DISTANCE_KM;

        if (typeof lat === "number" && typeof lng === "number" && typeof eventLat === "number" && typeof eventLng === "number") {
          distanceInKm = haversineKm(lat, lng, eventLat, eventLng);
        }

        candidates.push({ eventDoc, distanceKm: distanceInKm, eventData });
      }

      candidates.sort((a, b) => {
        const timeA = parseFirestoreDate(a.eventData.timing?.startDate)?.getTime() || Number.MAX_SAFE_INTEGER;
        const timeB = parseFirestoreDate(b.eventData.timing?.startDate)?.getTime() || Number.MAX_SAFE_INTEGER;
        return timeA - timeB;
      });

      const topCandidates = candidates.slice(0, 10);
      const hostIds = topCandidates.map((c) => c.eventData.metadata?.hostId).filter(Boolean);
      await resolveHostProfiles(hostIds, hostDataCache);

      const cards = topCandidates.map((c) =>
        formatDiscoverCard(c.eventDoc, c.distanceKm, hostDataCache)
      );

      return cards.map(stripInternalFields);
    } catch (error) {
      console.error("Error getting friends and mutuals feed:", error);
      throw new HttpsError("internal", "Failed to get friends and mutuals feed.");
    }
  }
);