# <img width="48" height="48" alt="vest_icon" src="https://github.com/user-attachments/assets/fb16bf6e-2773-421d-a130-e159b07f11c5" /> vest

Vibe coded portfolio management app for iOS with a Python backend.
<p align="center">
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 28 11" src="https://github.com/user-attachments/assets/1c951c53-ebe7-4a2e-992d-b90ce068f3ae" />
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 28 38" src="https://github.com/user-attachments/assets/6192eceb-033b-4fc9-bbac-e8b8a390c19b" />
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 29 04" src="https://github.com/user-attachments/assets/22f5ec7e-2c94-42d3-8667-2f62672962a5" />
   <img width="20%" alt="Simulator Screenshot - iPhone 17 - 2026-02-05 at 17 29 55" src="https://github.com/user-attachments/assets/d5b8200e-85f8-46cf-9501-671f57a2dd46" />
</p>

## Architecture

The project follows **Clean Architecture** with a modular structure:

```
vest/
├── vest_mobile/          # iOS app (SwiftUI)
│   ├── App/              # Entry point & resources
│   └── Modules/          # SPM packages
│       ├── Domain/       # Business logic, use cases, models
│       ├── Data/         # Repository implementations, API client
│       ├── Core/         # DI container, view state
│       └── Presentation/ # UI screens, view models, design system
└── vest_backend/         # Python API (FastAPI)
```

## Tech Stack

**Mobile:** Swift 6.0, SwiftUI, iOS 18+, XcodeGen, Swift Package Manager, Factory (DI)

**Backend:** Python 3.12, FastAPI, SQLite, Docker

## Setup

### Backend

```bash
cd vest_backend
cp .env.example .env    # edit as needed
docker compose up --build
```

The API starts on `http://localhost:8002` with docs at `/docs`.

### Mobile

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen)
2. Configure the API endpoint:
   ```bash
   cd vest_mobile
   cp App/Resources/Config.json.example App/Resources/Config.json
   # edit Config.json with your backend URL
   ```
3. Generate the Xcode project and open it:
   ```bash
   xcodegen generate
   open vest.xcodeproj
   ```
4. Build and run on a simulator or device (iOS 18+)

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/transactions` | List all transactions |
| POST | `/transactions` | Create a transaction |
| POST | `/transactions/batch` | Create multiple transactions |
| GET | `/transactions/form-options` | Get form options (asset types, operators) |
| GET | `/portfolio/details` | Get aggregated portfolio holdings |

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
