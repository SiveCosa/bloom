const { auth } = require("firebase-functions/v1");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

const GOOGLE_MAPS_API_KEY = defineSecret("GOOGLE_MAPS_API_KEY");
const WEATHER_API_KEY = defineSecret("WEATHER_API_KEY");

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

    // [TESTING MODE] 
    console.log(`[TESTING] The OTP for ${normalized} is: ${otp}`);

    return { success: true };
  }
);

// 2. Verify OTP Function (Locked to JHB)
exports.verifyOtp = onCall(
  { region: "africa-south1" },
  async (request) => {
    const email = request.data.email;
    const otp = request.data.otp;

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
    if (otpData.expiresAt.toDate() < new Date()) {
      throw new HttpsError("failed-precondition", "OTP has expired.");
    }

    // Security Layer 3: Value Check
    if (otpData.otp !== otp) {
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

    // Case 1: RSVP is removed or status is no longer "going"
    if (!afterSnap.exists || data.status !== "going") {
      // Only delete if it was previously "going" or if it exists in schedule
      if (beforeSnap.exists && previousData.status === "going") {
        await scheduleRef.delete();
        console.log(`Removed event ${eventId} from user ${userId} schedule (status: ${data ? data.status : 'deleted'})`);
        
        // AUTOMATION: Try to promote someone from the waitlist
        await promoteFromWaitlist(eventId);
      }
      return;
    }

    // Case 2: RSVP status is "going" (New or Update)
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
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Synced event ${eventId} to user ${userId} schedule`);
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

// 9. Update Propagation Trigger
// When event details change, update all guest schedules to ensure consistency
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

    // Check if core details changed to avoid unnecessary writes
    const titleChanged = after.title !== before.title;
    const timingChanged = JSON.stringify(after.timing) !== JSON.stringify(before.timing);
    const posterChanged = after.visuals?.posterUrl !== before.visuals?.posterUrl;
    const locationChanged = after.location?.displayName !== before.location?.displayName;

    if (!titleChanged && !timingChanged && !posterChanged && !locationChanged) {
      return;
    }

    console.log(`Event ${eventId} core details changed. Propagating updates...`);

    // Find all guests who are "going"
    const guestsSnap = await db.collection("events").doc(eventId)
      .collection("guests")
      .where("status", "==", "going")
      .get();

    if (guestsSnap.empty) return;

    // Use chunked batching for efficiency and to respect Firestore's 500-op limit
    const docs = guestsSnap.docs;
    const chunkSize = 400; // Safe margin below 500
    let updatedCount = 0;

    for (let i = 0; i < docs.length; i += chunkSize) {
      const batch = db.batch();
      const chunk = docs.slice(i, i + chunkSize);

      chunk.forEach((guestDoc) => {
        const userId = guestDoc.id;
        const scheduleRef = db.collection("users").doc(userId).collection("schedule").doc(eventId);
        
        batch.set(scheduleRef, {
          title: after.title,
          start_time: after.timing.startDate,
          startTime: after.timing.startDate,
          end_time: after.timing.endDate || null,
          endTime: after.timing.endDate || null,
          poster_url: after.visuals?.posterUrl || "",
          posterUrl: after.visuals?.posterUrl || "",
          subtitle_info: after.location?.displayName || after.title,
          locationName: after.location?.displayName || "",
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        
        updatedCount++;
      });

      await batch.commit();
    }

    console.log(`Successfully propagated updates to ${updatedCount} guest schedules for event ${eventId}`);
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

    // --- STEP 4: Testing Fallback ---
    // For testing purposes: display all new users up to 10 if we still haven't hit the limit
    if (recommendations.length < limit) {
      const anyUsersSnap = await db.collection("users")
        .orderBy("created_at", "desc")
        .limit(limit * 3)
        .get();
        
      for (const userDoc of anyUsersSnap.docs) {
        if (recommendations.length >= limit) break;
        await addUser(userDoc.id, "New on Bloom (Testing)");
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

      // --- Privacy & Social Visibility ---
      const visibility = eventData.audience?.visibility || "public";
      const hostId = eventData.metadata?.hostId;

      if (!hostId) continue; // Invalid event data
      if (hostId === currentUserId) continue; // Skip events hosted by the current user

      if (visibility === "private") {
        const invitedUserIds = eventData.invitedUserIds || eventData.invited_user_ids || eventData.invitations || eventData.audience?.invitedUserIds || eventData.audience?.invited_user_ids || [];
        const explicitlyInvited = invitedUserIds.includes(currentUserId);
        
        if (!currentUserInvites.has(eventId) && !explicitlyInvited) {
          continue; // Failed private checkpoint
        }
      } else if (visibility === "friendsOnly" || visibility === "friends_only") {
        if (!currentUserFriends.has(hostId)) {
          continue; // Failed friendsOnly checkpoint
        }
      } else if (visibility === "friendsOfFriends" || visibility === "friends_of_friends") {
        if (!currentUserFriends.has(hostId)) {
          // Check if there is a mutual friend
          let hostFriends = hostFriendsCache.get(hostId);
          if (!hostFriends) {
            hostFriends = new Set();
            const hFriendsSnap = await db.collection("users").doc(hostId).collection("connections").where("status", "==", "connected").get();
            hFriendsSnap.docs.forEach(doc => hostFriends.add(doc.id));
            hostFriendsCache.set(hostId, hostFriends);
          }

          let hasMutual = false;
          for (const friendUid of currentUserFriends) {
            if (hostFriends.has(friendUid)) {
              hasMutual = true;
              break;
            }
          }

          if (!hasMutual) {
            continue; // Failed friendsOfFriends checkpoint
          }
        }
      } else if (visibility === "maleOnly" || visibility === "male_only") {
        if (userGender !== "male") {
          continue; // Failed maleOnly checkpoint
        }
      } else if (visibility === "femaleOnly" || visibility === "female_only") {
        if (userGender !== "female") {
          continue; // Failed femaleOnly checkpoint
        }
      }

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