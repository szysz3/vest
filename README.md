# Vest

Portfolio management app for iOS with a Python backend.

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
