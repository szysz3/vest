# Vest Backend

Python backend for the Vest iOS app.

## Run

```bash
docker compose up --build
```

The server starts on `http://localhost:8000`.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/transactions` | List all transactions |
| POST | `/transactions` | Create a transaction |
| GET | `/transactions/form-options` | Get form options (asset types, operators) |

API docs available at `http://localhost:8000/docs`.
