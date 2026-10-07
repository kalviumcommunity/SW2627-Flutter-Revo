# Director Interview Summary & PRD Baseline Evidence Document

> **Document Version**: 1.0  
> **Author**: Jovab Sabu (`jovabsabus130-alt`) — Team Lead, S130-Revo  
> **Target Audience**: Stakeholders, Project Evaluators, Engineering Team  
> **Linked Requirements**: FR-01, FR-03, FR-04, FR-07, BR-01..BR-06  

---

## 1. Executive Summary & Purpose

This document serves as the **authoritative PRD Baseline Evidence** compiled from structural interviews with primary theatre directors. It captures empirical requirements, baseline operational pain points, and target Key Performance Indicators (KPIs) to evaluate the **Revo Theatre Production Management System**.

---

## 2. Stakeholder Profile & Persona

| Field | Details |
| :--- | :--- |
| **Persona** | Director Sarah Jenkins (Primary User Persona) |
| **Organization** | Regional Community Theatre Group |
| **Scale** | 3–5 simultaneous active productions; 40+ cast & crew members |
| **Key Responsibility** | Production creation, audition setup, role definitions, cast assignments, rehearsal scheduling, venue booking, and conflict resolution |

---

## 3. Core Baseline Operational Pain Points

1. **Unmanageable Messaging Group Chats**: Coordination via multi-group chats leads to missed schedule updates, outdated rehearsal timings, and communication lag ($\ge 48$ hours).
2. **Venue Double-Bookings**: Multiple production teams frequently attempt to reserve the same rehearsal space without centralized real-time awareness.
3. **Cast Schedule Overlaps**: Actors cast across multiple productions face overlapping rehearsal commitments with zero automated pre-confirmation validation.
4. **Manual Role & Audition Tracking**: Directors track auditions and role assignments in manual spreadsheets, causing status misalignments and unnotified cast applicants.

---

## 4. Key Performance Indicators & Target Impact Framework

| Impact Area | Baseline Pre-Revo Metric | Target Post-Revo KPI | Verification Mechanism |
| :--- | :--- | :--- | :--- |
| **Weekly Schedule Search Time** | ~4.5 hours / week per director | **$\ge 30\%$ Reduction** | In-app schedule dashboard with role filters |
| **Delayed Schedule Communications** | ~35% delayed updates | **$\ge 50\%$ Reduction** | Live Firestore streams & instant push notifications |
| **Venue Double-Bookings** | ~3 confirmed conflicts / month | **0 Confirmed Conflicts** | Automated pre-confirmation conflict engine (FR-07) |
| **Cast Rehearsal Overlaps** | ~5 actor overlaps / month | **0 Overlaps** | Real-time participant schedule validation (BR-05) |
| **Audition-to-Cast Assignment Traceability** | Disconnected spreadsheets | **100% Traceability** | Automated Application status lifecycle & Role status sync (BR-06) |

---

## 5. Requirement Verification & Alignment Matrix

### FR-01: Firebase Authentication & Role-Based Access Control
- **User Roles**: Director, Cast Member, Theatre Admin.
- **Access Guard**: Client-side router navigation guards restrict non-authorized users from accessing elevated features (e.g. Cast Members cannot create auditions or assign roles).

### FR-03: Audition & Application Workflow
- Directors create auditions linked to specific Productions specifying venue, start/end time, and available roles.
- Cast Members browse open auditions, apply for available roles, and track application lifecycle statuses (`submitted`, `shortlisted`, `selected`, `rejected`, `withdrawn`).

### FR-04 & BR-06: Role Definitions & Cast Assignment Logic
- Directors define Production Roles with initial status `open`.
- **BR-06 Rules**:
  - Assigning a Cast Member transitions role status from `open` to `assigned`.
  - Revo prevents duplicate active assignments of the same user to the same role.
  - Removing a cast assignment automatically reverts role status to `open`.
  - Cast assignments are logged with timestamped confirmation.

---

*Verified & Approved by Team Lead jovabsabus130-alt — Revo Systems*
