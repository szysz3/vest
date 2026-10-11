import json
import os
import re
import sqlite3
import urllib.request
import uuid
from contextlib import asynccontextmanager, contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional, Tuple

from fastapi import APIRouter, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from parsers import BondsParser, EquitiesParser

DB_PATH = Path(os.environ.get("DB_PATH", Path(__file__).parent / "vest.db"))
CONFIG_PATH = Path(os.environ.get("CONFIG_PATH", Path(__file__).parent / "config.json"))

MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024  # 25 MB max upload limit

ASSET_TYPES = ["bond", "etf", "stock", "crypto", "gold", "cash"]

DEFAULT_OPERATORS = [
    {"id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "vest.operator.broker_a")), "name": "Broker A"},
    {"id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "vest.operator.broker_b")), "name": "Broker B"},
]

FX_RATE_CACHE = {}
GOLD_PRICE_CACHE = {}
TROY_OUNCE_IN_GRAMS = 31.1034768


def get_configured_operators() -> List[dict]:
    config = load_config()
    operators = []
    seen = set()
    for user in config.get("users", []):
        for slot in user.get("expected_statements", []):
            b_type = slot.get("broker", "").lower()
            if b_type and b_type not in seen:
                seen.add(b_type)
                b_name = slot.get("broker_name", slot.get("name", b_type.replace("_", " ").title()))
                op_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"vest.operator.{b_type}"))
                operators.append({"id": op_id, "name": b_name})
    return operators or DEFAULT_OPERATORS


