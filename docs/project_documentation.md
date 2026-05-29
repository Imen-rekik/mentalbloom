# MentalBloom — Academic Project Documentation

## 1. Global Summary

**MentalBloom** is a cross-platform mobile application built with **Flutter** and **Firebase** that serves as a personal mental wellness companion. It combines mood tracking, AI-powered conversational support, journaling, guided breathing exercises, ambient soundscapes, mental health podcasts, and an anonymous peer-support community — all within a single cohesive application.

---

## 2. Technology Stack

| Layer | Technology |
|---|---|
| **Language** | Dart |
| **Framework** | Flutter (Material 3) |
| **Backend / Database** | Google Firebase (Authentication + Cloud Firestore) |
| **AI / LLM Integration** | OpenRouter API (multi-model fallback routing) |
| **Audio** | `audioplayers` package |
| **Charts** | `fl_chart` package |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **State Management** | Provider (`ChangeNotifier`) |
| **Environment Config** | `flutter_dotenv` (`.env` file for API keys) |
| **Permissions** | `permission_handler` |
| **Local Storage** | `shared_preferences` (notification scheduling only) |

---

## 3. Overall Architecture

The project follows a **layered architecture** with clear separation of concerns:

```
lib/
├── main.dart                  # Entry point & auth routing
├── firebase_options.dart      # Auto-generated Firebase config
├── theme/
│   └── app_colors.dart        # Global color palette
├── models/
│   └── community_post.dart    # Data models for community
├── services/                  # Business logic layer
│   ├── firebase_service.dart          # Auth, Firestore CRUD, state
│   ├── ai_service.dart                # AI chatbot via OpenRouter
│   ├── moderation_service.dart        # AI content moderation
│   ├── mood_summary_service.dart      # AI daily mood summaries
│   ├── podcast_provider.dart          # Audio player state
│   ├── notification_scheduler.dart    # Local push notifications
│   └── notification_prompt_service.dart # Permission deferral
└── screens/                   # UI / Presentation layer (19 screens)
    ├── login_screen.dart
    ├── email_verification_screen.dart
    ├── name_entry_screen.dart
    ├── main_layout.dart
    ├── dashboard_screen.dart
    ├── mood_check_in_section.dart
    ├── mood_details_screen.dart
    ├── mood_entry_screen.dart
    ├── history_analytics_screen.dart
    ├── chatbot_screen.dart
    ├── community_screen.dart
    ├── journal_screen.dart
    ├── journal_editor_screen.dart
    ├── podcast_screen.dart
    ├── relax_screen.dart
    ├── breath_screen.dart
    ├── gratitude_jar_screen.dart
    ├── quick_relief_modal.dart
    └── notification_permission_prompt.dart
```

**State management** uses the **Provider** pattern. `FirebaseService` and `PodcastProvider` are registered as `ChangeNotifierProvider`s at the root of the widget tree and are consumed by screens via `Provider.of<T>(context)`.

---

## 4. File-by-File Description

### 4.1 Entry Point

#### `main.dart`
- **Purpose**: Application entry point. Initializes Firebase, loads environment variables, sets up the notification system, and registers global providers.
- **Key classes**:
  - `main()` — Async initialization sequence: dotenv → Firebase → notifications → `runApp`.
  - `MentalBloomApp` — Root `MaterialApp` with theme configuration.
  - `AuthWrapper` — Reactive widget that observes `FirebaseService` and routes users to the appropriate screen based on authentication state (not logged in → `LoginScreen`, unverified email → `EmailVerificationScreen`, no name set → `NameEntryScreen`, fully authenticated → `MainLayout`).

### 4.2 Theme

#### `app_colors.dart`
- **Purpose**: Centralized color palette used across all screens.
- **Colors defined**: `primary` (teal), `secondary` (light cyan), `background` (white), `accent` (salmon pink), `textMain` (dark grey), `textLight` (medium grey).

