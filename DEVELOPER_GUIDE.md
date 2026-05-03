# Bloom Project Overview & Developer Guide

This document provides a high-level overview of the Bloom architecture, distinguishing between Frontend and Backend responsibilities, and summarizing the essential files to help the team get up to speed.

---

## Architecture Overview

The Bloom project is split into two primary areas:

### 1. Frontend (Flutter)
**Location:** `/lib`
The frontend team is responsible for everything related to the user interface, client-side state management, and navigation. 

**Duties:**
- Building responsive UI components using Flutter.
- Managing application state (using Riverpod).
- Handling client-side routing and navigation.
- Implementing local data persistence and caching.
- Validating user input before sending it to the backend.

### 2. Backend (Firebase)
**Location:** `/functions`, `/firestore.rules`, `/storage.rules`
The backend team handles server-side logic, database security, and cloud integrations.

**Duties:**
- Writing and deploying Cloud Functions for sensitive operations (e.g., OTP, Auth).
- Defining Firestore Security Rules to protect user data.
- Managing storage permissions and file structures.
- Handling automated triggers (e.g., initializing a profile when a user signs up).

---

## Essential File Summaries

### Frontend (`/lib`)

| File / Directory | Function & Operation | Primary Duty |
| :--- | :--- | :--- |
| `main.dart` | The entry point of the Flutter application. | Initializes Firebase, sets up global providers (Riverpod), and configures the `MaterialApp` with routing and themes. |
| `data/firebase_provider.dart` | A singleton helper for Firebase initialization. | Handles `Firebase.initializeApp()` and activates **Firebase App Check** for security enforcement. |
| `core/routing/` | Contains the `GoRouter` configuration. | Manages the navigation stack, deep linking, and route guards. |
| `core/theme/` | The styling engine of the app. | Defines light/dark themes, color palettes, and typography to ensure UI consistency. |
| `ui/` | Feature-based UI directories (auth, profile, home, etc.). | Contains all screens and widgets. This is where most frontend visual work happens. |
| `domain/` | Data models and business logic entities. | Defines the structure of data (e.g., User, Event) used across the app. |

### Backend (`/functions`, `/`)

| File / Directory | Function & Operation | Primary Duty |
| :--- | :--- | :--- |
| `functions/index.js` | The main entry point for Firebase Cloud Functions. | Contains critical business logic: OTP generation/verification, student email validation, and username uniqueness checks. |
| `firestore.rules` | The security gatekeeper for the database. | Defines who can read/write specific documents. It ensures users can only modify their own data and enforces schema constraints. |
| `storage.rules` | Security rules for Firebase Storage. | Controls access to uploaded files like profile avatars and event images. |
| `firebase.json` | Firebase CLI configuration. | Defines hosting settings, function triggers, and which local files map to which Firebase services. |

---

## Workflow Summary

- **Adding a new UI Screen:** Create a new directory in `lib/ui/`, define your screen and widgets, and register the new route in `lib/core/routing/`.
- **Changing Data Security:** Modify `firestore.rules` and run `firebase deploy --only firestore:rules`.
- **Adding a secure API:** Add a new `onCall` function in `functions/index.js` and deploy using `firebase deploy --only functions`.
- **Global Styling:** Always use the tokens defined in `lib/core/theme/` rather than hardcoding colors.

---

*Last Updated: May 2026*
