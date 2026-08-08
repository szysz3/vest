from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class ParsedHolding:
    asset_type: str  # bond, etf, stock, crypto, gold, cash
    details: str  # e.g. "ROR0127", "VWCE.DE"
    name: str  # e.g. "Obligacje ROR0127", "FTSE All-World"
    amount: float  # current market value (Wartość Aktualna)
    nominal_amount: float = 0.0  # nominal value / cost basis (Wartość Nominalna)
    profit_or_loss: float = 0.0  # profit/loss difference
    profit_or_loss_pct: float = 0.0  # profit/loss percentage
    currency: str = "PLN"
    quantity: float = 0.0


@dataclass
class ParsedTransaction:
    id: str
    name: str
    action: str  # bought, sold, cashDeposit, cashWithdrawal, positionClosed
    asset_type: str
    place: str
    date: str  # ISO string
    amount: float
    details: str = ""
    profit_or_loss: Optional[float] = None


@dataclass
class ParsedStatement:
    broker: str
    statement_date: Optional[str] = None  # YYYY-MM-DD
    holdings: List[ParsedHolding] = field(default_factory=list)
    transactions: List[ParsedTransaction] = field(default_factory=list)
    account_currency: str = "PLN"
