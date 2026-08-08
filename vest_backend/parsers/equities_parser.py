import io
import re
import uuid
import zipfile
from datetime import datetime
from typing import List, Tuple
import pandas as pd
from parsers.base import ParsedHolding, ParsedStatement, ParsedTransaction


class EquitiesParser:
    """Parser for equities brokerage statements (.xlsx, .xls, or .zip containing .xlsx/.xls files)."""

    def parse(self, file_content: bytes, filename: str = "") -> ParsedStatement:
        excel_items = self._extract_excel_items(file_content, filename)
        if not excel_items:
            raise ValueError("No valid Excel spreadsheet (.xlsx/.xls) found in uploaded file")

        statement = ParsedStatement(broker="broker_a")

        # Initial currency hint from filename
        detected_curr = self._detect_currency_from_name(filename)
        statement.account_currency = detected_curr

        latest_date = None

        for item_name, excel_bytes in excel_items:
            # Check currency from item name if nested inside zip
            item_curr = self._detect_currency_from_name(item_name)
            if item_curr != "PLN":
                statement.account_currency = item_curr

            try:
                excel = pd.ExcelFile(io.BytesIO(excel_bytes))

                if "Open Positions" in excel.sheet_names:
                    df_open = pd.read_excel(excel, sheet_name="Open Positions", header=None)
                    stmt_date = self._parse_open_positions(df_open, statement, default_curr=statement.account_currency)
                    if stmt_date and (not latest_date or stmt_date > latest_date):
                        latest_date = stmt_date

                if "Cash Operations" in excel.sheet_names:
                    df_cash = pd.read_excel(excel, sheet_name="Cash Operations", header=None)
                    self._parse_cash_operations(df_cash, statement)

            except Exception:
                continue

        if latest_date:
            statement.statement_date = latest_date
        else:
            date_match = re.search(r"(\d{4}-\d{2}-\d{2})", filename)
            if date_match:
                statement.statement_date = date_match.group(1)
            else:
                date_match_digits = re.search(r"(\d{8})", filename)
                if date_match_digits:
                    raw = date_match_digits.group(1)
                    statement.statement_date = f"{raw[:4]}-{raw[4:6]}-{raw[6:8]}"
                else:
                    statement.statement_date = datetime.now().strftime("%Y-%m-%d")

        return statement

    def _detect_currency_from_name(self, text: str) -> str:
        m = re.search(r"(?:^|[\s_/-])(EUR|USD|PLN|GBP|CHF)(?:[\s_.-]|$)", text.upper())
        if m:
            return m.group(1)
        return "PLN"

    def _extract_excel_items(self, file_content: bytes, filename: str) -> List[Tuple[str, bytes]]:
        fname_lower = filename.lower()
        if fname_lower.endswith(".xlsx") or fname_lower.endswith(".xls"):
            return [(filename, file_content)]

        if fname_lower.endswith(".zip") or file_content.startswith(b"PK\x03\x04"):
            try:
                with zipfile.ZipFile(io.BytesIO(file_content)) as z:
                    excel_files = [
                        f for f in z.namelist()
                        if (f.lower().endswith(".xlsx") or f.lower().endswith(".xls"))
                        and not f.startswith("__MACOSX")
                    ]
                    if excel_files:
                        return [(f, z.read(f)) for f in excel_files]
            except Exception:
                pass

        return [(filename, file_content)]

    def _parse_open_positions(self, df: pd.DataFrame, statement: ParsedStatement, default_curr: str = "PLN") -> str:
        header_idx = None
        account_currency = default_curr
        parsed_date = None

        for idx, row in df.iterrows():
            row_vals = [str(val).strip() for val in row.values if pd.notna(val)]
            row_str = " ".join(row_vals)

            if "Data as of report generated" in row_str:
                date_match = re.search(r"(\d{4}-\d{2}-\d{2})", row_str)
                if date_match:
                    parsed_date = date_match.group(1)

            # Check explicit Currency cell (e.g. ['My Trades', 'Value', '853.48', 'EUR'])
            for val in row_vals:
                val_upper = val.upper()
                if val_upper in ["EUR", "USD", "PLN", "GBP", "CHF"]:
                    account_currency = val_upper

            if "Instrument/Position" in row_str and "Ticker" in row_str:
                header_idx = idx

        statement.account_currency = account_currency

        if header_idx is not None:
            df_positions = df.iloc[header_idx + 1 :].copy()
            df_positions.columns = [str(val).strip() for val in df.iloc[header_idx].values]

            for _, row in df_positions.iterrows():
                instrument = str(row.get("Instrument/Position", "")).strip()
                ticker = str(row.get("Ticker", "")).strip()
                category = str(row.get("Category", "")).strip().upper()
                volume = row.get("Volume")
                value = row.get("Value")
                net_profit_val = row.get("Net Profit")
                if pd.isna(net_profit_val):
                    net_profit_val = row.get("Gross Profit")
                net_profit_pct_val = row.get("Net Profit %")

                if not instrument or instrument == "nan":
                    continue

                if instrument.isdigit():
                    continue

                try:
                    vol_float = float(volume) if pd.notna(volume) else 0.0
                    val_float = float(value) if pd.notna(value) else 0.0
                    profit_float = float(net_profit_val) if pd.notna(net_profit_val) else 0.0
                    profit_pct_float = float(net_profit_pct_val) if pd.notna(net_profit_pct_val) else 0.0
                except (ValueError, TypeError):
                    continue

                if val_float <= 0 and vol_float <= 0:
                    continue

                nominal_val = val_float - profit_float
                asset_type = "etf" if "ETF" in category else "stock"
                details = ticker if ticker and ticker != "nan" else instrument
                name = f"{instrument} ({details})" if ticker else instrument

                existing = next((h for h in statement.holdings if h.details == details), None)
                if existing:
                    existing.amount += val_float
                    existing.nominal_amount += nominal_val
                    existing.profit_or_loss += profit_float
                    existing.quantity += vol_float
                    if existing.nominal_amount > 0:
                        existing.profit_or_loss_pct = (existing.profit_or_loss / existing.nominal_amount) * 100.0
                else:
                    holding = ParsedHolding(
                        asset_type=asset_type,
                        details=details,
                        name=name,
                        amount=val_float,
                        nominal_amount=nominal_val,
                        profit_or_loss=profit_float,
                        profit_or_loss_pct=profit_pct_float,
                        currency=account_currency,
                        quantity=vol_float,
                    )
                    statement.holdings.append(holding)

        return parsed_date or ""

    def _parse_cash_operations(self, df: pd.DataFrame, statement: ParsedStatement):
        header_idx = None
        for idx, row in df.iterrows():
            row_str = " ".join([str(val) for val in row.values if pd.notna(val)])
            if "Type" in row_str and "Amount" in row_str and ("Time" in row_str or "Date" in row_str):
                header_idx = idx
                break

        if header_idx is not None:
            df_ops = df.iloc[header_idx + 1 :].copy()
            df_ops.columns = [str(val).strip() for val in df.iloc[header_idx].values]

            for _, row in df_ops.iterrows():
                op_type = str(row.get("Type", "")).strip()
                instrument = str(row.get("Instrument", "")).strip()
                ticker = str(row.get("Ticker", "")).strip()
                category = str(row.get("Category", "")).strip().upper()
                time_val = str(row.get("Time", "")).strip()
                amount_val = row.get("Amount")
                op_id = str(row.get("ID", "")).strip()
                comment = str(row.get("Comment", "")).strip()

                if not op_type or op_type == "nan" or op_type == "Total":
                    continue

                try:
                    amount = float(amount_val)
                except (ValueError, TypeError):
                    continue

                if "purchase" in op_type.lower():
                    action = "bought"
                elif "sell" in op_type.lower():
                    action = "sold"
                elif amount > 0:
                    action = "cashDeposit"
                else:
                    action = "cashWithdrawal"

                asset_type = "etf" if "ETF" in category else ("stock" if ticker and ticker != "nan" else "cash")
                name = instrument if instrument and instrument != "nan" else op_type
                details = ticker if ticker and ticker != "nan" else comment

                tx_id = op_id if op_id and op_id != "nan" else str(uuid.uuid4())
                if not any(t.id == tx_id for t in statement.transactions):
                    tx = ParsedTransaction(
                        id=tx_id,
                        name=name,
                        action=action,
                        asset_type=asset_type,
                        place="Brokerage",
                        date=time_val if time_val and time_val != "nan" else datetime.now().isoformat(),
                        amount=abs(amount),
                        details=details,
                    )
                    statement.transactions.append(tx)
