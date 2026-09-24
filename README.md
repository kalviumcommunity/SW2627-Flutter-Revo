# SW2627-Flutter-Revo

> A Flutter project developed by Team **S130-Revo** under the Kalvium Community organization.

---

## Project Overview

**SW2627-Flutter-Revo** is a Flutter-based mobile application built collaboratively by the S130-Revo team. The project follows a structured Git workflow to ensure clean collaboration, traceable history, and maintainable code.

---

## Team

| Role              | GitHub Username         |
|-------------------|-------------------------|
| Team Lead / Admin | `jovabsabus130-alt`     |

> Team members should update this table with their GitHub usernames.

---

## Development Workflow

```
main
  ↓
development
  ↓
individual feature / fix / docs / chore branch
  ↓
Pull Request → development
  ↓
Team Lead reviews & merges
  ↓
(periodic) development → main (stable releases only)
```

### ⛔ Critical Rules

- **DO NOT push directly to `main`.**
- **DO NOT push directly to `development`.**
- All work must go through a **Pull Request**.
- Every PR targets `development` — never `main`.
- `main` is reserved for **stable, approved releases** only.

---

## Branch Strategy

| Branch        | Purpose                                          |
|---------------|--------------------------------------------------|
| `main`        | Stable, production-ready code. Protected.        |
| `development` | Shared integration branch. All PRs target here.  |
| `feat/*`      | New features                                     |
| `fix/*`       | Bug fixes                                        |
| `docs/*`      | Documentation updates                            |
| `chore/*`     | Tooling, config, setup tasks                     |
| `refactor/*`  | Code refactoring without feature changes         |

---

## Branch Naming Convention

All branches must be created **from `development`**, never from `main`.

### Format

```
<type>/<short-description>
```

### Examples

```
feat/login
feat/farmer-dashboard
fix/otp-validation
docs/update-readme
chore/setup-project
refactor/auth-service
```

### How to create a branch

```bash
git checkout development
git pull origin development
git checkout -b feat/your-feature-name
```

---

## Commit Convention

This project follows **Conventional Commits** for consistent, readable history.

### Format

```
<type>: <short description>
```

### Types

| Type       | When to use                              |
|------------|------------------------------------------|
| `feat`     | Adding a new feature                     |
| `fix`      | Fixing a bug                             |
| `docs`     | Documentation changes only               |
| `chore`    | Build process, tooling, config changes   |
| `refactor` | Code change that neither fixes nor adds  |
| `style`    | Formatting, missing semicolons, etc.     |
| `test`     | Adding or updating tests                 |

### Examples

```
feat: add login screen
fix: resolve OTP validation issue
docs: update README with workflow
chore: configure project structure
refactor: improve authentication service
```

### Commit commands

```bash
git add .
git commit -m "feat: add login screen"
git push origin feat/login
```

---

## Pull Request Rules

### Target branch

```
feature branch → development    ✅
feature branch → main           ❌ NOT ALLOWED
```

### Required reviewer

Every PR **must** request a review from:

```
jovabsabus130-alt
```

### PR Description Template

Use this template for every Pull Request:

```markdown
## Status
In Progress / Completed / Needs Review

## What changed
- ...

## What remains
- ...

## Action required
- Review the implementation
- Test the feature
- Approve / request changes

## How to test
1. ...
2. ...
3. ...

## Related Issue
Closes #...
```

---

## Daily Progress Rule

> **Every working day with meaningful progress = push your branch + update your PR.**

- Developers are expected to raise a PR to `development` **daily** when there is meaningful progress.
- Even partial or incomplete work can be submitted.
- **Do NOT create a new PR for each small update.** Push new commits to the same branch — the existing PR updates automatically.
- Update the PR comment/description to reflect the current status.

---

## PR Status

Use one of the following statuses in your PR description and comments:

| Status           | Meaning                                             |
|------------------|-----------------------------------------------------|
| `In Progress`    | Work is actively ongoing, not ready for full review |
| `Completed`      | Work is finished and ready for review/merge         |
| `Needs Review`   | Awaiting reviewer feedback                          |
| `Changes Needed` | Reviewer requested changes; developer must update   |

---

## PR Comment Examples

### When In Progress

```
Status: In Progress

Completed:
- Login UI
- Form validation
- API integration

Remaining:
- Error handling
- Final testing

Action required:
Please review the current implementation and check the API integration.
```

### When Completed

```
Status: Completed

Completed:
- Login UI
- Form validation
- API integration
- Error handling

Action required:
Please perform final review and testing, then approve for merge.
```

---

## Review Process

```
Developer
   ↓
Feature branch (feat/*, fix/*, docs/*, etc.)
   ↓
Push to GitHub
   ↓
Open PR → development
   ↓
Request review from: jovabsabus130-alt
   ↓
Review by Team Lead
   ↓
Changes requested  OR  Approved
   ↓
(if changes requested) Developer updates SAME branch/PR
   ↓
Team Lead merges → development
```

> **Do NOT open a new PR** just because the reviewer requested changes. Always update the same branch and PR.

---

## Main Branch Protection

The `main` branch is **protected**:

- ❌ Direct pushes are **blocked**.
- ✅ Merges are only allowed via **Pull Request**.
- ✅ At least **one approval** is required before merging.
- ✅ Only the Team Lead (`jovabsabus130-alt`) manages merges to `main`.
- `main` is updated only when `development` reaches a stable, approved state.

---

## Issue Tracking

- Use **GitHub Issues** to track bugs, features, and tasks.
- Reference issues in your PR with `Closes #<issue-number>`.
- Keep issues updated with progress notes.

---

## How to Run the Project

> _(Update this section once the Flutter project is initialized.)_

### Prerequisites

- Flutter SDK installed
- Dart SDK
- Android Studio / VS Code with Flutter plugin

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/kalviumcommunity/SW2627-Flutter-Revo.git

# 2. Enter the project directory
cd SW2627-Flutter-Revo

# 3. Get dependencies
flutter pub get

# 4. Run the app
flutter run
```

---

*Last updated by `jovabsabus130-alt` — Team Lead, S130-Revo*
