# Bloom

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)

## About Bloom

Bloom is a comprehensive social discovery and event management platform designed to help users connect with their local communities. Key features of the platform include:
- **Event Discovery**: Browse a personalized "For You" feed and explore events in your area using location-based services.
- **Event Management & RSVPs**: Seamlessly create events, manage guest lists, join waitlists, and handle event invitations.
- **Social Connectivity**: Build a network by adding friends, discovering peers with similar interests or educational backgrounds, and engaging in real-time messaging.
- **Real-Time Updates**: Stay informed with real-time notifications for event updates, friend requests, and new messages.

This repository contains the source code for the mobile application. The app leverages Firebase for its robust backend infrastructure, including Authentication, Firestore, and Cloud Storage.


## Project Context

Bloom was developed as a **group university software engineering project**. This fork is maintained as part of my personal developer portfolio and preserves the original team project while highlighting the areas I personally contributed to.

I did **not** build every feature in Bloom. The application was developed collaboratively by the project team.

## My Contributions

My documented contributions to Bloom include:

### Secure “For You” Discovery Engine
I implemented the Firebase Cloud Function used to generate Bloom’s personalized **For You** event feed.

The function:
- runs in the `africa-south1` region
- requires authenticated users
- reads user interests and gender
- queries active events
- applies gender restrictions
- enforces public, private, friends-only, and friends-of-friends visibility rules
- validates direct invitations
- calculates interest-match and popularity scores
- returns a lightweight event payload for the Flutter feed UI

This contribution was merged through **PR #29 — “Implement secure For You discovery engine.”**

### Calendar Filter & Search System
I also implemented a calendar filtering and local search workflow, including:
- multi-select calendar filter categories
- a dedicated filter bottom sheet
- local event search by title and host
- a `/calendar/search` route
- filtered schedule providers
- support for requested and waitlisted RSVP states in calendar scheduling

This work is documented in **PR #39 — “Implement calendar filter and search system.”**

### Event Card Interaction Refinements
I contributed additional frontend/backend refinements to the event-card experience, including:
- extracting reusable Interested-button logic
- wiring medium event cards into RSVP and optimistic-update behavior
- removing hardcoded placeholder avatars
- adding event-description support to feed mappings
- extending Cloud Function payloads to include descriptions

These contributions demonstrate work across **Flutter UI, Riverpod state management, Firebase Cloud Functions, Firestore-backed event data, and application navigation**.

## Home Page
<img width="300" alt="bloom_home_screen_1" src="https://github.com/user-attachments/assets/81de57ca-39a3-4a6a-b447-f2f077567762" />
<img width="300" alt="bloom_home_screen_2" src="https://github.com/user-attachments/assets/379658a6-d3cb-48ad-b5b1-2282e0b10bd7" />
<img width="300" alt="bloom_home_screen_3" src="https://github.com/user-attachments/assets/11824c25-55e4-46fc-81c5-ca09350f3f27" />

### Schedule Filters & Upcoming Events
At the top of the feed, you can toggle between four filters: **Upcoming**, **Hosting**, **Invites**, and **Attending**. 
* Selecting a filter instantly updates the schedule list below it.
* Your scheduled events are organized chronologically into **"Today"** and **"This Week"**. 

### Discovery Carousels
Below your personal schedule, the page features three horizontal scrolling carousels designed to help you discover new events:
* **For You:** A personalized feed of events curated for your interests ("Your social life curated").
* **In your Area:** A location-based feed showing events happening geographically close to you ("The Streets are calling"). 
* **Friends & Mutuals:** A social feed highlighting events that your inner circle and their connections are interacting with ("Your inner circle's outer circle").

### Action Elements
* **Create Event:** A call-to-action button at the very top of the feed to start planning a new event.
* **Discover More:** A section at the bottom of the feed that encourages broader event exploration.


## Discover Page
<img width="300" alt="bloom_home_screen" src="https://github.com/user-attachments/assets/d75db0da-943d-4034-8db4-6217cf33fe17" />
<img width="300" alt="Screenshot_20260628_164456_com_bloom_bloom_MainActivity" src="https://github.com/user-attachments/assets/c98dc428-c61d-4d77-bae8-5711df0492bf" />
<img width="300" alt="Screenshot_20260628_164501_com_bloom_bloom_MainActivity" src="https://github.com/user-attachments/assets/24759b3f-91ce-4fc7-878a-ab2d1b40b11e" />

### Category Filters
At the top of the screen, there is a horizontal scrolling list of categories to refine your search:
* **Categories:** Options include **All**, **Community**, **Music**, **Film**, **Arts**, **Fitness**, **Food**, and **Education**. Selecting a category filters the events shown below.
* **Filter Icon:** An option to open an advanced filter sheet for more precise event searching.

### Spotlight Carousels
Depending on your selected category filter, the page displays horizontal carousels to highlight specific groups of events:
* **When "All" is selected:** You will see multiple themed carousels such as "Weekend Forecast," "Meet New People" (Community), "After Hours" (Music), and "Silver Screen" (Film).
* **When a specific category is selected:** The page displays a single spotlight carousel at the top tailored to that category (e.g., "After Hours" for Music).

