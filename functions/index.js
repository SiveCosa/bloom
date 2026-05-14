const { auth } = require("firebase-functions/v1");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

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
      host_id: eventData.metadata.hostId,
      hostId: eventData.metadata.hostId,
      host_name: "Host", // Placeholder
      hostName: "Host",
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
    region: "europe-west1", // Changed from africa-south1 due to regional Scheduler availability
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