def get_fx_rate(currency: str) -> float:
    curr = (currency or "PLN").strip().upper()
    if curr == "PLN":
        return 1.0

    if curr in FX_RATE_CACHE:
        return FX_RATE_CACHE[curr]

    url = f"http://api.nbp.pl/api/exchangerates/rates/a/{curr.lower()}/?format=json"
    req = urllib.request.Request(url, headers={"User-Agent": "VestBackend/1.0", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            rates = data.get("rates", [])
            if rates:
                mid_rate = float(rates[0].get("mid", 0.0))
                if mid_rate > 0:
                    FX_RATE_CACHE[curr] = mid_rate
                    return mid_rate
    except Exception as e:
        print(f"Warning: Failed to fetch live NBP FX rate for {curr}: {e}")

    fallbacks = {"EUR": 4.30, "USD": 3.75, "GBP": 5.00, "CHF": 4.50}
    rate = fallbacks.get(curr, 1.0)
    FX_RATE_CACHE[curr] = rate
    return rate


def get_gold_price(currency: str = "PLN") -> Tuple[float, float, str]:
    """
    Returns (price_per_oz, price_per_g, date_str) in the requested currency.
    Uses official NBP API (http://api.nbp.pl/api/cenyzlota/?format=json) which publishes
    the gold price per 1 gram of pure gold in PLN.
    Converts 1 troy oz = 31.1034768 g, then applies FX rate for other currencies.
    Caches results per calendar date and currency to save API calls.
    """
    curr = (currency or "PLN").strip().upper()
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    cache_key = f"{today_str}:{curr}"
    if cache_key in GOLD_PRICE_CACHE:
        return GOLD_PRICE_CACHE[cache_key]

    base_cache_key = f"{today_str}:PLN"
    price_g_pln = None
    date_str = today_str

    if base_cache_key in GOLD_PRICE_CACHE:
        _, price_g_pln, date_str = GOLD_PRICE_CACHE[base_cache_key]
    else:
        url = "http://api.nbp.pl/api/cenyzlota/?format=json"
        req = urllib.request.Request(url, headers={"User-Agent": "VestBackend/1.0", "Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data and isinstance(data, list) and len(data) > 0:
                    price_g_pln = float(data[0].get("cena", 0.0))
                    date_str = str(data[0].get("data", today_str))
                    if price_g_pln > 0:
                        GOLD_PRICE_CACHE[base_cache_key] = (
                            round(price_g_pln * TROY_OUNCE_IN_GRAMS, 2),
                            round(price_g_pln, 2),
                            date_str,
                        )
        except Exception as e:
            print(f"Warning: Failed to fetch live NBP gold price: {e}")

    # Fallback if NBP is unreachable: ~520.0 PLN/g
    if not price_g_pln or price_g_pln <= 0:
        price_g_pln = 520.0
        date_str = today_str

    price_oz_pln = price_g_pln * TROY_OUNCE_IN_GRAMS

    if curr == "PLN":
        res = (round(price_oz_pln, 2), round(price_g_pln, 2), date_str)
        GOLD_PRICE_CACHE[cache_key] = res
        return res

    fx_rate = get_fx_rate(curr)
    price_oz_curr = price_oz_pln / fx_rate if fx_rate > 0 else price_oz_pln
    price_g_curr = price_g_pln / fx_rate if fx_rate > 0 else price_g_pln

    res = (round(price_oz_curr, 2), round(price_g_curr, 2), date_str)
    GOLD_PRICE_CACHE[cache_key] = res
    return res


def is_statement_stale(stmt_date_str: str, threshold_days: int = 30) -> Tuple[bool, int]:
    """Returns (is_stale, age_in_days). Statement is stale if age > threshold_days (30 days)."""
    try:
        stmt_date = datetime.strptime(stmt_date_str[:10], "%Y-%m-%d").date()
        today = datetime.now(timezone.utc).date()
        age_days = (today - stmt_date).days
        return age_days > threshold_days, age_days
    except Exception:
        return True, 999


class AssetDetailResponse(BaseModel):
    assetType: str
    details: str
    currency: str
    nominalAmount: float
    totalAmount: float
    profitOrLoss: float
    profitOrLossPct: float
    nominalAmountPLN: float
    totalAmountPLN: float
    profitOrLossPLN: float
    accountNumber: Optional[str] = None
    id: Optional[str] = None
    weightOz: Optional[float] = None


class FixedAssetCreate(BaseModel):
    assetType: str
    details: str
    amount: float = 0.0
    currency: str = "PLN"
    weightOz: Optional[float] = None


class FixedAssetUpdate(BaseModel):
    details: Optional[str] = None
    amount: Optional[float] = None
    currency: Optional[str] = None
    weightOz: Optional[float] = None


class FixedAssetResponse(BaseModel):
    id: str
    assetType: str
    details: str
    amount: float
    currency: str
    amountPLN: float
    weightOz: Optional[float] = None
    createdAt: str
    updatedAt: str


class GoldPriceResponse(BaseModel):
    date: str
    currency: str
    pricePerGram: float
    pricePerOz: float



class StatementSyncStatusResponse(BaseModel):
    allUploaded: bool
    uploadedCount: int
    totalCount: int
    lastSyncDate: Optional[str]
    missingSlots: List[str]


class PortfolioHistorySummary(BaseModel):
    currentTotal: float
    startingTotal: float
    totalSaved: float
    totalGrowthPct: float
    monthlyAverageSaved: float
    yearlyAverageSaved: float
    currentMonthSaved: float
    currentYearSaved: float


class PortfolioSnapshotPoint(BaseModel):
    id: str
    date: str
    totalAmount: float
    nominalAmount: float
    amountSaved: float


class MonthlySavingItem(BaseModel):
    id: str
    year: int
    month: int
    label: str
    shortLabel: str
    amount: float


class YearlySavingItem(BaseModel):
    id: str
    year: int
    label: str
    amount: float


class PortfolioHistoryResponse(BaseModel):
    summary: PortfolioHistorySummary
    snapshots: List[PortfolioSnapshotPoint]
    monthlySavings: List[MonthlySavingItem]
    yearlySavings: List[YearlySavingItem]


def load_config() -> dict:
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"users": [], "staleness_threshold_days": 30}


@contextmanager
def get_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                amount REAL NOT NULL,
                name TEXT NOT NULL,
                action TEXT NOT NULL,
                asset_type TEXT NOT NULL,
                place TEXT NOT NULL,
                date TEXT NOT NULL,
                details TEXT NOT NULL DEFAULT '',
                profit_or_loss REAL,
                account_number TEXT NOT NULL DEFAULT '',
                currency TEXT NOT NULL DEFAULT 'PLN'
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS operators (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS statement_uploads (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                slot_id TEXT NOT NULL,
                broker TEXT NOT NULL,
                filename TEXT NOT NULL,
                uploaded_at TEXT NOT NULL,
                statement_date TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'active'
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS parsed_holdings (
                id TEXT PRIMARY KEY,
                upload_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                asset_type TEXT NOT NULL,
                details TEXT NOT NULL,
                name TEXT NOT NULL,
                amount REAL NOT NULL,
                nominal_amount REAL NOT NULL DEFAULT 0.0,
                profit_or_loss REAL NOT NULL DEFAULT 0.0,
                profit_or_loss_pct REAL NOT NULL DEFAULT 0.0,
                currency TEXT NOT NULL DEFAULT 'PLN',
                quantity REAL NOT NULL DEFAULT 0.0,
                amount_pln REAL NOT NULL,
                nominal_amount_pln REAL NOT NULL DEFAULT 0.0,
                profit_or_loss_pln REAL NOT NULL DEFAULT 0.0,
                fx_rate REAL NOT NULL DEFAULT 1.0,
                account_number TEXT NOT NULL DEFAULT ''
            )
        """)

        # Migration checks
        cursor = conn.execute("PRAGMA table_info(parsed_holdings)")
        cols = [row["name"] for row in cursor.fetchall()]
        if "nominal_amount" not in cols:
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN nominal_amount REAL NOT NULL DEFAULT 0.0")
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN profit_or_loss REAL NOT NULL DEFAULT 0.0")
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN profit_or_loss_pct REAL NOT NULL DEFAULT 0.0")
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN nominal_amount_pln REAL NOT NULL DEFAULT 0.0")
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN profit_or_loss_pln REAL NOT NULL DEFAULT 0.0")
        if "fx_rate" not in cols:
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN fx_rate REAL NOT NULL DEFAULT 1.0")
        if "account_number" not in cols:
            conn.execute("ALTER TABLE parsed_holdings ADD COLUMN account_number TEXT NOT NULL DEFAULT ''")

        cursor = conn.execute("PRAGMA table_info(transactions)")
        cols = [row["name"] for row in cursor.fetchall()]
        if "account_number" not in cols:
            conn.execute("ALTER TABLE transactions ADD COLUMN account_number TEXT NOT NULL DEFAULT ''")
        if "currency" not in cols:
            conn.execute("ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'PLN'")

        # Seed operators
        cursor = conn.execute("SELECT COUNT(*) FROM operators")
        if cursor.fetchone()[0] == 0:
            for op in get_configured_operators():
                conn.execute(
                    "INSERT INTO operators (id, name) VALUES (?, ?)",
                    (op["id"], op["name"]),
                )

        conn.execute("""
            CREATE TABLE IF NOT EXISTS fixed_assets (
                id TEXT PRIMARY KEY,
                asset_type TEXT NOT NULL,
                details TEXT NOT NULL,
                amount REAL NOT NULL,
                currency TEXT NOT NULL DEFAULT 'PLN',
                weight_oz REAL DEFAULT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)

        cursor = conn.execute("PRAGMA table_info(fixed_assets)")
        fixed_cols = [row["name"] for row in cursor.fetchall()]
        if "weight_oz" not in fixed_cols:
            conn.execute("ALTER TABLE fixed_assets ADD COLUMN weight_oz REAL DEFAULT NULL")

        conn.execute("""
            CREATE TABLE IF NOT EXISTS portfolio_snapshots (
                id TEXT PRIMARY KEY,
                snapshot_date TEXT NOT NULL,
                total_amount_pln REAL NOT NULL,
                nominal_amount_pln REAL NOT NULL,
                profit_or_loss_pln REAL NOT NULL,
                amount_saved_pln REAL NOT NULL DEFAULT 0.0,
                breakdown_json TEXT DEFAULT '{}',
                created_at TEXT NOT NULL
            )
        """)

        conn.commit()


def calculate_current_portfolio_valuation(conn) -> Tuple[float, float, float]:
    """Returns (total_amount_pln, total_nominal_pln, total_profit_pln)."""
    rows = conn.execute("""
        SELECT SUM(h.nominal_amount_pln) as total_nominal_pln,
               SUM(h.amount_pln) as total_amount_pln,
               SUM(h.profit_or_loss_pln) as total_profit_pln
        FROM parsed_holdings h
        JOIN statement_uploads u ON h.upload_id = u.id
        WHERE u.status = 'active'
    """).fetchone()

    total_nominal = round(rows["total_nominal_pln"] or 0.0, 2)
    total_amount = round(rows["total_amount_pln"] or 0.0, 2)
    total_profit = round(rows["total_profit_pln"] or 0.0, 2)

    fixed_rows = conn.execute("""
        SELECT id, asset_type, details, amount, currency, weight_oz
        FROM fixed_assets
    """).fetchall()

    for f_row in fixed_rows:
        curr = (f_row["currency"] or "PLN").strip().upper()
        fx = get_fx_rate(curr)
        f_type = (f_row["asset_type"] or "").lower().strip()
        weight_oz = f_row["weight_oz"] if "weight_oz" in f_row.keys() else None

        if f_type == "gold" and weight_oz is not None and weight_oz > 0:
            spot_oz, _, _ = get_gold_price(curr)
            tot = round(weight_oz * spot_oz, 2)
            cost_basis = round(f_row["amount"] or 0.0, 2)
            nom = cost_basis if cost_basis > 0 else tot
            prof = round(tot - nom, 2)
            total_nominal += round(nom * fx, 2)
            total_amount += round(tot * fx, 2)
            total_profit += round(prof * fx, 2)
        else:
            tot = round(f_row["amount"] or 0.0, 2)
            tot_pln = round(tot * fx, 2)
            total_nominal += tot_pln
            total_amount += tot_pln

    return round(total_amount, 2), round(total_nominal, 2), round(total_profit, 2)


def record_portfolio_snapshot(conn, snapshot_date: Optional[str] = None):
    now_iso = datetime.now(timezone.utc).isoformat()
    if not snapshot_date:
        snapshot_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    elif len(snapshot_date) == 7:
        snapshot_date = f"{snapshot_date}-01"

    total_amount, total_nominal, total_profit = calculate_current_portfolio_valuation(conn)

    prev = conn.execute("""
        SELECT nominal_amount_pln FROM portfolio_snapshots
        WHERE snapshot_date < ?
        ORDER BY snapshot_date DESC LIMIT 1
    """, (snapshot_date,)).fetchone()

    amount_saved = 0.0
    if prev and prev["nominal_amount_pln"] is not None:
        amount_saved = max(0.0, round(total_nominal - float(prev["nominal_amount_pln"]), 2))

    existing = conn.execute("SELECT id FROM portfolio_snapshots WHERE snapshot_date = ?", (snapshot_date,)).fetchone()
    if existing:
        conn.execute("""
            UPDATE portfolio_snapshots
            SET total_amount_pln = ?, nominal_amount_pln = ?, profit_or_loss_pln = ?, amount_saved_pln = ?, created_at = ?
            WHERE id = ?
        """, (total_amount, total_nominal, total_profit, amount_saved, now_iso, existing["id"]))
    else:
        conn.execute("""
            INSERT INTO portfolio_snapshots (id, snapshot_date, total_amount_pln, nominal_amount_pln, profit_or_loss_pln, amount_saved_pln, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (str(uuid.uuid4()), snapshot_date, total_amount, total_nominal, total_profit, amount_saved, now_iso))


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="Vest Backend", lifespan=lifespan)

STATIC_DIR = Path(__file__).parent / "static"
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# Allow local LAN clients & mobile apps to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_router = APIRouter(prefix="/api")


@app.get("/favicon.ico", include_in_schema=False)
@app.get("/favicon.png", include_in_schema=False)
@app.get("/apple-touch-icon.png", include_in_schema=False)
@app.get("/favicon-32x32.png", include_in_schema=False)
@app.get("/favicon-64x64.png", include_in_schema=False)
@app.get("/favicon-512x512.png", include_in_schema=False)
async def get_favicon_png():
    icon_path = STATIC_DIR / "favicon_app.png"
    if not icon_path.exists():
        icon_path = STATIC_DIR / "vest_icon.png"
    if icon_path.exists():
        return FileResponse(icon_path, media_type="image/png")
    raise HTTPException(status_code=404, detail="Favicon missing")


@app.get("/", response_class=HTMLResponse)
async def get_portal_ui():
    template_path = Path(__file__).parent / "templates" / "index.html"
    if not template_path.exists():
        raise HTTPException(status_code=404, detail="Portal template missing")
    with open(template_path, "r", encoding="utf-8") as f:
        content = f.read()
    return HTMLResponse(
        content=content,
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
        },
    )


@app.get("/portal/status")
@api_router.get("/portal/status")
async def get_portal_status():
    config = load_config()
    users_config = config.get("users", [])
    threshold_days = config.get("staleness_threshold_days", 30)

    total_slots = 0
    uploaded_slots = 0
    result_users = []

    with get_db() as conn:
        for user in users_config:
            user_id = user["id"]
            user_name = user["name"]
            slots = user.get("expected_statements", [])

            user_slot_data = []
            for slot in slots:
                total_slots += 1
                slot_id = slot["slot_id"]

                row = conn.execute(
                    """
                    SELECT * FROM statement_uploads 
                    WHERE user_id = ? AND slot_id = ? AND status = 'active'
                    ORDER BY uploaded_at DESC LIMIT 1
                """,
                    (user_id, slot_id),
                ).fetchone()

                is_uploaded = row is not None
                is_stale = False
                age_days = 0

                if is_uploaded:
                    is_stale, age_days = is_statement_stale(row["statement_date"], threshold_days)
                    if not is_stale:
                        uploaded_slots += 1

                    last_upload = {
                        "filename": row["filename"],
                        "uploaded_at": row["uploaded_at"],
                        "statement_date": row["statement_date"],
                        "is_stale": is_stale,
                        "age_days": age_days,
                    }
                else:
                    last_upload = None

                broker_name = slot.get("broker_name", slot.get("name", slot["broker"].replace("_", " ").title()))
                user_slot_data.append(
                    {
                        "slot_id": slot_id,
                        "broker": slot["broker"],
                        "broker_name": broker_name,
                        "label": slot["label"],
                        "is_uploaded": is_uploaded and not is_stale,
                        "is_stale": is_stale,
                        "last_upload": last_upload,
                    }
                )

            result_users.append(
                {
                    "id": user_id,
                    "name": user_name,
                    "slots": user_slot_data,
                }
            )

    return {
        "all_uploaded": uploaded_slots == total_slots and total_slots > 0,
        "uploaded_slots": uploaded_slots,
        "total_slots": total_slots,
        "staleness_threshold_days": threshold_days,
        "users": result_users,
    }


@app.post("/portal/upload")
@api_router.post("/portal/upload")
async def upload_statement(
    user_id: str = Form(...),
    slot_id: str = Form(...),
    file: UploadFile = File(...),
):
    config = load_config()
    user_conf = next((u for u in config.get("users", []) if u["id"] == user_id), None)
    if not user_conf:
        raise HTTPException(status_code=404, detail="User not found in config")

    slot_conf = next((s for s in user_conf.get("expected_statements", []) if s["slot_id"] == slot_id), None)
    if not slot_conf:
        raise HTTPException(status_code=404, detail="Statement slot not found")

    broker = slot_conf["broker"].lower()
    content = await file.read()

    if len(content) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(status_code=400, detail="Uploaded file size exceeds maximum limit (25 MB)")

    # Select parser
    if broker in ["broker_b", "bonds"]:
        parser = BondsParser()
    elif broker in ["broker_a", "equities"]:
        parser = EquitiesParser()
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported broker: {broker}")

    try:
        statement = parser.parse(content, filename=file.filename or "")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    upload_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()
    stmt_date = statement.statement_date or datetime.now().strftime("%Y-%m-%d")

    threshold_days = config.get("staleness_threshold_days", 30)
    stale, age = is_statement_stale(stmt_date, threshold_days)
    if stale:
        raise HTTPException(
            status_code=400,
            detail=f"Statement is outdated ({stmt_date}, {age} days old). Please upload a fresh statement generated within the last {threshold_days} days."
        )

    with get_db() as conn:
        conn.execute(
            "UPDATE statement_uploads SET status = 'superseded' WHERE user_id = ? AND slot_id = ? AND status = 'active'",
            (user_id, slot_id),
        )

        conn.execute(
            """
            INSERT INTO statement_uploads (id, user_id, slot_id, broker, filename, uploaded_at, statement_date, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'active')
        """,
            (upload_id, user_id, slot_id, broker, file.filename or "statement", now_iso, stmt_date),
        )

        for holding in statement.holdings:
            fx = get_fx_rate(holding.currency)
            amount_pln = holding.amount * fx
            nominal_pln = holding.nominal_amount * fx
            profit_pln = holding.profit_or_loss * fx

            conn.execute(
                """
                INSERT INTO parsed_holdings (id, upload_id, user_id, asset_type, details, name, amount, nominal_amount, profit_or_loss, profit_or_loss_pct, currency, quantity, amount_pln, nominal_amount_pln, profit_or_loss_pln, fx_rate, account_number)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    str(uuid.uuid4()),
                    upload_id,
                    user_id,
                    holding.asset_type,
                    holding.details,
                    holding.name,
                    holding.amount,
                    holding.nominal_amount,
                    holding.profit_or_loss,
                    holding.profit_or_loss_pct,
                    holding.currency,
                    holding.quantity,
                    amount_pln,
                    nominal_pln,
                    profit_pln,
                    fx,
                    holding.account_number or "",
                ),
            )

        for tx in statement.transactions:
            try:
                conn.execute(
                    """
                    INSERT INTO transactions (id, amount, name, action, asset_type, place, date, details, profit_or_loss, account_number, currency)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                    (
                        tx.id,
                        tx.amount,
                        tx.name,
                        tx.action,
                        tx.asset_type,
                        tx.place,
                        tx.date,
                        tx.details,
                        tx.profit_or_loss,
                        tx.account_number or "",
                        tx.currency or "PLN",
                    ),
                )
            except sqlite3.IntegrityError:
                pass

        record_portfolio_snapshot(conn, stmt_date)
        conn.commit()

    accounts = sorted(
        list(
            set(h.account_number for h in statement.holdings if h.account_number)
            | set(t.account_number for t in statement.transactions if t.account_number)
        )
    )
    currencies = sorted(
        list(set(h.currency for h in statement.holdings) | set(t.currency for t in statement.transactions))
    )

    return {
        "upload_id": upload_id,
        "statement_date": stmt_date,
        "holdings_count": len(statement.holdings),
        "transactions_count": len(statement.transactions),
        "accounts_count": len(accounts),
        "accounts": accounts,
        "currencies": currencies,
    }


def parse_bond_maturity_key(text: str) -> Tuple[int, int, str]:
    """Extract (year, month, text) from bond name like COI0730 -> (2030, 7, 'COI0730') for sorting closest maturity first."""
    s = (text or "").upper()
    m = re.search(r"([A-Z]{2,4})\s*(\d{2})(\d{2})", s)
    if m:
        mm = int(m.group(2))
        yy = int(m.group(3))
        if 1 <= mm <= 12:
            return (2000 + yy, mm, text)
    m2 = re.search(r"\b(\d{2})(\d{2})\b", s)
    if m2:
        mm = int(m2.group(1))
        yy = int(m2.group(2))
        if 1 <= mm <= 12:
            return (2000 + yy, mm, text)
    return (9999, 99, text or "")


@app.get("/portfolio/details", response_model=list[AssetDetailResponse])
@api_router.get("/portfolio/details", response_model=list[AssetDetailResponse])
async def get_portfolio_details():
    with get_db() as conn:
        rows = conn.execute("""
            SELECT h.asset_type, h.details, h.currency,
                   SUM(h.nominal_amount) as total_nominal,
                   SUM(h.amount) as total_amount,
                   SUM(h.profit_or_loss) as total_profit,
                   SUM(h.nominal_amount_pln) as total_nominal_pln,
                   SUM(h.amount_pln) as total_amount_pln,
                   SUM(h.profit_or_loss_pln) as total_profit_pln,
                   GROUP_CONCAT(DISTINCT h.account_number) as account_numbers
            FROM parsed_holdings h
            JOIN statement_uploads u ON h.upload_id = u.id
            WHERE u.status = 'active'
            GROUP BY h.asset_type, h.details, h.currency
            ORDER BY h.asset_type, h.details
        """).fetchall()

        fixed_rows = conn.execute("""
            SELECT id, asset_type, details, amount, currency, weight_oz
            FROM fixed_assets
            ORDER BY asset_type, details
        """).fetchall()

    result = []
    for row in rows:
        currency = row["currency"] or "PLN"
        nom = round(row["total_nominal"] or 0.0, 2)
        tot = round(row["total_amount"] or 0.0, 2)
        prof = round(row["total_profit"] or 0.0, 2)
        pct = round((prof / nom * 100.0), 2) if nom > 0 else 0.0

        nom_pln = round(row["total_nominal_pln"] or 0.0, 2)
        tot_pln = round(row["total_amount_pln"] or 0.0, 2)
        prof_pln = round(row["total_profit_pln"] or 0.0, 2)
        acc_nums = row["account_numbers"] or None

        result.append(
            AssetDetailResponse(
                assetType=row["asset_type"],
                details=row["details"],
                currency=currency,
                nominalAmount=nom,
                totalAmount=tot,
                profitOrLoss=prof,
                profitOrLossPct=pct,
                nominalAmountPLN=nom_pln,
                totalAmountPLN=tot_pln,
                profitOrLossPLN=prof_pln,
                accountNumber=acc_nums,
            )
        )

    for f_row in fixed_rows:
        curr = (f_row["currency"] or "PLN").strip().upper()
        fx = get_fx_rate(curr)
        f_type = (f_row["asset_type"] or "").lower().strip()
        weight_oz = f_row["weight_oz"] if "weight_oz" in f_row.keys() else None

        if f_type == "gold" and weight_oz is not None and weight_oz > 0:
            spot_oz, _, _ = get_gold_price(curr)
            tot = round(weight_oz * spot_oz, 2)
            cost_basis = round(f_row["amount"] or 0.0, 2)
            if cost_basis > 0:
                nom = cost_basis
                prof = round(tot - nom, 2)
                pct = round((prof / nom * 100.0), 2)
            else:
                nom = tot
                prof = 0.0
                pct = 0.0
            nom_pln = round(nom * fx, 2)
            tot_pln = round(tot * fx, 2)
            prof_pln = round(prof * fx, 2)
            result.append(
                AssetDetailResponse(
                    assetType=f_row["asset_type"],
                    details=f_row["details"],
                    currency=curr,
                    nominalAmount=nom,
                    totalAmount=tot,
                    profitOrLoss=prof,
                    profitOrLossPct=pct,
                    nominalAmountPLN=nom_pln,
                    totalAmountPLN=tot_pln,
                    profitOrLossPLN=prof_pln,
                    accountNumber=f"fixed:{f_row['id']}",
                    id=f"fixed_{f_row['id']}",
                    weightOz=weight_oz,
                )
            )
        else:
            tot = round(f_row["amount"] or 0.0, 2)
            tot_pln = round(tot * fx, 2)
            result.append(
                AssetDetailResponse(
                    assetType=f_row["asset_type"],
                    details=f_row["details"],
                    currency=curr,
                    nominalAmount=tot,
                    totalAmount=tot,
                    profitOrLoss=0.0,
                    profitOrLossPct=0.0,
                    nominalAmountPLN=tot_pln,
                    totalAmountPLN=tot_pln,
                    profitOrLossPLN=0.0,
                    accountNumber=f"fixed:{f_row['id']}",
                    id=f"fixed_{f_row['id']}",
                    weightOz=weight_oz,
                )
            )

    bonds = [r for r in result if r.assetType.lower() in ["bond", "bonds"]]
    bonds.sort(key=lambda r: parse_bond_maturity_key(r.details))

    non_bonds = [r for r in result if r.assetType.lower() not in ["bond", "bonds"]]
    non_bonds.sort(key=lambda r: (r.assetType, r.details))

    return bonds + non_bonds


@app.get("/fixed-assets", response_model=list[FixedAssetResponse])
@api_router.get("/fixed-assets", response_model=list[FixedAssetResponse])
async def get_fixed_assets():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM fixed_assets ORDER BY created_at DESC").fetchall()
    result = []
    for r in rows:
        curr = (r["currency"] or "PLN").strip().upper()
        fx = get_fx_rate(curr)
        amt = round(r["amount"] or 0.0, 2)
        amt_pln = round(amt * fx, 2)
        w_oz = r["weight_oz"] if "weight_oz" in r.keys() else None
        result.append(
            FixedAssetResponse(
                id=r["id"],
                assetType=r["asset_type"],
                details=r["details"],
                amount=amt,
                currency=curr,
                amountPLN=amt_pln,
                weightOz=w_oz,
                createdAt=r["created_at"],
                updatedAt=r["updated_at"],
            )
        )
    return result


@app.post("/fixed-assets", response_model=FixedAssetResponse)
@api_router.post("/fixed-assets", response_model=FixedAssetResponse)
async def create_fixed_asset(payload: FixedAssetCreate):
    asset_type = payload.assetType.lower().strip()
    if asset_type not in ["cash", "gold"]:
        raise HTTPException(status_code=400, detail="assetType must be 'cash' or 'gold'")
    if not payload.details.strip():
        raise HTTPException(status_code=400, detail="details cannot be empty")
    if payload.amount < 0:
        raise HTTPException(status_code=400, detail="amount cannot be negative")

    weight_oz = round(payload.weightOz, 4) if payload.weightOz is not None else None
    if asset_type == "gold" and weight_oz is not None and weight_oz <= 0:
        raise HTTPException(status_code=400, detail="weightOz must be greater than 0")

    asset_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()
    curr = (payload.currency or "PLN").strip().upper()
    amt = round(payload.amount, 2)

    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO fixed_assets (id, asset_type, details, amount, currency, weight_oz, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
            (asset_id, asset_type, payload.details.strip(), amt, curr, weight_oz, now_iso, now_iso),
        )
        record_portfolio_snapshot(conn)
        conn.commit()

    fx = get_fx_rate(curr)
    return FixedAssetResponse(
        id=asset_id,
        assetType=asset_type,
        details=payload.details.strip(),
        amount=amt,
        currency=curr,
        amountPLN=round(amt * fx, 2),
        weightOz=weight_oz,
        createdAt=now_iso,
        updatedAt=now_iso,
    )


@app.put("/fixed-assets/{asset_id}", response_model=FixedAssetResponse)
@api_router.put("/fixed-assets/{asset_id}", response_model=FixedAssetResponse)
async def update_fixed_asset(asset_id: str, payload: FixedAssetUpdate):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM fixed_assets WHERE id = ?", (asset_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Fixed asset not found")

        details = payload.details.strip() if payload.details is not None else row["details"]
        if not details:
            raise HTTPException(status_code=400, detail="details cannot be empty")

        amount = round(payload.amount, 2) if payload.amount is not None else row["amount"]
        if amount < 0:
            raise HTTPException(status_code=400, detail="amount cannot be negative")

        currency = payload.currency.strip().upper() if payload.currency is not None else row["currency"]
        weight_oz = round(payload.weightOz, 4) if payload.weightOz is not None else (row["weight_oz"] if "weight_oz" in row.keys() else None)
        if row["asset_type"] == "gold" and weight_oz is not None and weight_oz <= 0:
            raise HTTPException(status_code=400, detail="weightOz must be greater than 0")

        now_iso = datetime.now(timezone.utc).isoformat()

        conn.execute(
            """
            UPDATE fixed_assets
            SET details = ?, amount = ?, currency = ?, weight_oz = ?, updated_at = ?
            WHERE id = ?
        """,
            (details, amount, currency, weight_oz, now_iso, asset_id),
        )
        record_portfolio_snapshot(conn)
        conn.commit()

    fx = get_fx_rate(currency)
    return FixedAssetResponse(
        id=asset_id,
        assetType=row["asset_type"],
        details=details,
        amount=amount,
        currency=currency,
        amountPLN=round(amount * fx, 2),
        weightOz=weight_oz,
        createdAt=row["created_at"],
        updatedAt=now_iso,
    )


@app.delete("/fixed-assets/{asset_id}")
@api_router.delete("/fixed-assets/{asset_id}")
async def delete_fixed_asset(asset_id: str):
    with get_db() as conn:
        row = conn.execute("SELECT id FROM fixed_assets WHERE id = ?", (asset_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Fixed asset not found")
        conn.execute("DELETE FROM fixed_assets WHERE id = ?", (asset_id,))
        record_portfolio_snapshot(conn)
        conn.commit()
    return {"success": True, "id": asset_id}


@app.get("/market/gold-price", response_model=GoldPriceResponse)
@api_router.get("/market/gold-price", response_model=GoldPriceResponse)
async def get_market_gold_price(currency: str = "PLN"):
    curr = (currency or "PLN").strip().upper()
    price_oz, price_g, date_str = get_gold_price(curr)
    return GoldPriceResponse(
        date=date_str,
        currency=curr,
        pricePerGram=price_g,
        pricePerOz=price_oz,
    )




@app.get("/statements/status", response_model=StatementSyncStatusResponse)
@api_router.get("/statements/status", response_model=StatementSyncStatusResponse)
async def get_statements_sync_status():
    config = load_config()
    users_config = config.get("users", [])
    threshold_days = config.get("staleness_threshold_days", 30)

    total_count = 0
    uploaded_count = 0
    missing_slots = []
    latest_sync_date = None

    with get_db() as conn:
        for user in users_config:
            user_name = user["name"]
            for slot in user.get("expected_statements", []):
                total_count += 1
                row = conn.execute(
                    """
                    SELECT uploaded_at, statement_date FROM statement_uploads 
                    WHERE user_id = ? AND slot_id = ? AND status = 'active'
                    ORDER BY uploaded_at DESC LIMIT 1
                """,
                    (user["id"], slot["slot_id"]),
                ).fetchone()

                if row:
                    s_date = row["statement_date"]
                    is_stale, age_days = is_statement_stale(s_date, threshold_days)
                    if not is_stale:
                        uploaded_count += 1
                        if not latest_sync_date or s_date > latest_sync_date:
                            latest_sync_date = s_date
                    else:
                        missing_slots.append(f"{user_name}: {slot['label']} (Outdated: {age_days} days old)")
                else:
                    missing_slots.append(f"{user_name}: {slot['label']} (Missing)")

    return StatementSyncStatusResponse(
        allUploaded=uploaded_count == total_count and total_count > 0,
        uploadedCount=uploaded_count,
        totalCount=total_count,
        lastSyncDate=latest_sync_date,
        missingSlots=missing_slots,
    )


@app.get("/transactions")
@api_router.get("/transactions")
async def get_transactions():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM transactions ORDER BY date DESC LIMIT 200").fetchall()
    return [dict(r) for r in rows]


@app.get("/portfolio/history", response_model=PortfolioHistoryResponse)
@api_router.get("/portfolio/history", response_model=PortfolioHistoryResponse)
async def get_portfolio_history():
    with get_db() as conn:
        snapshots_rows = conn.execute("""
            SELECT id, snapshot_date, total_amount_pln, nominal_amount_pln, profit_or_loss_pln, amount_saved_pln
            FROM portfolio_snapshots
            ORDER BY snapshot_date ASC
        """).fetchall()

        if not snapshots_rows:
            record_portfolio_snapshot(conn)
            conn.commit()
            snapshots_rows = conn.execute("""
                SELECT id, snapshot_date, total_amount_pln, nominal_amount_pln, profit_or_loss_pln, amount_saved_pln
                FROM portfolio_snapshots
                ORDER BY snapshot_date ASC
            """).fetchall()

    snapshots = []
    for r in snapshots_rows:
        snapshots.append(
            PortfolioSnapshotPoint(
                id=r["id"],
                date=r["snapshot_date"],
                totalAmount=round(r["total_amount_pln"] or 0.0, 2),
                nominalAmount=round(r["nominal_amount_pln"] or 0.0, 2),
                amountSaved=round(r["amount_saved_pln"] or 0.0, 2),
            )
        )

    month_map = {}
    month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    for i in range(len(snapshots)):
        s = snapshots[i]
        d_parts = s.date.split("-")
        y = int(d_parts[0])
        m = int(d_parts[1])
        key = f"{y:04d}-{m:02d}"

        if s.amountSaved > 0:
            saved_val = s.amountSaved
        elif i > 0:
            saved_val = max(0.0, round(s.nominalAmount - snapshots[i - 1].nominalAmount, 2))
        else:
            saved_val = s.amountSaved

        month_map[key] = {
            "year": y,
            "month": m,
            "amount": saved_val,
        }

    monthly_savings = []
    for key in sorted(month_map.keys()):
        item = month_map[key]
        y = item["year"]
        m = item["month"]
        m_name = month_names[m - 1]
        monthly_savings.append(
            MonthlySavingItem(
                id=key,
                year=y,
                month=m,
                label=f"{m_name} {y}",
                shortLabel=m_name,
                amount=round(item["amount"], 2),
            )
        )

    year_map = {}
    for m_item in monthly_savings:
        y = m_item.year
        year_map[y] = year_map.get(y, 0.0) + m_item.amount

    yearly_savings = []
    for y in sorted(year_map.keys()):
        yearly_savings.append(
            YearlySavingItem(
                id=str(y),
                year=y,
                label=str(y),
                amount=round(year_map[y], 2),
            )
        )

    cur_tot = snapshots[-1].totalAmount if snapshots else 0.0
    start_tot = snapshots[0].totalAmount if snapshots else 0.0
    tot_saved = sum(m.amount for m in monthly_savings)
    growth_pct = round(((cur_tot - start_tot) / start_tot * 100.0), 2) if (start_tot > 0 and len(snapshots) > 1) else 0.0

    monthly_avg = round(tot_saved / len(monthly_savings), 2) if monthly_savings else 0.0
    yearly_avg = round(tot_saved / len(yearly_savings), 2) if yearly_savings else 0.0
    cur_month_saved = monthly_savings[-1].amount if monthly_savings else 0.0
    rolling_12_months = monthly_savings[-12:] if monthly_savings else []
    cur_year_saved = round(sum(m.amount for m in rolling_12_months), 2)

    summary = PortfolioHistorySummary(
        currentTotal=cur_tot,
        startingTotal=start_tot,
        totalSaved=round(tot_saved, 2),
        totalGrowthPct=growth_pct,
        monthlyAverageSaved=monthly_avg,
        yearlyAverageSaved=yearly_avg,
        currentMonthSaved=cur_month_saved,
        currentYearSaved=cur_year_saved,
    )

    return PortfolioHistoryResponse(
        summary=summary,
        snapshots=snapshots,
        monthlySavings=monthly_savings,
        yearlySavings=yearly_savings,
    )


@app.post("/portfolio/history/snapshot")
@api_router.post("/portfolio/history/snapshot")
async def force_portfolio_snapshot(date: Optional[str] = None):
    with get_db() as conn:
        record_portfolio_snapshot(conn, snapshot_date=date)
        conn.commit()
    return {"success": True, "message": "Snapshot recorded successfully"}


app.include_router(api_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)