### Vertical Event Feed
Below the spotlight carousels, there is a vertical scrolling feed of events:
* This feed dynamically loads and displays a broader list of events matching your selected category.
* The events are displayed as medium-sized cards. Tapping any card opens the full details for that event.

### Action Elements
* **Create Event:** A call-to-action button placed at the end of the vertical feed (or shown prominently if no events are found) to encourage users to create their own events.

## Calendar Page
<img width="300" alt="Screenshot_20260628_161735_com_bloom_bloom_MainActivity" src="https://github.com/user-attachments/assets/5d3e0c74-60cb-4ccf-99e1-13c09cfc322e" />
<img width="300" alt="Screenshot_20260628_161728_com_bloom_bloom_MainActivity" src="https://github.com/user-attachments/assets/a903d674-9d79-46b0-a7f9-a5717504e1cd" />
<img width="300" alt="Screenshot_20260628_160331_com_bloom_bloom_MainActivity" src="https://github.com/user-attachments/assets/c4da0d15-95cd-4c8a-991e-00d117436cfb" />

### View Toggle
At the top of the content area, you can seamlessly toggle between two different ways to view your schedule:
* **Calendar View (Grid icon):** A traditional monthly calendar layout.
* **List View (List icon):** A continuous, vertically scrolling list of all your scheduled events.

### Calendar View Layout
When using the Calendar View, the screen is split into two main interactive parts:

**1. The Month Grid**
* Displays the days of the current month. Swiping left or right changes the month.
* **Event Indicators:** Days with scheduled events visually indicate activity by displaying the event's poster image directly on that calendar day.
* **Multiple Events:** If a day has more than one event, the calendar day will show overlapping mini-posters. 
* **Pending RSVPs:** If you have an event where your status is "maybe" or "interested," a question mark icon is overlaid on the calendar day.

**2. The Daily Schedule Sheet**
* A draggable panel at the bottom of the screen.
* Tapping any day on the month grid updates this sheet to display a detailed list of all events scheduled for that specific day. 
* You can pull the sheet up to expand it and see more details, or drag it down to see more of the calendar grid. Tapping an event in this sheet opens its full detail page.

### List View Layout
When toggled to the List View, the month grid and bottom sheet are replaced by a straightforward, scrollable feed of all your upcoming events arranged chronologically. This is ideal for quickly scanning what's next without selecting specific dates.

## Profile Page
<img width="300" alt="Bloom_profile_screen_1" src="https://github.com/user-attachments/assets/e628d82e-5421-4304-a4af-e7a3132095fd" />
<img width="300" alt="Bloom_profile_screen_2" src="https://github.com/user-attachments/assets/6cf642de-7b02-4b13-a19f-7fccdff46bcc" />
<img width="300" alt="Bloom_profile_screen_3" src="https://github.com/user-attachments/assets/f2298842-9e8f-4cd1-91c1-4f78fd914441" />

### Identity & Information
* **Profile Picture & Name:** Your avatar is displayed prominently at the top. You can tap it to view it full-screen or edit it to upload a new photo. Your display name is shown directly below it.
* **Social Links:** If you have linked your Instagram, X (Twitter), or Snapchat accounts, their respective icons appear below your stats, allowing others to quickly visit your external profiles.
* **Bio:** A text area describing yourself. If your bio is long, it features an interactive "...more/less" toggle to expand or collapse the text.

### Activity Stats
A horizontal row showcasing your app activity, with each metric being tappable to view more details:
* **Friends made:** Displays your total friend count. Tapping it opens your friends list.
* **Hosted events:** Shows the number of events you have organized.
* **Joined events:** Shows the number of events you have RSVP'd to or attended.

### Action Buttons
Directly below your bio, there are two primary actions:
* **Edit profile:** Opens a screen where you can update your name, bio, and social links.
* **Share profile:** Opens your device's native share menu so you can send a link to your profile to others outside the app.

### Recommended Friends
At the bottom of the profile, there is a section dedicated to suggesting new people you might want to connect with, based on your activity and mutuals.

## Create Page
<img width="300" alt="create_default_screen" src="https://github.com/user-attachments/assets/d08e797c-8870-48ca-a992-9e42949de125" />
<img width="300" alt="create_bowling_screen" src="https://github.com/user-attachments/assets/537a0c12-c7c0-49e0-b515-a6f329e27cf1" />
<img width="300" alt="create_21stCelebration_screen" src="https://github.com/user-attachments/assets/a4b78806-f248-4661-8e95-8592def7ea30" />

### Essential Event Details
At the top of the form, you configure the core aspects of your event:
* **Event Title:** A text field to name your gathering.
* **Poster Upload:** A module to upload a cover photo or poster for the event. The app analyzes this image to generate a matching color theme for the event page.
* **Date & Time:** A selector to set the start and end times.
* **Location:** A search interface to set the exact venue or address.
* **Co-Hosts:** An option to invite friends to help manage the event.

