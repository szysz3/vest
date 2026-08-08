import io
import re
from datetime import datetime
import pandas as pd
from parsers.base import ParsedHolding, ParsedStatement, ParsedTransaction


class PKOParser:
    """Parser for PKO BP Polish Treasury Bonds Excel statements (StanRachunkuRejestrowego_*.xls)."""

    def parse(self, file_content: bytes, filename: str = "") -> ParsedStatement:
        statement = ParsedStatement(broker="pko", account_currency="PLN")

        date_match = re.search(r"(\d{4}-\d{2}-\d{2})", filename)
        if date_match:
            statement.statement_date = date_match.group(1)
        else:
            statement.statement_date = datetime.now().strftime("%Y-%m-%d")

        try:
            excel = pd.ExcelFile(io.BytesIO(file_content))
            sheet_name = "tbl1" if "tbl1" in excel.sheet_names else excel.sheet_names[0]
            df = pd.read_excel(excel, sheet_name=sheet_name, header=0)

            df.columns = [str(c).strip().upper() for c in df.columns]

            for _, row in df.iterrows():
                emisja = str(row.get("EMISJA", "")).strip()
                if not emisja or emisja.lower() == "nan":
                    continue

                avail_qty = float(row.get("DOSTĘPNA LICZBA OBLIGACJI", 0) or 0)
                blocked_qty = float(row.get("ZABLOKOWANA LICZBA OBLIGACJI", 0) or 0)
                total_qty = avail_qty + blocked_qty

                nominal_val = float(row.get("WARTOŚĆ NOMINALNA", 0) or 0)
                cur_val = float(row.get("WARTOŚĆ AKTUALNA", 0) or 0)
                if cur_val == 0:
                    cur_val = nominal_val

                profit_or_loss = cur_val - nominal_val
                profit_or_loss_pct = (profit_or_loss / nominal_val * 100.0) if nominal_val > 0 else 0.0

                holding = ParsedHolding(
                    asset_type="bond",
                    details=emisja,
                    name=f"Obligacje {emisja}",
                    amount=cur_val,
                    nominal_amount=nominal_val,
                    profit_or_loss=profit_or_loss,
                    profit_or_loss_pct=profit_or_loss_pct,
                    currency="PLN",
                    quantity=total_qty,
                )
                statement.holdings.append(holding)

        except Exception as e:
            raise ValueError(f"Failed to parse PKO statement: {e}")

        return statement
