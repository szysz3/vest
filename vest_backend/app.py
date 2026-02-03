import os
import sqlite3
import uuid
from contextlib import asynccontextmanager, contextmanager
from datetime import datetime
from enum import Enum
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

DB_PATH = Path(os.environ.get("DB_PATH", Path(__file__).parent / "vest.db"))

ASSET_TYPES = ["bond", "etf", "stock", "crypto", "gold", "cash"]

DEFAULT_OPERATORS = [
    {"id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "vest.operator.xtb")), "name": "XTB"},
    {"id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "vest.operator.bank")), "name": "Bank"},
]


class TransactionAction(str, Enum):
    bought = "bought"
    sold = "sold"
    cashDeposit = "cashDeposit"
    cashWithdrawal = "cashWithdrawal"
    positionClosed = "positionClosed"


class AssetType(str, Enum):
    bond = "bond"
    etf = "etf"
    stock = "stock"
    crypto = "crypto"
    gold = "gold"
    cash = "cash"


class Transaction(BaseModel):
    id: str
    amount: float
    name: str
    action: TransactionAction
    assetType: AssetType
    place: str
    date: datetime
    details: str = ""
    profitOrLoss: float | None = None


class Operator(BaseModel):
    id: str
    name: str


class TransactionFormOptions(BaseModel):
    assetTypes: list[str]
    operators: list[Operator]


class AssetDetailResponse(BaseModel):
    assetType: str
    details: str
    totalAmount: float


@contextmanager
def get_db():
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
                date TEXT NOT NULL
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS operators (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
        """)
        # Migrate: add details column if missing
        cursor = conn.execute("PRAGMA table_info(transactions)")
        columns = [row["name"] for row in cursor.fetchall()]
        if "details" not in columns:
            conn.execute("ALTER TABLE transactions ADD COLUMN details TEXT NOT NULL DEFAULT ''")
        if "profit_or_loss" not in columns:
            conn.execute("ALTER TABLE transactions ADD COLUMN profit_or_loss REAL")
        # Seed operators if empty
        cursor = conn.execute("SELECT COUNT(*) FROM operators")
        if cursor.fetchone()[0] == 0:
            for op in DEFAULT_OPERATORS:
                conn.execute(
                    "INSERT INTO operators (id, name) VALUES (?, ?)",
                    (op["id"], op["name"]),
                )
        conn.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="Vest Backend", lifespan=lifespan)


@app.get("/transactions", response_model=list[Transaction])
async def get_transactions():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM transactions ORDER BY date DESC").fetchall()
    return [
        Transaction(
            id=row["id"],
            amount=row["amount"],
            name=row["name"],
            action=row["action"],
            assetType=row["asset_type"],
            place=row["place"],
            date=row["date"],
            details=row["details"],
            profitOrLoss=row["profit_or_loss"],
        )
        for row in rows
    ]


@app.post("/transactions", response_model=Transaction, status_code=201)
async def add_transaction(transaction: Transaction):
    with get_db() as conn:
        try:
            conn.execute(
                "INSERT INTO transactions (id, amount, name, action, asset_type, place, date, details, profit_or_loss) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    transaction.id,
                    transaction.amount,
                    transaction.name,
                    transaction.action.value,
                    transaction.assetType.value,
                    transaction.place,
                    transaction.date.isoformat(),
                    transaction.details,
                    transaction.profitOrLoss,
                ),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            raise HTTPException(status_code=409, detail="Transaction already exists")
    return transaction


@app.post("/transactions/batch", response_model=list[Transaction], status_code=201)
async def add_transactions_batch(transactions: list[Transaction]):
    with get_db() as conn:
        try:
            for transaction in transactions:
                conn.execute(
                    "INSERT INTO transactions (id, amount, name, action, asset_type, place, date, details, profit_or_loss) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        transaction.id,
                        transaction.amount,
                        transaction.name,
                        transaction.action.value,
                        transaction.assetType.value,
                        transaction.place,
                        transaction.date.isoformat(),
                        transaction.details,
                        transaction.profitOrLoss,
                    ),
                )
            conn.commit()
        except sqlite3.IntegrityError:
            raise HTTPException(status_code=409, detail="One or more transactions already exist")
    return transactions


@app.get("/transactions/form-options", response_model=TransactionFormOptions)
async def get_form_options():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM operators").fetchall()
    return TransactionFormOptions(
        assetTypes=ASSET_TYPES,
        operators=[Operator(id=row["id"], name=row["name"]) for row in rows],
    )


@app.get("/portfolio/details", response_model=list[AssetDetailResponse])
async def get_portfolio_details():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM transactions ORDER BY date DESC").fetchall()

    holdings: dict[tuple[str, str], float] = {}
    for row in rows:
        asset_type = row["asset_type"]
        details = row["details"]
        if not details:
            continue
        key = (asset_type, details)
        action = row["action"]
        amount = row["amount"]
        if action in ("bought", "cashDeposit"):
            holdings[key] = holdings.get(key, 0) + amount
        elif action in ("sold", "cashWithdrawal", "positionClosed"):
            holdings[key] = holdings.get(key, 0) - amount

    result = []
    for (asset_type, details), total in holdings.items():
        if total > 0:
            result.append(AssetDetailResponse(
                assetType=asset_type,
                details=details,
                totalAmount=total,
            ))

    result.sort(key=lambda x: (x.assetType, x.details))
    return result


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