### Audience Settings
This section controls who can see and attend the event:
* **Visibility:** Set the event to public, private, or visible only to friends.
* **Capacity:** Specify a maximum number of available spots for attendees.
* **Plus Ones:** Define how many extra guests each attendee is allowed to bring.

### Extras & Details
Here you can add rich context to make the event page more informative:
* **Extras Pills:** Quick-add buttons to attach specific details like a Link, Playlist, Dress code, Food, Drinks, Parking, Accommodation, or Gift Registry.
* **Tags:** Add categorized tags to help people discover the event (if public).
* **Description:** A detailed text area (up to 2,000 characters) to explain what the event is about.

### RSVP Settings
At the bottom of the form, you can fine-tune how people respond:
* **Approval Required:** Toggle whether attendees need your manual approval to join.
* **Allow "Maybe":** Toggle whether guests can RSVP as "maybe" instead of just yes or no.
* **RSVP Deadline:** Set a specific cutoff date and time for when RSVPs will close.

*(Note: There is also a "Preview" button at the very top right that lets you see exactly how the finished event page will look to guests before you hit post.)*

## Event Invitations Screen
<img width="300" alt="invite_minimized" src="https://github.com/user-attachments/assets/045f6e69-ceef-4b22-8acc-df09358e2afa" />
<img width="300" alt="invite_normal" src="https://github.com/user-attachments/assets/3d206a23-6550-46f2-ada5-02d9361aa401" />
<img width="300" alt="invite_expanded" src="https://github.com/user-attachments/assets/44b5b84b-6b28-483b-9ec4-8b66ebc8ba98" />

### The Draggable Invitation Sheet
The entire invitation screen is built around a fluid, draggable sheet that you can swipe up or down to access different levels of detail. It snaps into three distinct views:

* **Minimized View (Swipe Down):** The sheet drops to the bottom quarter of the screen, leaving just the event title visible. This view is designed to let you see the full, unobstructed event poster or cover image at the top of the screen.
* **Default View (Halfway):** This is the view you see when you first open the invitation. The sheet covers the lower half of the screen, displaying the event title, date/time, and location, while the poster image sits beautifully in the background.
* **Expanded View (Swipe Up):** Pulling the sheet all the way up expands it to cover most of the screen, slightly dimming the poster image behind it. This reveals all the deep details of the event, including:
  * The full description text
  * The guest list (who is going)
  * Host and Co-host profiles
  * A map of the location and the current weather forecast (if a location is set)

You can fluidly flick the sheet up or down, or simply tap the top of the sheet when minimized to quickly pop it back up to the default view.

### The RSVP Bar
This is the floating, pill-shaped gradient bar at the bottom of the event invitation that lets you respond to an event. It dynamically adjusts based on the event's settings.

### The Three States
By default, the bar presents up to three distinct options:
* **Going:** Confirms your attendance. If the event is full but has a waitlist, this changes to **Waitlist**. If the event requires approval, this changes to **Get on List** (which switches your status to *Requested*).
* **Maybe:** Indicates you are interested but unsure. *(Note: The host can disable this option, in which case the bar only shows Yes/No).*
* **Decline:** You cannot attend. Selecting this lets the host know you won't make it.

### Interactive Elements
* **Sliding Selection:** When you tap an option, a white background smoothly slides over to highlight your active selection.
* **Plus Ones Prompt:** If you select "Going" (or "Requested") and the host has allowed plus ones, a menu slides up asking "Bringing anyone?" You can select "Just Me" or choose how many extra guests you are bringing up to the host's limit.
* **RSVP Removal Warning:** If you are approved for an event that requires approval and you try to change your status, a warning pops up reminding you that if you leave, you'll have to request access all over again.
* **Deadline Lockout:** If the event's RSVP deadline has passed, the buttons disappear and are replaced by a message saying "RSVP period has ended."
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
git clone https://github.com/SiveCosa/bloom.git
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

**Configure your own Firebase project**

To run the application locally, connect the app to your own Firebase project:
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

## Technical Highlights

- **Fluid, Gesture-Driven UI**: Built with complex animations and micro-interactions, such as the fluid, draggable RSVP sheet on event invitations that snaps to different content views.
- **Reactive State Management**: Heavy utilization of Riverpod for a highly decoupled, reactive architecture that updates feeds and UI states instantly across the app.
- **Advanced Navigation**: Uses GoRouter for deep linking and managing complex navigation stacks seamlessly.
- **Real-time Backend Syncing**: Leveraging Firebase Firestore streams for instant updates across event feeds, guest lists, and chat features.

## Tech Stack & Architecture

This application follows a modern Flutter architecture emphasizing clean separation of concerns:
- **Frontend**: Flutter & Dart for cross-platform deployment.
- **State Management**: Riverpod for reactive caching, data-binding, and state handling.
- **Routing**: GoRouter for declarative routing.
- **Backend**: Firebase suite (Authentication, Firestore, Cloud Storage).
- **Architecture Pattern**: Adopts a layered architecture separating UI/View, State/Providers, and Domain/Service layers for optimal testability and maintainability.

## Repository Note

This repository is a portfolio fork of a collaborative university project. Project credit belongs to the Bloom development team, and the sections above identify my individual contributions.
