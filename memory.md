# Amer Dokan — Project Memory

## Overview
Flutter offline-first credit ledger (বাকি খাতা) app for Bengali grocery stores. Tracks customer credit, payments, and sends SMS/WhatsApp reminders.

## Tech Stack
- **Framework**: Flutter (Dart, SDK ^3.11.1)
- **State Management**: Provider
- **Database**: SQLite (sqflite)
- **Auth**: Google Sign-In
- **Backup**: Google Drive API (googleapis)
- **Notifications**: flutter_local_notifications + timezone
- **Charts**: fl_chart
- **Fonts**: Google Fonts (Hind Siliguri + Poppins)
- **Other**: url_launcher, share_plus, image_picker, flutter_contacts, http

## Architecture

### Data Models (`lib/models/`)
- `Customer` — id, name, phone, address?, photoPath?, createdAt, totalBaki (computed)
- `BakiTransaction` — id, customerId, amount, description?, date, createdAt
- `Payment` — id, customerId, amount, note?, date, createdAt

### Database (`lib/database/database_helper.dart`)
- Singleton `DatabaseHelper` with lazy initialization
- 3 tables: `customers`, `transactions`, `payments`
- `total_baki` computed via subquery: `SUM(transactions.amount) - SUM(payments.amount)`
- Cascade deletes on foreign keys
- Dashboard stats via raw SQL with date-based filtering

### Providers (`lib/providers/`)
- `CustomerProvider`, `TransactionProvider`, `DashboardProvider` — all ChangeNotifiers

### Services (`lib/services/`)
- `SmsService` — deep link to native SMS app
- `WhatsappService` — deep link to WhatsApp
- `BackupService` — Google Drive backup/restore
- `NotificationService` — month-end reminder scheduling
- `SettingsService` — SharedPreferences wrapper
- `MessageTemplates` — Bengali message templates
- `UpdateChecker` — app update checks

### Theme (`lib/theme/app_theme.dart`)
- Dark theme: deep navy (`#0A0E21` → `#1A1A2E`), emerald primary (`#00C853`), gold accent (`#FFD700`)
- Glassmorphism card style via `GlassCard` widget

## Conventions
- **State**: Provider pattern (not Riverpod/Bloc)
- **Database**: Raw SQL queries (not ORM)
- **Backup**: Google Drive integration for cloud backup
- **Auth**: Google Sign-In (optional, based on shared_prefs flag)
- **Dates**: ISO 8601 strings in DB, Bengali locale (`bn_BD`) for display via `intl`
- **Constants**: Import `AppTheme` for colors, padding, and text styles
- **Widgets**: Reusable widgets in `lib/widgets/`, screen-specific in `lib/screens/`

## Current State
- Implemented: Database helper, models, theme, main entry point, GlassCard widget
- Not yet implemented: Most screens, providers logic, services, charts

## Build & Run
```bash
flutter pub get
flutter run
```
