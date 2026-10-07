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


class FixedAssetCreate(BaseModel):
    assetType: str
    details: str
    amount: float
    currency: str = "PLN"


class FixedAssetUpdate(BaseModel):
    details: Optional[str] = None
    amount: Optional[float] = None
    currency: Optional[str] = None


class FixedAssetResponse(BaseModel):
    id: str
    assetType: str
    details: str
    amount: float
    currency: str
    amountPLN: float
    createdAt: str
    updatedAt: str



class StatementSyncStatusResponse(BaseModel):
    allUploaded: bool
    uploadedCount: int
    totalCount: int
    lastSyncDate: Optional[str]
    missingSlots: List[str]


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
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)

        conn.commit()



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
            SELECT id, asset_type, details, amount, currency
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
        result.append(
            FixedAssetResponse(
                id=r["id"],
                assetType=r["asset_type"],
                details=r["details"],
                amount=amt,
                currency=curr,
                amountPLN=amt_pln,
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

    asset_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()
    curr = (payload.currency or "PLN").strip().upper()
    amt = round(payload.amount, 2)

    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO fixed_assets (id, asset_type, details, amount, currency, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
            (asset_id, asset_type, payload.details.strip(), amt, curr, now_iso, now_iso),
        )
        conn.commit()

    fx = get_fx_rate(curr)
    return FixedAssetResponse(
        id=asset_id,
        assetType=asset_type,
        details=payload.details.strip(),
        amount=amt,
        currency=curr,
        amountPLN=round(amt * fx, 2),
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
        now_iso = datetime.now(timezone.utc).isoformat()

        conn.execute(
            """
            UPDATE fixed_assets
            SET details = ?, amount = ?, currency = ?, updated_at = ?
            WHERE id = ?
        """,
            (details, amount, currency, now_iso, asset_id),
        )
        conn.commit()

    fx = get_fx_rate(currency)
    return FixedAssetResponse(
        id=asset_id,
        assetType=row["asset_type"],
        details=details,
        amount=amount,
        currency=currency,
        amountPLN=round(amount * fx, 2),
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
        conn.commit()
    return {"success": True, "id": asset_id}




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


app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)