### 4.3 Models

#### `community_post.dart`
- **Purpose**: Data models for the anonymous community feature.
- **Classes**:
  - `CommunityPost` — Represents a user post with fields: `id`, `userId`, `username`, `content`, `timestamp`, `reactionsCount` (map of emoji→count), and `userReaction`. Includes a `fromFirestore()` factory that deserializes a Firestore `DocumentSnapshot`.
  - `CommunityComment` — Represents a reply/comment on a post, also with a `fromFirestore()` factory.

### 4.4 Services (Business Logic Layer)

#### `firebase_service.dart` (817 lines — the core service)
- **Purpose**: Central service that manages authentication, user profiles, mood tracking, journaling, chat persistence, and AI summary caching. Acts as the single source of truth for app state.
- **Key responsibilities**:
  - **Authentication**: `login()`, `signup()`, `logout()`, `resendVerificationEmail()`, `refreshAuthStatus()`. Includes input validation, timeout handling, and human-readable error mapping for all Firebase Auth error codes.
  - **Auth state listener**: `_handleAuthChanged()` reacts to Firebase auth state changes, loads the user profile, validates email verification, and resets local state on logout.
  - **Mood tracking**: `saveMood()` uses a **Firestore transaction** to atomically save a mood entry and update the user's streak counter. The streak logic checks the number of days between the last entry and today: if exactly 1 day → increment streak; if >1 day → reset to 1; if same day → no change. Also tracks `longestStreak`.
  - **Mood queries**: `getLatestMoodLabel()`, `getMoodsForLast7Days()`, `getMoodsForLast14Days()`, `getAllMoods()` — time-windowed Firestore queries for analytics.
  - **Journaling**: Full CRUD — `addJournal()`, `updateJournal()`, `deleteJournal()`, `loadJournals()`. Journals are stored in `users/{uid}/journals/`.
  - **Chat persistence**: `saveChatMessage()` stores messages both in local state and in Firestore under `users/{uid}/chatSessions/{date}/messages/`. `getTodayChatHistory()` retrieves a day's conversation. `initChatIfNeeded()` seeds the chat with an initial bot greeting.
  - **AI Summary caching**: `getDailySummary()` / `saveDailySummary()` read/write cached AI summaries to `users/{uid}/ai_summaries/{date}` to avoid redundant API calls.
  - **Community helpers**: `getMyComments()` uses a Firestore `collectionGroup` query to fetch all comments by a user across all posts.
  - **Notification integration**: After saving a mood, calls `cancelMorningReminderForTodayIfBeforeNine()` to suppress the morning reminder since the user has already checked in.

