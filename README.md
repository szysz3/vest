# <img width="48" height="48" alt="vest_icon" src="https://github.com/user-attachments/assets/fb16bf6e-2773-421d-a130-e159b07f11c5" /> vest

A privacy-focused, multi-partner portfolio management platform featuring a local **Python Web Portal** for parsing brokerage statements and a **read-only iOS app** for tracking combined family/partner assets.

<p align="center">
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 28 11" src="https://github.com/user-attachments/assets/1c951c53-ebe7-4a2e-992d-b90ce068f3ae" />
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 28 38" src="https://github.com/user-attachments/assets/6192eceb-033b-4fc9-bbac-e8b8a390c19b" />
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 29 04" src="https://github.com/user-attachments/assets/22f5ec7e-2c94-42d3-8667-2f62672962a5" />
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 29 55" src="https://github.com/user-attachments/assets/d5b8200e-85f8-46cf-9501-671f57a2dd46" />
</p>

---

## System Overview

Vest automates portfolio aggregation across partners saving money on separate brokerage accounts. Instead of manual data entry, partners upload official brokerage statements to a locally hosted Web Portal. The system parses, normalizes, and aggregates holdings while enforcing monthly sync compliance.

```
┌─────────────────────────────────────────────────────────────┐
│                    Local Web Portal UI                      │
│      Upload Bonds (.xls) & Equities (.zip / .xlsx) Reports  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Backend Server                    │
│   • Statement Parsers (Bonds & Stocks/ETFs)                 │
│   • Live NBP FX Rate Converter (EUR/USD -> PLN)             │
│   • Monthly 30-Day Staleness Enforcement                    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Read-Only iOS Mobile App                    │
│   • Portfolio Hero Pie Chart & Asset Allocation             │
│   • Multi-Partner Sync Compliance Status Banner             │
│   • Position Breakdown with Profit Badges & Dual Currency   │
└─────────────────────────────────────────────────────────────┘
```

---

## Features

- **Multi-Partner Statement Tracking**: Configurable slots per partner (e.g., Partner 1 tracks Broker A + Broker B; Partner 2 tracks Broker B).
- **Pluggable Statement Parsers**:
  - **Bonds Broker**: Extracts bond asset codes (e.g., `BOND01`, `BOND02`), nominal values, current values, and accrued interest.
  - **Equities Broker**: Parses open positions (`.xlsx`, `.xls`, or `.zip` archives containing nested folders), ticker symbols (e.g., `ETF01`), Net Profit, and Profit %.
- **Live FX Currency Conversion**: Integrates live exchange rate API from Narodowy Bank Polski (NBP) to denominate foreign holdings into PLN.
- **30-Day Monthly Staleness Enforcement**: Rejects outdated reports (> 30 days old) and flags expired slots on both portal and mobile app.
- **Strictly Read-Only Mobile App**: Mobile UI focuses on clean tracking, removing manual transaction sheets and display clutter.
- **Dual-Currency Display**: Positions highlight original document currency (e.g., `EUR`, `USD`) as primary values with secondary PLN conversions.

---

## Architecture

The project follows **Clean Architecture** with a modular structure:

```
vest/
├── vest_mobile/          # iOS app (SwiftUI)
│   ├── App/              # Entry point & configuration
│   └── Modules/          # SPM packages
│       ├── Domain/       # Business logic, use cases, models
│       ├── Data/         # Repository implementations, API client
│       ├── Core/         # DI container (Factory), view state
│       └── Presentation/ # UI screens, view models, design system
└── vest_backend/         # Python API & Web Portal (FastAPI)
    ├── parsers/          # Statement parsers
    ├── templates/        # Glassmorphic Web Portal HTML/CSS/JS
    └── config.json       # Users & expected statement slot definitions
```

---

## Tech Stack

- **Mobile:** Swift 6.0, SwiftUI, iOS 18+, XcodeGen, Swift Package Manager, Factory (DI)
- **Backend:** Python 3.12, FastAPI, SQLite, Docker, Pandas, OpenPyXL, XLRD

---

## Setup & Quickstart

### 1. Backend Server & Web Portal

```bash
cd vest_backend
docker compose up --build -d
```

- **Web Portal**: Open [http://localhost:8002](http://localhost:8002) in your browser to drag-and-drop brokerage statements.
- **API Docs**: Interactive Swagger documentation available at [http://localhost:8002/docs](http://localhost:8002/docs).

### 2. Mobile App

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen)
2. Configure the API endpoint:
   ```bash
   cd vest_mobile
   cp App/Resources/Config.json.example App/Resources/Config.json
   # Verify BaseURL points to "http://127.0.0.1:8002"
   ```
3. Generate the Xcode project and open it:
   ```bash
   xcodegen generate
   open vest.xcodeproj
   ```
4. Build and run on an iOS Simulator or device (iOS 18+).

---

## API Reference

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Web Portal Dashboard UI |
| `GET` | `/portal/status` | Get statement upload compliance status per partner |
| `POST` | `/portal/upload` | Upload and parse brokerage statement file (`.xls`, `.xlsx`, `.zip`) |
| `GET` | `/portfolio/details` | Get aggregated portfolio holdings with original currency & PLN amounts |
| `GET` | `/statements/status` | Get mobile sync compliance status & missing/stale slot warnings |
| `GET` | `/transactions` | List parsed transaction history |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
