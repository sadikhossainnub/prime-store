# 🏪 Amer Dokan — বাকি খাতা (Credit Ledger App)

A comprehensive offline-first Flutter mobile application for Bengali grocery stores (খাবারের দোকান) to manage customer credit ledgers, inventory, purchases, and sales.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-%2307405E.svg?style=for-the-badge&logo=SQLite&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%232A80B9.svg?style=for-the-badge&logo=dart&logoColor=white)

---

## ✨ Features

### 📊 Core Features
- **Customer Management** — Add, edit, delete customers with photo support and credit limits
- **Baki (Credit) Tracking** — Record daily credit transactions and track outstanding amounts
- **Payment Collection** — Record payments and automatically update customer balances
- **Dashboard** — Real-time statistics with 6 summary cards (total due, today's sales/purchases/collection, total profit, low stock count)
- **Top Defaulters** — Quick view of top 5 customers with highest outstanding amounts
- **Recent Transactions** — Timeline view of last 10 transactions (baki, payments, sales)

### 📦 Inventory Management
- **Product Catalog** — Manage products with categories, units, buy/sell prices
- **Stock Tracking** — Real-time stock levels with low-stock alerts
- **Stock Adjustments** — Manual stock corrections with audit trail

### 🛒 Purchase Management
- **Supplier Management** — Track suppliers and their due amounts
- **Purchase Orders** — Record purchases with automatic stock increment
- **Purchase History** — View all purchases with supplier details

### 💰 Sales Management
- **POS-Style Sales** — Quick sale entry with product cart
- **Multiple Sale Types** — Cash, Baki, or Partial payments
- **Automatic Baki Link** — Sales with baki automatically create credit transactions
- **Stock Decrement** — Automatic stock reduction on sale

### 📱 Communication
- **SMS Reminders** — Send Bengali SMS via native SMS app
- **WhatsApp Notifications** — Send messages via WhatsApp deep links
- **Bulk Reminders** — Select multiple customers to send reminders
- **Month-End Notifications** — Auto-scheduled reminders on 28th of each month

### 📈 Reports & Analytics
- **Monthly Reports** — Day-wise baki and collection charts
- **Sales Reports** — Day-wise sales and purchases charts
- **Customer Reports** — Customer-wise baki summary
- **Yearly Reports** — 12-month bar chart (baki vs collection vs sales)

### 🔐 Security & Settings
- **Google Sign-In** — Optional authentication with Google account
- **PIN Lock** — Biometric/PIN authentication for app access
- **Google Drive Backup** — Automatic and manual cloud backup/restore
- **Shop Settings** — Customize shop name, owner name, and message templates

### 📤 Export Features
- **PDF Export** — Generate customer statements and sales invoices
- **CSV Export** — Export transactions, sales, purchases to CSV

---

## 🎨 Design

Amer Dokan features a premium dark glassmorphism UI designed specifically for Bengali users:

- **Primary Color**: Emerald Green (`#00C853`) — representing business and money
- **Accent Color**: Golden Yellow (`#FFD700`) — for highlights
- **Background**: Deep Navy Gradient (`#0A0E21` → `#1A1A2E`)
- **Typography**: Google Fonts `Hind Siliguri` (Bengali) + `Poppins` (English/Numbers)
- **Cards**: Glassmorphism effect with blur, transparency, and gradient borders

---

## 📱 Navigation

The app uses a bottom navigation bar with 5 tabs:

1. **ড্যাশবোর্ড** — Dashboard with stats and quick actions
2. **কাস্টমার** — Customer management and baki tracking
3. **বিক্রয়** — Sales/POS management
4. **ইনভেন্টরি** — Product and stock management
5. **রিপোর্ট** — Reports and analytics

Settings are accessible via the drawer menu.

---

## 🗄️ Database Schema

The app uses SQLite with 4 versions of incremental migrations:

### Tables (v4)
- **customers** — Customer information with credit limits
- **transactions** — Baki (credit) entries
- **payments** — Payment collection records
- **products** — Product catalog with stock tracking
- **suppliers** — Supplier information
- **purchases** — Purchase orders
- **purchase_items** — Purchase line items
- **sales** — Sales records
- **sale_items** — Sales line items

### Key Features
- Foreign key constraints with cascade deletes
- Computed fields (total_baki, total_due)
- Stock movement tracking
- Automatic baki creation on sales

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter SDK ^3.11.1 |
| State Management | Provider |
| Database | SQLite (sqflite) |
| Authentication | Google Sign-In |
| Cloud Backup | Google Drive API |
| Charts | fl_chart ^1.2.0 |
| Fonts | Google Fonts |
| Notifications | flutter_local_notifications |
| Other | url_launcher, share_plus, image_picker, flutter_contacts, http |

---

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── customer.dart
│   ├── transaction.dart
│   ├── payment.dart
│   ├── product.dart
│   ├── supplier.dart
│   ├── purchase.dart
│   └── sale.dart
├── providers/                   # State management
│   ├── customer_provider.dart
│   ├── transaction_provider.dart
│   ├── dashboard_provider.dart
│   ├── inventory_provider.dart
│   ├── supplier_provider.dart
│   ├── purchase_provider.dart
│   └── sales_provider.dart
├── database/
│   └── database_helper.dart     # SQLite CRUD operations
├── screens/                     # UI screens
│   ├── auth/
│   ├── dashboard/
│   ├── customers/
│   ├── baki/
│   ├── payment/
│   ├── inventory/
│   ├── purchase/
│   ├── sales/
│   ├── suppliers/
│   ├── reports/
│   └── settings/
├── services/                    # Business logic
│   ├── sms_service.dart
│   ├── whatsapp_service.dart
│   ├── backup_service.dart
│   ├── notification_service.dart
│   ├── settings_service.dart
│   ├── message_templates.dart
│   └── update_checker.dart
├── theme/
│   └── app_theme.dart           # Dark theme & colors
└── widgets/
    └── glass_card.dart          # Glassmorphism widget
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ^3.11.1
- Dart SDK ^3.11.1
- Android Studio / VS Code with Flutter extensions
- Google account for backup (optional)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd "Baki khata"
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

4. **Build for Android**
   ```bash
   flutter build apk --release
   ```

### Default Login
- **Username**: `admin`
- **Password**: `123`

---

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.5+1
  sqflite: ^2.4.2+1
  path: ^1.9.1
  path_provider: ^2.1.5
  google_fonts: ^8.1.0
  fl_chart: ^1.2.0
  intl: ^0.20.2
  google_sign_in: ^6.2.2
  googleapis: ^13.2.0
  http: ^1.2.0
  share_plus: ^12.0.2
  shared_preferences: ^2.3.5
  url_launcher: ^6.3.0
  flutter_local_notifications: ^21.0.0
  timezone: ^0.11.0
  flutter_contacts: ^2.0.2
  image_picker: ^1.2.2
  flutter_svg: ^2.0.10+1
```

---

## 📝 Implementation Roadmap

### ✅ Completed
- Customer management with photo support
- Baki entry and payment collection
- Dashboard with stats
- Monthly & customer reports with charts
- SMS & WhatsApp reminders
- Google Drive backup/restore
- Local notifications (month-end reminder)
- Settings (shop info, backup, logout)
- Google Sign-In auth

### 🔄 In Progress
- Inventory management
- Purchase management
- Sales management

### 📋 Planned
- PDF export service
- CSV export service
- Credit limit enforcement
- PIN lock
- Yearly reports
- Top defaulters widget
- Enhanced navigation

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

- Designed specifically for Bengali grocery store owners
- Built with offline-first approach for areas with limited connectivity
- All communication in Bengali (with English support where needed)

---

## 📞 Support

For support, email amerdokan@example.com or open an issue on GitHub.

---

**Made with ❤️ for Bengali small business owners**