#### `ai_service.dart`
- **Purpose**: Handles all AI chatbot conversations via the OpenRouter API.
- **Key logic**:
  - Organizes LLM models into **3 fallback groups of 3 models each** (OpenRouter's maximum). If Group 1 returns a 429 rate-limit error, the service automatically retries with Group 2, then Group 3.
  - Uses a carefully crafted **system prompt** that instructs the AI to be empathetic, non-judgmental, culturally aware (Tunisian context — supports Darija, French, English), and includes a **crisis protocol** that triggers a professional-help disclaimer when self-harm is mentioned.
  - `sendMessage()` — Core method. Sends a user message with the system prompt to OpenRouter, parses the response, and returns the AI's reply.
  - `generateMoodQuote()` — Generates a short motivational quote tailored to the user's current mood. Falls back to a local dictionary of pre-written quotes if the API fails.

#### `moderation_service.dart`
- **Purpose**: AI-powered content moderation for the anonymous community feature. Every post and reply is checked before publication.
- **Key logic**:
  - Uses the same multi-group fallback strategy (3 groups × 3 models).
  - `tryModerate()` sends the user's text to the AI with a prompt that asks it to classify the content as `safe` or `unsafe` and return a structured JSON response (`{"safe": true/false, "reason": "..."}`).
  - Strips `<think>` blocks (from reasoning models like DeepSeek R1) and markdown backticks before parsing.
  - `moderateContent()` iterates through all groups. If every group fails, it **defaults to unsafe** (fail-closed) to ensure community safety when the service is unavailable.

#### `mood_summary_service.dart`
- **Purpose**: Generates a daily AI-written narrative summary of the user's mood data, journal entries, and chat conversations.
- **Key logic**:
  - Same multi-group fallback architecture.
  - Uses a **system prompt** that instructs the AI to write a warm, specific, 80-word-max paragraph reflecting *why* the user felt a certain way, without giving advice or using clinical language.
  - `generateDailySummary()` takes a date string and a pre-formatted text block of all user data for that day, sends it to the AI, cleans the response (strips `<think>` blocks), and returns the summary.
  - Uses a separate API key (`OPENROUTER_API_KEY_SUMMARY`) to avoid rate-limit conflicts with the chatbot.

#### `podcast_provider.dart`
- **Purpose**: Manages audio playback state for the podcast feature using `ChangeNotifier`.
- **Key classes**:
  - `PodcastEpisode` — Immutable data class holding episode metadata (title, podcast name, duration, audio URL, emoji, colors).
  - `PodcastProvider` — Wraps `AudioPlayer`, exposes reactive state (`isPlaying`, `position`, `duration`, `currentEpisode`), and provides playback controls (`playEpisode()`, `pause()`, `resume()`, `seek()`, `skipForward15()`, `skipBackward15()`). Supports both local asset paths and network URLs.

#### `notification_scheduler.dart`
- **Purpose**: Schedules local push notifications to remind users to check in with their mood throughout the day.
- **Key logic**:
  - Schedules notifications for a **21-day rolling window** at three daily times: morning (9:00), midday (14:00), and evening (21:00).
  - Uses deterministic notification IDs derived from `YYYYMMDD + reminderType` to avoid duplicates.
  - Maintains a list of scheduled IDs in `SharedPreferences` and prunes expired ones.
  - `cancelMorningReminderForTodayIfBeforeNine()` — Called after a mood save to cancel the morning reminder if the user already checked in.

#### `notification_prompt_service.dart`
- **Purpose**: Manages the timing of the notification permission prompt with a deferral mechanism.
- **Key logic**: If the user declines, the prompt is deferred for 24 hours using `SharedPreferences`.

### 4.5 Screens (UI / Presentation Layer)

#### `login_screen.dart`
- **Purpose**: Authentication screen supporting both login and signup modes via a toggle button.
- **Features**: Email/password input fields, loading state, friendly error display via `SnackBar`. Delegates all auth logic to `FirebaseService`.

#### `email_verification_screen.dart`
- **Purpose**: Intermediate screen shown after signup, prompting the user to verify their email address before proceeding. Includes a "Resend" button and a "Check Status" button.

#### `name_entry_screen.dart`
- **Purpose**: One-time onboarding screen where new users set their display name after email verification. The name is stored in the Firestore `users` collection.

#### `main_layout.dart`
- **Purpose**: The primary navigation shell. Uses `IndexedStack` with a `BottomNavigationBar` containing 5 tabs: Home, Chat, Podcasts, Journal, and Relax.
- **Key logic**: On initialization, loads journals, checks if notification permissions should be prompted, schedules daily reminders, and handles deep-linking from notification taps (scrolls to mood check-in section).

#### `dashboard_screen.dart`
- **Purpose**: The home screen. Displays a personalized greeting, the mood check-in widget, and navigation cards to the Mood Tracker (analytics) and Gratitude Jar features.

#### `mood_check_in_section.dart` (939 lines)
- **Purpose**: An interactive, animated mood dial widget embedded in the dashboard. This is the primary entry point for mood tracking.
- **Key features**: Custom-painted arc dial with 5 mood options (Happy, Neutral, Sad, Anxious, Angry), drag-to-select interaction, animated emoji face, real-time clock display, streak counter, and an AI-generated mood-specific quote. After selection, navigates to `MoodDetailsScreen` for intensity and symptom logging. Also includes a "Quick Relief" button that opens `QuickReliefModal`.

#### `mood_details_screen.dart` (819 lines)
- **Purpose**: A detailed mood logging screen reached after selecting a mood from the dial. Allows the user to rate intensity (1–10 slider), select physical/emotional symptoms from a curated list, and write free-text notes.
- **Key features**: Mood-specific color themes, symptom chip selection, notes text field, and an AI daily summary section that displays a cached or freshly generated narrative summary of the user's day.

#### `mood_entry_screen.dart`
- **Purpose**: A simpler, alternative mood entry screen with emoji selection and intensity slider. Displays a streak celebration dialog after saving.

#### `history_analytics_screen.dart` (1206 lines — the largest screen)
- **Purpose**: Comprehensive mood analytics dashboard with interactive charts and historical data.
- **Key features**:
  - **Donut chart**: Shows intensity-weighted mood distribution using `fl_chart`. Each emotion has a distinct color and can be toggled on/off.
  - **Line chart**: 14-day mood trend graph with interactive touch tooltips.
  - **Daily mood logs**: Grouped-by-date list of all mood entries with timestamps, intensity bars, symptoms, and notes. Defaults to showing yesterday's entries. Includes a date picker for historical navigation.
  - **AI daily summaries**: For each date group, displays an AI-generated narrative summary (fetched from `MoodSummaryService`, cached in Firestore).

#### `chatbot_screen.dart`
- **Purpose**: Dual-tab screen containing the AI chatbot and the Community feature.
- **Tab 1 (AI Companion)**: A real-time chat interface. User messages are sent to `AIService.sendMessage()`, and both user and bot messages are persisted to Firestore via `FirebaseService.saveChatMessage()`. Uses a `ListView.builder` for the message list with auto-scroll-to-bottom behavior.
- **Tab 2 (Community)**: Embeds the `CommunityScreen` widget.

#### `community_screen.dart` (829 lines)
- **Purpose**: Anonymous peer-support community feed, fully backed by Firestore with real-time updates.
- **Key features**:
  - **Post creation**: Text input (280-char limit) with AI moderation gate. Every post is checked by `ModerationService` before being written to Firestore.
  - **Real-time feed**: Uses Firestore `StreamBuilder` for live updates. Supports infinite scroll (loads 20 posts at a time, appends more on scroll).
  - **"My Posts Only" filter**: Toggle switch that filters posts by the current user's UID using a Firestore composite query.
  - **Reactions**: Three emoji reactions (💙, 🤝, ✨) with atomic counting using `FieldValue.increment()` and batched writes. Each user can have exactly one reaction per post (toggling or switching).
  - **Nested comments**: Expandable reply sections with their own real-time `StreamBuilder`. Replies are also moderated before submission.
  - **"You" badge**: Posts and comments by the current user are visually marked with a "You" badge using UID comparison.
  - **Privacy**: All usernames are hardcoded to "Anonymous".

#### `journal_screen.dart`
- **Purpose**: Displays a searchable list of the user's journal entries. Supports search by title or date, tap to edit, long-press to delete.

#### `journal_editor_screen.dart`
- **Purpose**: Full-screen text editor for creating or editing journal entries with title and content fields.

#### `podcast_screen.dart`
- **Purpose**: A curated library of mental health podcast episodes (primarily Andrew Huberman) with an integrated audio player.
- **Features**: Episode list with metadata (title, duration, emoji), a bottom mini-player bar showing the currently playing episode with play/pause, skip ±15s, and a seek slider. Audio files are bundled as local assets.

#### `relax_screen.dart`
- **Purpose**: Relaxation hub with two sections: a guided breathing exercise card (navigates to `BreathScreen`) and an ambient sound player.
- **Ambient sounds**: 6 looping sounds (Quran, Rain, Forest, Ocean, Fire, River) loaded from local audio assets. Volume slider control. Dark-themed UI.

#### `breath_screen.dart`
- **Purpose**: Full-screen guided breathing exercise using the 4-7-8 method (4s inhale, 7s hold, 8s exhale).
- **Key features**: Custom `AnimationController` driving a pulsing orb that expands during inhale, holds at peak, and contracts during exhale. A `CustomPainter` (`ProgressArcPainter`) draws a circular progress arc around the orb. Runs for 5 rounds then shows a completion button.

#### `gratitude_jar_screen.dart`
- **Purpose**: An interactive "Insight Vessel" with premium glassmorphism design. The user taps a floating glass jar to receive an AI-generated motivational quote personalized to their current mood.
- **Key logic**: Fetches the user's latest mood from Firestore, sends it to `AIService.generateMoodQuote()`, and displays the result in a premium bottom sheet. The jar has a continuous floating animation and a shake animation on tap.

#### `quick_relief_modal.dart`
- **Purpose**: A fullscreen dark overlay with 4 quick-action buttons: "Talk it out" (→ Chatbot), "Write it down" (→ Journal), "Take a breath" (→ Relax), "Calming sounds" (→ Relax). Provides immediate coping tool access when the user is in distress.

#### `notification_permission_prompt.dart`
- **Purpose**: Custom dialog that explains why notifications are beneficial and requests permission. Offers "Enable" and "Not Now" options.

---

## 5. The AI/ML Component

### 5.1 Models Used
MentalBloom does **not** train or fine-tune any model. It consumes pre-trained Large Language Models (LLMs) via the **OpenRouter API**, which acts as a unified gateway to multiple model providers. The models used include:

| Group | Models |
|---|---|
| **Group 1** | Qwen 2.5 72B, Llama 3.3 70B, Gemini Flash 1.5 |
| **Group 2** | DeepSeek R1, Mistral Small 24B, Gemini 2.0 Flash Lite |
| **Group 3** | GPT-4o Mini, Claude 3 Haiku, Mistral Nemo |

### 5.2 How the AI is Used (3 Distinct Use Cases)

**Use Case 1 — Conversational Chatbot (`ai_service.dart`)**
- **Input**: User's text message + system prompt defining the AI's persona (empathetic mental health assistant).
- **Output**: A supportive, conversational text response.
- **Data flow**: User types message → `AIService.sendMessage()` → HTTP POST to OpenRouter → AI response → displayed in chat UI → saved to Firestore.

**Use Case 2 — Content Moderation (`moderation_service.dart`)**
- **Input**: The text content of a community post or reply + a classification prompt.
- **Output**: A JSON object `{"safe": true/false, "reason": "..."}`.
- **Data flow**: User writes post → `ModerationService.moderateContent()` → AI classifies → if safe, post is written to Firestore; if unsafe, a dialog asks the user to rephrase.

**Use Case 3 — Daily Mood Summary (`mood_summary_service.dart`)**
- **Input**: A formatted text block containing the user's mood entries, journal entries, and chat conversations for a specific date.
- **Output**: A warm, specific 3–4 sentence paragraph reflecting why the user may have felt the way they did.
- **Data flow**: User opens analytics → app collects day's data from Firestore → `MoodSummaryService.generateDailySummary()` → AI generates narrative → cached in Firestore `ai_summaries` sub-collection → displayed in UI.

### 5.3 Fallback Strategy
All three AI services use a **sequential group fallback** mechanism. OpenRouter's `"route": "fallback"` parameter tells it to try each model in the group sequentially. If the entire group fails (e.g., 429 rate limit), the app catches the error and retries with the next group. If all 3 groups fail, a secure default is returned (chatbot returns a friendly message, moderation defaults to **"unsafe"** to protect the community, and the summary returns a placeholder message).

---

## 6. Firestore Data Model

```
Firestore Root
├── users/{userId}
│   ├── name, email, moodStreak, longestStreak, lastEntryDate, createdAt
│   ├── moods/{moodId}
│   │   └── label, intensity, notes, symptoms, createdAt
│   ├── journals/{journalId}
│   │   └── title, content, date, createdAt, updatedAt
│   ├── chatSessions/{date}
│   │   └── messages/{messageId}
│   │       └── role, content, timestamp, date
│   └── ai_summaries/{date}
│       └── summary, createdAt
│
└── communityPosts/{postId}
    ├── userId, username, content, timestamp, reactionsCount
    ├── comments/{commentId}
    │   └── userId, username, content, timestamp
    └── reactions/{userId}
        └── userId, reactionType, timestamp
```

### Security Rules (Production — deployed to Firebase Console)
- **Users collection**: Read/write restricted to the authenticated user matching the document's UID. A recursive wildcard (`/{document=**}`) grants access to all nested sub-collections (moods, journals, chatSessions, ai_summaries).
- **Community posts**: Public read for authenticated users. Create requires `userId` matching auth UID. Update/delete restricted to the post owner. Comments follow the same pattern. Reactions are keyed by UID, so each user can only modify their own reaction document.

---

## 7. External API Connections

| Service | Purpose | Authentication |
|---|---|---|
| **Firebase Auth** | User registration, login, email verification | Firebase SDK (auto) |
| **Cloud Firestore** | Persistent data storage for all user data and community content | Firebase SDK (auto) |
| **OpenRouter API** | Gateway to multiple LLMs for chatbot, moderation, and summaries | Bearer token via `OPENROUTER_API_KEY` in `.env` |

---

## 8. Main User-Facing Features

1. **Mood Check-In** — Interactive arc dial with 5 emotions, intensity slider, symptom selection, and free-text notes
2. **AI Chatbot** — Empathetic conversational assistant with Tunisian cultural awareness and crisis detection
3. **Anonymous Community** — Peer-support feed with AI-moderated posts, nested comments, and emoji reactions
4. **Journal** — Personal diary with full CRUD, search, and date tracking
5. **Mood Analytics** — Donut chart, 14-day line graph, daily mood logs, and AI-generated narrative summaries
6. **Guided Breathing** — 4-7-8 breathing exercise with animated visual orb
7. **Ambient Sounds** — 6 looping nature/spiritual sounds with volume control
8. **Mental Health Podcasts** — Curated audio episodes with integrated player
9. **Gratitude / Insight Vessel** — AI-powered personalized quote generator with glassmorphism UI
10. **Push Notifications** — 3 daily reminders (morning, midday, evening) for mood check-in
11. **Streak System** — Gamification via consecutive-day mood logging streaks

---

## 9. Data Flow: User → AI → User

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌───────────┐
│   User   │────▶│  Flutter UI  │────▶│  AI Service  │────▶│ OpenRouter│
│  (Input) │     │  (Screen)    │     │  (HTTP POST) │     │   API     │
└──────────┘     └──────────────┘     └──────────────┘     └─────┬─────┘
                        ▲                                        │
                        │              ┌──────────────┐          │
                        └──────────────│  AI Response  │◀────────┘
                                       │  (JSON Parse) │
                                       └──────┬───────┘
                                              │
                                       ┌──────▼───────┐
                                       │   Firestore   │
                                       │  (Persist)    │
                                       └──────────────┘
```

1. User interacts with the UI (sends a chat message, writes a post, or opens analytics).
2. The relevant service constructs an HTTP POST request with the user's data and a system prompt.
3. The request is sent to OpenRouter, which routes it to the best available model in the specified fallback group.
4. The AI model generates a response (chat reply, moderation verdict, or narrative summary).
5. The Flutter app parses the JSON response, strips any model artifacts (like `<think>` blocks), and displays the result.
6. The result is persisted to Firestore for caching and history.
