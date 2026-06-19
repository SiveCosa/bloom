# Bloom

A cross-platform mobile application built with Flutter for Android and iOS. 

## About Bloom

Bloom is a comprehensive social discovery and event management platform designed to help users connect with their local communities. Key features of the platform include:
- **Event Discovery**: Browse a personalized "For You" feed and explore events in your area using location-based services.
- **Event Management & RSVPs**: Seamlessly create events, manage guest lists, join waitlists, and handle event invitations.
- **Social Connectivity**: Build a network by adding friends, discovering peers with similar interests or educational backgrounds, and engaging in real-time messaging.
- **Real-Time Updates**: Stay informed with real-time notifications for event updates, friend requests, and new messages.

This repository contains the source code for the mobile application. The app leverages Firebase for its robust backend infrastructure, including Authentication, Firestore, and Cloud Storage.

## Getting Started

To build and run this application locally on your machine for evaluation, please follow the steps below.

### Prerequisites

Ensure you have the following installed on your local development environment:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version recommended)
- [Android Studio](https://developer.android.com/studio) (for Android development/emulation)
- [Xcode](https://developer.apple.com/xcode/) (for iOS development/simulation - Mac only)
- [Git](https://git-scm.com/)

### 1. Clone the Repository

Clone this repository to your local machine:
```bash
git clone https://github.com/YourUsername/bloom.git
cd bloom
```

### 2. Install Dependencies

Fetch all the required Flutter packages:
```bash
flutter pub get
```

### 3. Firebase Configuration (Important)

For security reasons, the Firebase configuration files that contain the project's API keys have been excluded from this public repository. 

To run this application, **you must add the configuration files back into the project.** You have two options:

**Option A: Request the files directly (Recommended for Employers/Reviewers)**
Please contact me directly at **gjaydyn7@gmail.com** to securely receive the following environment files:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` (if running on iOS)
- `lib/firebase_options.dart`

Once received, place them in their respective directories within the project.

**Option B: Connect your own Firebase project**
If you prefer, you can connect the app to your own Firebase instance:
1. Create a new Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
3. Run `flutterfire configure` in the root of the project and select your new Firebase project.

### 4. Run the Application

Once the dependencies are installed and the Firebase configuration is in place, you can run the app on an emulator or a connected physical device.

To run on a default connected device/emulator:
```bash
flutter run
```

To run on a specific device (e.g., iOS Simulator or Android Emulator):
```bash
# List available devices
flutter devices

# Run on a specific device by ID
flutter run -d <device_id>
```

## Project Architecture

This application follows a modern Flutter architecture emphasizing clean separation of concerns:
- **UI/View Layer**: Declarative UI built with Flutter widgets.
- **State Management**: Handling application state efficiently to ensure smooth interactions.
- **Service Layer**: Handles external API calls and Firebase backend communication.

## License
This project is proprietary and confidential. Unauthorized copying of this file, via any medium, is strictly prohibited.
