# Revo — Theatre Production Management System

> **Mobile Theatre Production Coordination System** built with Flutter & Dart, powered by Firebase Authentication & Cloud Firestore. Developed by Team **S130-Revo** under the Kalvium Community.

---

## 📌 Terminology Rule
> **Production** is the single authoritative term used for a theatre production throughout the product, UI, Firestore data model, repository documentation, and presentations. The term **"Show"** is strictly prohibited as an alternate product term.

---

## 📖 Table of Contents
1. [Product Overview & Problem Statement](#1-product-overview--problem-statement)
2. [Target Users & Stakeholders](#2-target-users--stakeholders)
3. [Key Performance Indicators & Impact Framework](#3-key-performance-indicators--impact-framework)
4. [Functional & Non-Functional Requirements](#4-functional--non-functional-requirements)
5. [Architecture & Project Folder Structure](#5-architecture--project-folder-structure)
6. [Firestore Data Model & API Specifications](#6-firestore-data-model--api-specifications)
7. [API Integration Setup & Connectivity Fallback](#7-api-integration-setup--connectivity-fallback)
8. [Team Task Alignment & Sprint Matrix](#8-team-task-alignment--sprint-matrix)
9. [Development & Git Workflow](#9-development--git-workflow)
10. [Getting Started & Local Setup](#10-getting-started--local-setup)

---

## 1. Product Overview & Problem Statement

### Core Coordination Problem
A regional theatre group manages auditions, rehearsal schedules, and cast assignments across several simultaneous productions, but coordination through group chats becomes unmanageable once multiple productions run in parallel. Cast members miss schedule changes, venues get double-booked, and directors have no consolidated view of commitments.

### Product Solution
**Revo** provides a centralized, authoritative mobile workflow for theatre groups coordinating multiple **Productions**. It standardizes data structures for Productions, auditions, applications, roles, cast assignments, rehearsals, and venues, providing real-time synchronization and offline availability.

```
Production → Auditions → Cast → Rehearsals → Venues → Conflict Checks → Schedule → Real-Time Updates
```

---

## 2. Target Users & Stakeholders

| Role | Core Responsibilities | Key Needs in Revo |
| :--- | :--- | :--- |
| **Director** *(Primary)* | Manages Productions, auditions, roles, cast assignments, rehearsal schedules, and venue bookings. | Conflict detection before rehearsal confirmation, central view of commitments. |
| **Cast Member** *(Primary)* | Browses auditions, submits applications, views assignment status, checks personal schedules. | Unified personal schedule, real-time schedule updates, offline schedule caching. |
| **Theatre Admin** *(Admin)* | Manages venues, theatre-wide resources, user roles, and access controls. | Venue capacity/availability setup, system access control. |
| **Team Lead / Admin** | Technical architecture, code quality, PR approval, and deployment pipelines. | Clean modular architecture, clear API contracts, strict Git workflow. |

---

## 3. Key Performance Indicators & Impact Framework

### Operational Impact Targets
- **Coordination Time**: Target $\ge 30\%$ reduction in weekly schedule searching & correction time post-pilot.
- **Missed/Delayed Schedule Updates**: Target $\ge 50\%$ reduction in delayed schedule communications.
- **Venue Double-Bookings**: **0 confirmed conflicts** in tested MVP scenarios (Acceptance Criterion).
- **Cast Rehearsal Overlaps**: **0 confirmed conflicts** in tested MVP scenarios (Acceptance Criterion).
- **Real-Time Update Reliability**: $\ge 90\%$ of connected schedule changes propagate without manual refresh.
- **Offline Schedule Availability**: $100\%$ access to locally cached schedule during network disconnection.

---

## 4. Functional & Non-Functional Requirements

### Functional Requirements Summary (FR-01 to FR-18)
- **FR-01 (Authentication & Role Access)**: User registration/login with Director, Cast Member, or Admin role assignment.
- **FR-02 (Production Management)**: Authorized Directors create, update, and manage assigned Productions.
- **FR-03 (Audition Management)**: Directors list auditions linked to a Production; Cast Members apply and view status.
- **FR-04 (Roles & Cast Assignment)**: Directors define Production roles and assign selected Cast Members.
- **FR-05 (Rehearsal Scheduling)**: Creation of rehearsal sessions specifying Production, venue, date, time, and participants.
- **FR-06 (Venue Management)**: Admins configure venues and availability; Directors view real-time venue status.
- **FR-07 (Conflict Detection)**: Automated pre-confirmation checks for venue time collisions and Cast Member schedule overlaps.
- **FR-08 (Conflict Resolution)**: Interactive UI to resolve detected conflicts by changing time, venue, or participants.
- **FR-09 (Unified Schedule)**: Chronological, personalized schedule view for Cast Members and production-wide schedules for Directors.
- **FR-10 (Connected Real-Time Updates)**: Live Firestore stream listeners for instant UI updates.
- **FR-11 (In-App Update State)**: Visible indicators surfacing schedule changes and conflict alerts.
- **FR-12 (Offline/Cached Schedule)**: Cached data display when offline with visible last-synced timestamp.
- **FR-13 (Safe Pending Writes)**: Queued offline writes marked as `Pending` until server-validated upon reconnect.
- **FR-14 (Reconnect Reconciliation)**: Server-side revalidation and conflict check upon re-establishing connection.
- **FR-15 (Director Dashboard)**: Consolidated view of active Productions, auditions, rehearsals, and pending conflicts.
- **FR-16 (Cast Dashboard)**: Personalized hub showing My Schedule, My Productions, and Audition Applications.
- **FR-17 (Admin Dashboard)**: Central management interface for user access and venue catalog.
- **FR-18 (Profile & Access Management)**: Profile overview, role verification, and logout handling.

---

## 5. Architecture & Project Folder Structure

Revo follows a modular **Clean Architecture** approach using Flutter and Dart, separating presentation, domain, and data layers to maintain high testability and maintainability.

```
lib/
├── main.dart                          # Application entry point & initialization
├── app.dart                           # MaterialApp, routing, & global theme setup
├── core/                              # Shared core utilities & infrastructure
│   ├── constants/                     # Colors, typography, strings, app constants
│   ├── errors/                        # Custom exceptions & failure models
│   ├── network/                       # Connectivity listener & network info
│   ├── theme/                         # Light/Dark design system theme
│   └── utils/                         # Date/time formatters, conflict validators
├── data/                              # Data Layer: Models, Data Sources & Repositories
│   ├── datasources/
│   │   ├── local/                     # Local cache (SharedPreferences/Hive) for offline schedule
│   │   └── remote/                    # Firebase Firestore & Auth datasources
│   ├── models/                        # JSON/Firestore Serializable Data Models
│   │   ├── user_model.dart
│   │   ├── production_model.dart
│   │   ├── audition_model.dart
│   │   ├── application_model.dart
│   │   ├── role_model.dart
│   │   ├── cast_assignment_model.dart
│   │   ├── rehearsal_model.dart
│   │   ├── venue_model.dart
│   │   └── notification_model.dart
│   └── repositories/                  # Repository implementations wrapping datasources
├── domain/                            # Domain Layer: Entities, Interfaces & Use Cases
│   ├── entities/                      # Pure Dart business objects
│   ├── repositories/                  # Repository interface definitions
│   └── usecases/                      # Business logic use cases
│       ├── auth_usecase.dart
│       ├── production_usecase.dart
│       ├── schedule_usecase.dart
│       ├── conflict_detection_usecase.dart
│       └── offline_sync_usecase.dart
└── presentation/                      # Presentation Layer: UI Widgets, Screens & State
    ├── providers/                     # State management (Notifier/Provider/Bloc)
    ├── screens/
    │   ├── auth/                      # LoginScreen, RegisterScreen, RoleSelection
    │   ├── director/                  # DirectorDashboard, ProductionDetails, CreateRehearsal
    │   ├── cast/                      # CastDashboard, MySchedule, AuditionDetails
    │   ├── admin/                     # AdminDashboard, VenueManagement, UserAccess
    │   └── common/                    # ConflictResolutionScreen, ProfileScreen
    └── widgets/                       # Reusable UI components (ScheduleCard, OfflineBanner, etc.)
```

---

## 6. Firestore Data Model & API Specifications

### Collection Architecture & Schemas

#### 1. `users` Collection
Path: `users/{userId}`
```json
{
  "userId": "string (PK, Firebase Auth UID)",
  "name": "string",
  "email": "string",
  "role": "string ('Director' | 'Cast Member' | 'Admin')",
  "createdAt": "timestamp"
}
```

#### 2. `productions` Collection
Path: `productions/{productionId}`
```json
{
  "productionId": "string (PK)",
  "name": "string",
  "description": "string",
  "directorId": "string (FK -> users.userId)",
  "startDate": "timestamp",
  "endDate": "timestamp",
  "status": "string ('Draft' | 'Active' | 'Completed')",
  "createdAt": "timestamp"
}
```

#### 3. `auditions` Collection
Path: `auditions/{auditionId}`
```json
{
  "auditionId": "string (PK)",
  "productionId": "string (FK -> productions.productionId)",
  "date": "timestamp",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "venueId": "string (FK -> venues.venueId)",
  "availableRoles": "array<string> (roleIds)",
  "status": "string ('Open' | 'Closed')"
}
```

#### 4. `applications` Collection
Path: `applications/{applicationId}`
```json
{
  "applicationId": "string (PK)",
  "auditionId": "string (FK -> auditions.auditionId)",
  "castMemberId": "string (FK -> users.userId)",
  "status": "string ('Pending' | 'Accepted' | 'Rejected')",
  "submittedAt": "timestamp"
}
```

#### 5. `roles` Collection
Path: `roles/{roleId}`
```json
{
  "roleId": "string (PK)",
  "productionId": "string (FK -> productions.productionId)",
  "name": "string",
  "description": "string",
  "status": "string ('Open' | 'Filled')"
}
```

#### 6. `castAssignments` Collection
Path: `castAssignments/{assignmentId}`
```json
{
  "assignmentId": "string (PK)",
  "productionId": "string (FK -> productions.productionId)",
  "roleId": "string (FK -> roles.roleId)",
  "castMemberId": "string (FK -> users.userId)",
  "assignedAt": "timestamp",
  "status": "string ('Confirmed' | 'Pending')"
}
```

#### 7. `rehearsals` Collection
Path: `rehearsals/{rehearsalId}`
```json
{
  "rehearsalId": "string (PK)",
  "productionId": "string (FK -> productions.productionId)",
  "venueId": "string (FK -> venues.venueId)",
  "date": "timestamp",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "participantIds": "array<string> (userIds)",
  "status": "string ('Scheduled' | 'Cancelled' | 'Completed')"
}
```

#### 8. `venues` Collection
Path: `venues/{venueId}`
```json
{
  "venueId": "string (PK)",
  "name": "string",
  "location": "string",
  "capacity": "number",
  "availability": "map (day/time bounds)",
  "status": "string ('Active' | 'Maintenance')"
}
```

#### 9. `notifications` Collection
Path: `notifications/{notificationId}`
```json
{
  "notificationId": "string (PK)",
  "userId": "string (FK -> users.userId)",
  "type": "string ('ScheduleUpdate' | 'ConflictAlert' | 'AuditionStatus')",
  "message": "string",
  "relatedId": "string",
  "createdAt": "timestamp",
  "read": "boolean"
}
```

---

## 7. API Integration Setup & Connectivity Fallback

### 1. Firebase Authentication & Role Management
- Users authenticate via Firebase Auth.
- User profile record stored in `users/{userId}` contains the assigned role (`Director`, `Cast Member`, `Admin`).
- Client-side navigation guards & Firestore Security Rules enforce role-based access.

### 2. Firestore Initialization & Offline Persistence
```dart
void initializeFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Enable offline persistence for local schedule access
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
```

### 3. Pre-Confirmation Conflict Detection Algorithm
Before confirming a new rehearsal or schedule modification, the application runs two client/server validation checks:

```
                  ┌────────────────────────────────────────┐
                  │ Request: Create / Edit Rehearsal       │
                  └───────────────────┬────────────────────┘
                                      │
           ┌──────────────────────────┴──────────────────────────┐
           ▼                                                     ▼
┌───────────────────────────────┐                     ┌───────────────────────────────┐
│ Venue Overlap Query           │                     │ Cast Member Overlap Query     │
│ Same venueId & overlapping    │                     │ Any participantId in existing │
│ startTime < T_end AND         │                     │ rehearsal with overlapping    │
│ endTime > T_start             │                     │ time window                   │
└──────────────┬────────────────┘                     └──────────────┬────────────────┘
               │                                                     │
               └──────────────────────────┬──────────────────────────┘
                                          │
                        ┌─────────────────┴─────────────────┐
                        │ Conflicts Found?                  │
                        └────────┬─────────────────┬────────┘
                             YES │                 │ NO
                                 ▼                 ▼
                    ┌───────────────────┐   ┌───────────────────┐
                    │ Block Confirmation│   │ Confirm & Write   │
                    │ Display Conflict  │   │ to Firestore      │
                    │ Resolution UI     │   └───────────────────┘
                    └───────────────────┘
```

### 4. Connectivity Fallback & Sync State Rules
- **Live State**: Connected to Firestore via `snapshots()`. Changes update UI immediately.
- **Offline Cached State**: When disconnected, display cached schedule with a visible **"Last Synced: HH:mm"** timestamp and an **"Offline"** status badge.
- **Pending Writes Queue**: Actions created offline receive a local `pending` state and are **never** presented as server-confirmed until reconnect synchronization succeeds.
- **Reconnect Reconciliation**: On reconnect, queued writes are validated against updated server state before final commit. Any conflict triggers the Conflict Resolution UI.

---

## 8. Team Task Alignment & Sprint Matrix

### Role Responsibilities & Team Members
| Role | Assignee | Primary Focus Areas |
| :--- | :--- | :--- |
| **Team Lead & Infrastructure** | `jovabsabus130-alt` | Firebase setup, Clean Architecture, Security Rules, Offline Sync, PR Reviews |
| **Director Module Developer** | Team Member | Production CRUD, Audition creation, Role casting, Rehearsal scheduling & Conflict resolution UI |
| **Cast Module Developer** | Team Member | Audition browsing, Application submission, My Schedule, Offline schedule viewer |
| **Admin & Venue Developer** | Team Member | Venue catalog, User access management, Theatre-wide resource setup |

### Sprint Task Mapping (PRD Alignment)

| Task ID | Requirement | User Story | Task Description | Primary Assignee | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TASK-01** | FR-01 | US-A02 | Setup Firebase Auth, Role Claims & User Profile Datasource | Team Lead | Completed |
| **TASK-02** | FR-02 | US-D01 | Implement Production Creation, Listing & Details Screens | Director Dev | In Progress |
| **TASK-03** | FR-03, FR-04 | US-D02, US-D03 | Build Auditions Workflow, Role Definitions & Cast Assignment | Director Dev | In Progress |
| **TASK-04** | FR-05, FR-07 | US-D04, US-D05 | Develop Rehearsal Scheduler & Conflict Detection Logic | Director Dev | In Progress |
| **TASK-05** | FR-08 | US-D06 | Create Conflict Resolution Screen (Time/Venue/Participant adjustment) | Director Dev | Needs Review |
| **TASK-06** | FR-03, FR-09 | US-C01, US-C02 | Build Cast Audition Application & Personal Chronological Schedule | Cast Dev | In Progress |
| **TASK-07** | FR-10, FR-12 | US-C03, US-C04 | Implement Firestore Real-Time Streams & Local Cache Display | Cast Dev | Needs Review |
| **TASK-08** | FR-06, FR-17 | US-A01 | Implement Admin Venue Management & Availability Configuration | Admin Dev | In Progress |
| **TASK-09** | FR-13, FR-14 | US-C04 | Offline Pending Write Queue & Reconnect Reconciliation Service | Team Lead | In Progress |
| **TASK-10** | FR-15..18 | US-D01..A02 | Dashboard Widgets, Role Navigation Guards & Profile Screen | Team Lead | Completed |

---

## 9. Development & Git Workflow

```
main (Protected)
  ↑ (Stable Release PR only)
development (Shared Integration)
  ↑
feat/* | fix/* | docs/* | chore/* | refactor/*
```

### ⛔ Critical Rules
- **DO NOT push directly to `main`.**
- **DO NOT push directly to `development`.**
- All work must go through a **Pull Request**.
- Every PR must target `development` — never `main`.
- `main` is reserved for **stable, approved releases** only.

### Branch Strategy & Naming Conventions
All feature branches must be created **from `development`**:
- `feat/description` — New features (e.g., `feat/conflict-detection`)
- `fix/description` — Bug fixes (e.g., `fix/venue-overlap-query`)
- `docs/description` — Documentation (e.g., `docs/update-readme`)
- `chore/description` — Tooling & configuration (e.g., `chore/setup-firebase`)

```bash
git checkout development
git pull origin development
git checkout -b feat/your-feature-name
```

### Commit Convention (Conventional Commits)
Format: `<type>: <short description>`
- `feat`: Adding a new feature
- `fix`: Fixing a bug
- `docs`: Documentation updates
- `chore`: Configuration, setup, or tooling tasks
- `refactor`: Code restructuring without logic changes
- `test`: Adding or modifying test cases

*Example*: `feat: implement rehearsal conflict detection query`

### Pull Request Guidelines
- **Target Branch**: `development`
- **Required Reviewer**: `jovabsabus130-alt`
- Daily progress rule: Push daily updates to your branch; update the existing PR rather than creating duplicates.

---

## 10. Getting Started & Local Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19.0 or later recommended)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code with Flutter & Dart plugins
- [Firebase CLI](https://firebase.google.com/docs/cli) & FlutterFire CLI

### Quick Start
```bash
# 1. Clone the repository
git clone https://github.com/kalviumcommunity/SW2627-Flutter-Revo.git

# 2. Navigate to project directory
cd SW2627-Flutter-Revo

# 3. Fetch dependencies
flutter pub get

# 4. Run Flutter static analysis & tests
flutter analyze
flutter test

# 5. Run the application (Android Emulator / Device)
flutter run
```

---

*Last updated by `jovabsabus130-alt` — Team Lead, S130-Revo*
