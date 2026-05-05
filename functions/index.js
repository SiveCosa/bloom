const { auth } = require("firebase-functions/v1");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

const GOOGLE_MAPS_API_KEY = defineSecret("GOOGLE_MAPS_API_KEY");

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