import json
import math
import re
import urllib.request
import xml.etree.ElementTree as ET
from datetime import date, datetime, timezone
from typing import Dict, List, Optional, Tuple
from pydantic import BaseModel

BOND_MARKET_CACHE: Dict[str, dict] = {}

BOND_DURATION_YEARS = {
    "OTS": 0,  # 3 months
    "ROR": 1,
    "DOR": 2,
    "DOS": 2,  # Legacy 2-year fixed
    "TOS": 3,
    "COI": 4,
    "ROS": 6,
    "EDO": 10,
    "ROD": 12,
}

BOND_DISPLAY_NAMES = {
    "OTS": "3-Month Fixed (OTS)",
    "ROR": "1-Year Floating NBP (ROR)",
    "DOR": "2-Year Floating NBP (DOR)",
    "TOS": "3-Year Fixed Capitalized (TOS)",
    "COI": "4-Year Inflation-Indexed (COI)",
    "ROS": "6-Year Family Inflation (ROS 800+)",
    "EDO": "10-Year Inflation Capitalized (EDO)",
    "ROD": "12-Year Family Inflation (ROD 800+)",
}

# Default parameters based on current Polish Ministry of Finance "list emisyjny"
DEFAULT_BOND_SPECS = [
    {
        "type": "OTS",
        "durationYears": 0,
        "durationMonths": 3,
        "firstYearRatePct": 2.00,
        "marginPct": 0.00,
        "earlyRedemptionFeePLN": 0.00,
        "isFamilyBond": False,
        "indexation": "fixed",
        "payoutType": "maturity_simple",
    },
    {
        "type": "ROR",
        "durationYears": 1,
        "durationMonths": 12,
        "firstYearRatePct": 4.00,
        "marginPct": 0.00,
        "earlyRedemptionFeePLN": 0.50,
        "isFamilyBond": False,
        "indexation": "nbp",
        "payoutType": "monthly_payout",
    },
    {
        "type": "DOR",
        "durationYears": 2,
        "durationMonths": 24,
        "firstYearRatePct": 4.15,
        "marginPct": 0.15,
        "earlyRedemptionFeePLN": 0.70,
        "isFamilyBond": False,
        "indexation": "nbp",
        "payoutType": "monthly_payout",
    },
    {
        "type": "TOS",
        "durationYears": 3,
        "durationMonths": 36,
        "firstYearRatePct": 4.40,
        "marginPct": 0.00,
        "earlyRedemptionFeePLN": 1.00,
        "isFamilyBond": False,
        "indexation": "fixed",
        "payoutType": "annual_capitalized",
    },
    {
        "type": "COI",
        "durationYears": 4,
        "durationMonths": 48,
        "firstYearRatePct": 4.75,
        "marginPct": 1.50,
        "earlyRedemptionFeePLN": 2.00,
        "isFamilyBond": False,
        "indexation": "cpi",
        "payoutType": "annual_payout",
    },
    {
        "type": "EDO",
        "durationYears": 10,
        "durationMonths": 120,
        "firstYearRatePct": 5.35,
        "marginPct": 2.00,
        "earlyRedemptionFeePLN": 3.00,
        "isFamilyBond": False,
        "indexation": "cpi",
        "payoutType": "annual_capitalized",
    },
    {
        "type": "ROS",
        "durationYears": 6,
        "durationMonths": 72,
        "firstYearRatePct": 5.00,
        "marginPct": 2.00,
        "earlyRedemptionFeePLN": 2.00,
        "isFamilyBond": True,
        "indexation": "cpi",
        "payoutType": "annual_capitalized",
    },
    {
        "type": "ROD",
        "durationYears": 12,
        "durationMonths": 144,
        "firstYearRatePct": 5.60,
        "marginPct": 2.50,
        "earlyRedemptionFeePLN": 3.00,
        "isFamilyBond": True,
        "indexation": "cpi",
        "payoutType": "annual_capitalized",
    },
]


class BondPlannerSettingsModel(BaseModel):
    targetMonthlyNominal: float = 3000.0
    horizonYears: int = 5
    investmentBudget: float = 10000.0
    includeFamilyBonds: bool = False
    customInflationRatePct: Optional[float] = None
    customNbpRatePct: Optional[float] = None


class BondOfferSeriesModel(BaseModel):
    code: str
    type: str
    name: str
    durationYears: int
    maturityMonth: int
    maturityYear: int
    maturityLabel: str
    firstYearRatePct: float
    marginPct: float
    earlyRedemptionFeePLN: float
    isFamilyBond: bool
    indexation: str
    payoutType: str


class BondMarketConditionsModel(BaseModel):
    referenceDate: str
    issueMonth: int
    issueYear: int
    issueMonthLabel: str
    liveInflationRatePct: float
    liveNbpReferenceRatePct: float
    effectiveInflationRatePct: float
    effectiveNbpReferenceRatePct: float
    sourceUrl: str
    availableSeries: List[BondOfferSeriesModel]


class BondComparisonOptionModel(BaseModel):
    bondCode: str
    bondType: str
    nativeDurationYears: int
    holdingYears: int
    isEarlyRedemption: bool
    grossInterestPerBondPLN: float
    earlyRedemptionFeePerBondPLN: float
    taxPerBondPLN: float
    netProfitPerBondPLN: float
    netPayoutPerBondPLN: float
    effectiveAnnualRatePct: float


class YearlyContinuitySlotModel(BaseModel):
    id: str
    year: int
    month: int
    label: str
    holdingYears: int
    targetNominalPLN: float
    existingNominalPLN: float
    existingActualPLN: float
    shortfallNominalPLN: float
    allocatedNewNominalPLN: float
    allocatedUnits: int
    unfundedGapNominalPLN: float
    recommendedBondCode: Optional[str] = None
    recommendedBondType: Optional[str] = None
    isEarlyRedemption: bool = False
    earlyRedemptionTargetLabel: Optional[str] = None
    projectedNetProfitPLN: float = 0.0
    projectedTotalPayoutPLN: float = 0.0
    effectiveAnnualRatePct: float = 0.0
    heldBonds: List[str] = []
    alternatives: List[BondComparisonOptionModel] = []


class PurchaseAllocationItemModel(BaseModel):
    targetLabel: str
    targetYear: int
    targetMonth: int
    holdingYears: int
    units: int
    nominalPLN: float
    isEarlyRedemption: bool
    isSurplus: bool
    projectedNetProfitPLN: float


class BondPurchaseRecommendationModel(BaseModel):
    id: str
    bondCode: str
    bondType: str
    bondName: str
    nativeMaturityLabel: str
    totalUnits: int
    totalNominalPLN: float
    requiredContinuityNominalPLN: float
    surplusNominalPLN: float
    projectedTotalNetProfitPLN: float
    effectiveAnnualRatePct: float
    firstYearRatePct: float
    marginPct: float
    earlyRedemptionFeePLN: float
    allocations: List[PurchaseAllocationItemModel]


class EarlyRedemptionRecommendationModel(BaseModel):
    id: str
    targetYear: int
    targetMonth: int
    targetLabel: str
    shortfallNominalPLN: float
    sourceBondCode: str
    sourceBondType: str
    sourceMaturityLabel: str
    recommendedRedeemUnits: int
    recommendedRedeemNominalPLN: float
    estimatedFeePLN: float
    isAnniversaryMonthMatch: bool
    reason: str


class HeldBondSliceModel(BaseModel):
    code: str
    nominalPLN: float
    actualPLN: float


class MonthlyMaturityCellModel(BaseModel):
    id: str
    year: int
    month: int
    monthShortLabel: str
    label: str
    targetNominalPLN: float
    existingNominalPLN: float
    proposedNominalPLN: float
    shortfallNominalPLN: float
    surplusNominalPLN: float
    coveragePct: float
    isCurrentIssueMonth: bool
    heldBonds: List[HeldBondSliceModel]


class YearlyMaturityRowModel(BaseModel):
    id: str
    year: int
    totalExistingNominalPLN: float
    totalProposedNominalPLN: float
    totalTargetNominalPLN: float
    months: List[MonthlyMaturityCellModel]


class BondPlannerSummaryModel(BaseModel):
    totalHeldBondsNominalPLN: float
    totalHeldBondsActualPLN: float
    currentMonthTargetSeriesCount: int
    currentMonthCoveredYearsCount: int
    totalRequiredForContinuityPLN: float
    budgetAllocatedToContinuityPLN: float
    budgetAllocatedToSurplusPLN: float
    unfundedContinuityGapPLN: float
    projectedTotalNetProfitFromBudgetPLN: float


class BondPlannerResponse(BaseModel):
    settings: BondPlannerSettingsModel
    market: BondMarketConditionsModel
    summary: BondPlannerSummaryModel
    yearlyContinuitySlots: List[YearlyContinuitySlotModel]
    purchaseRecommendations: List[BondPurchaseRecommendationModel]
    earlyRedemptionRecommendations: List[EarlyRedemptionRecommendationModel]
    maturityCalendar: List[YearlyMaturityRowModel]


MONTH_NAMES_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def compute_series_code(bond_type: str, issue_year: int, issue_month: int, duration_years: int, duration_months: int) -> Tuple[str, int, int]:
    if duration_years == 0:
        total_m = (issue_year * 12 + (issue_month - 1)) + duration_months
        mat_year = total_m // 12
        mat_month = (total_m % 12) + 1
    else:
        mat_year = issue_year + duration_years
        mat_month = issue_month
    code = f"{bond_type}{mat_month:02d}{mat_year % 100:02d}"
    return code, mat_month, mat_year


def fetch_live_nbp_reference_rate() -> float:
    url = "https://static.nbp.pl/dane/stopy/stopy_procentowe.xml"
    req = urllib.request.Request(url, headers={"User-Agent": "VestBackend/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            xml_bytes = resp.read()
            root = ET.fromstring(xml_bytes)
            for pos in root.iter("pozycja"):
                if pos.attrib.get("id") == "ref":
                    val_str = pos.attrib.get("oprocentowanie", "").replace(",", ".")
                    val = float(val_str)
                    if val >= 0:
                        return val
    except Exception as e:
        print(f"Warning: Failed to fetch NBP reference rate: {e}")
    return 3.75


def fetch_live_poland_cpi_inflation() -> float:
    """
    Fetches live Polish GUS CPI YoY inflation ('wskaźnik cen towarów i usług konsumpcyjnych r/r'):
    1. Official GUS (stat.gov.pl) latest CPI signal announcement ('Informacja sygnalna').
    2. Bankier.pl macroeconomic GUS CPI YoY indicator ('Inflacja r/r (Polska)').
    3. Official GUS monthly CPI table ('Analogiczny miesiąc poprzedniego roku = 100').
    """
    headers = {"User-Agent": "Mozilla/5.0 (VestBackend/1.0)"}

    # 1. Primary: Official GUS (stat.gov.pl) latest CPI announcement
    try:
        index_url = "https://stat.gov.pl/obszary-tematyczne/ceny-handel/wskazniki-cen/"
        req = urllib.request.Request(index_url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
        links = re.findall(
            r'href=["\'](https?://stat\.gov\.pl/obszary-tematyczne/ceny-handel/wskazniki-cen/[^"\']*towarow-i-uslug-konsumpcyjnych[^"\']*\.html)["\']',
            html,
        )
        if links:
            ann_url = links[0]
            req_ann = urllib.request.Request(ann_url, headers=headers)
            with urllib.request.urlopen(req_ann, timeout=5) as resp_ann:
                ann_html = resp_ann.read().decode("utf-8", errors="ignore")
            ann_text = re.sub(r"<[^>]+>", " ", ann_html)
            ann_text = re.sub(r"\s+", " ", ann_text)
            # Match e.g. "Ceny towarów i usług konsumpcyjnych ... wzrosły o 3,5% (wskaźnik cen 103,5) w porównaniu z analogicznym miesiącem ub. roku"
            m = re.search(
                r"[Cc]eny towar[óo]w i us[łl]ug konsumpcyjnych[^\.]{0,220}?\(\s*wska[źz]nik cen\s+(\d+[,\.]\d+)\s*\)\s*w por[óo]wnaniu z analogicznym miesi[ąa]cem",
                ann_text,
            )
            if m:
                idx_val = float(m.group(1).replace(",", "."))
                return round(idx_val - 100.0, 2)
            m_pct = re.search(
                r"[Cc]eny towar[óo]w i us[łl]ug konsumpcyjnych[^\.]{0,180}?wzros[łl]y o\s+(\d+[,\.]\d+)\s*%\s*[^\.]{0,80}?analogicznym miesi[ąa]cem",
                ann_text,
            )
            if m_pct:
                return round(float(m_pct.group(1).replace(",", ".")), 2)
    except Exception as e:
        print(f"Warning: Failed to fetch GUS CPI announcement: {e}")

    # 2. Secondary: Bankier.pl GUS CPI YoY ('Inflacja r/r (Polska)')
    try:
        bankier_url = "https://www.bankier.pl/gospodarka/wskazniki-makroekonomiczne/inflacja-rdr-pol"
        req_b = urllib.request.Request(bankier_url, headers=headers)
        with urllib.request.urlopen(req_b, timeout=5) as resp_b:
            b_html = resp_b.read().decode("utf-8", errors="ignore")
        b_text = re.sub(r"<[^>]+>", " ", b_html)
        b_text = re.sub(r"\s+", " ", b_text)
        m_b = re.search(r"Inflacja r/r\s*\(Polska\)\s*(-?\d+[,\.]\d+)\s*%", b_text)
        if m_b:
            return round(float(m_b.group(1).replace(",", ".")), 2)
    except Exception as e:
        print(f"Warning: Failed to fetch Bankier CPI inflation: {e}")

    # 3. Tertiary: Official GUS monthly table ('Analogiczny miesiąc poprzedniego roku = 100')
    try:
        table_url = "https://stat.gov.pl/obszary-tematyczne/ceny-handel/wskazniki-cen/wskazniki-cen-towarow-i-uslug-konsumpcyjnych-pot-inflacja-/miesieczne-wskazniki-cen-towarow-i-uslug-konsumpcyjnych-od-1982-roku/"
        req_t = urllib.request.Request(table_url, headers=headers)
        with urllib.request.urlopen(req_t, timeout=5) as resp_t:
            t_html = resp_t.read().decode("utf-8", errors="ignore")
        t_text = re.sub(r"<[^>]+>", " ", t_html)
        t_text = re.sub(r"\s+", " ", t_text)
        idx = t_text.find("Analogiczny miesiąc poprzedniego roku = 100")
        if idx != -1:
            row_m = re.search(r"20\d{2}\s+((?:\d{2,3}[,\.]\d+\s*)+)", t_text[idx : idx + 400])
            if row_m:
                nums = re.findall(r"\d{2,3}[,\.]\d+", row_m.group(1))
                if nums:
                    latest_idx = float(nums[-1].replace(",", "."))
                    return round(latest_idx - 100.0, 2)
    except Exception as e:
        print(f"Warning: Failed to fetch GUS CPI table: {e}")

    return 3.50


def scrape_obligacje_skarbowe_specs() -> Tuple[Dict[str, dict], str]:
    """
    Scrapes obligacjeskarbowe.pl main page and the latest monthly sale communication
    for current bond series codes, 1st period interest rates, and margins.
    """
    base_url = "https://www.obligacjeskarbowe.pl"
    source_url = base_url
    scraped: Dict[str, dict] = {}

    try:
        req = urllib.request.Request(base_url + "/", headers={"User-Agent": "Mozilla/5.0 (VestBackend/1.0)"})
        with urllib.request.urlopen(req, timeout=4) as resp:
            html = resp.read().decode("utf-8", errors="ignore")

        comm_match = re.search(r'href=["\'](/komunikaty/z-dniem-1-[^"\']+rozpoczyna-sie-sprzedaz-obligacji[^"\']*)["\']', html)
        if comm_match:
            comm_url = base_url + comm_match.group(1)
            source_url = comm_url
            req_comm = urllib.request.Request(comm_url, headers={"User-Agent": "Mozilla/5.0 (VestBackend/1.0)"})
            with urllib.request.urlopen(req_comm, timeout=4) as resp_comm:
                comm_html = resp_comm.read().decode("utf-8", errors="ignore")
                text = re.sub(r"<[^>]+>", " ", comm_html)
                text = re.sub(r"\s+", " ", text)

                for spec in DEFAULT_BOND_SPECS:
                    b_type = spec["type"]
                    pattern = rf"\(\s*({b_type}\d{{4}})\s*\)(.*?)(?=\(\s*[A-Z]{{3}}\d{{4}}\s*\)|Powr[óo]t|$)"
                    m = re.search(pattern, text, re.IGNORECASE)
                    if m:
                        code = m.group(1).upper()
                        segment = m.group(2)
                        rate_m = re.search(r"wynosi\s+(\d+[,\.]\d+)\s*%", segment)
                        margin_m = re.search(r"mar[żz]y\s+(\d+[,\.]\d+)\s*%", segment)
                        entry = {"code": code}
                        if rate_m:
                            entry["firstYearRatePct"] = float(rate_m.group(1).replace(",", "."))
                        if margin_m:
                            entry["marginPct"] = float(margin_m.group(1).replace(",", "."))
                        scraped[b_type] = entry
    except Exception as e:
        print(f"Warning: Failed to scrape obligacjeskarbowe.pl: {e}")

    return scraped, source_url


def get_bond_market_data(ref_date: Optional[date] = None) -> dict:
    if ref_date is None:
        ref_date = datetime.now(timezone.utc).date()

    cache_key = ref_date.strftime("%Y-%m-%d")
    if cache_key in BOND_MARKET_CACHE:
        return BOND_MARKET_CACHE[cache_key]

    live_nbp = fetch_live_nbp_reference_rate()
    live_cpi = fetch_live_poland_cpi_inflation()
    scraped_specs, source_url = scrape_obligacje_skarbowe_specs()

    data = {
        "referenceDate": cache_key,
        "liveNbpReferenceRatePct": live_nbp,
        "liveInflationRatePct": live_cpi,
        "scrapedSpecs": scraped_specs,
        "sourceUrl": source_url,
    }
    BOND_MARKET_CACHE[cache_key] = data
    return data


def build_offer_series_for_month(issue_year: int, issue_month: int, scraped_specs: Dict[str, dict]) -> List[BondOfferSeriesModel]:
    series_list: List[BondOfferSeriesModel] = []
    for spec in DEFAULT_BOND_SPECS:
        b_type = spec["type"]
        dur_y = spec["durationYears"]
        dur_m = spec["durationMonths"]
        code, mat_m, mat_y = compute_series_code(b_type, issue_year, issue_month, dur_y, dur_m)

        scraped = scraped_specs.get(b_type, {})
        first_rate = float(scraped.get("firstYearRatePct", spec["firstYearRatePct"]))
        margin = float(scraped.get("marginPct", spec["marginPct"]))

        series_list.append(
            BondOfferSeriesModel(
                code=code,
                type=b_type,
                name=BOND_DISPLAY_NAMES.get(b_type, b_type),
                durationYears=dur_y,
                maturityMonth=mat_m,
                maturityYear=mat_y,
                maturityLabel=f"{mat_m:02d}.{mat_y}",
                firstYearRatePct=first_rate,
                marginPct=margin,
                earlyRedemptionFeePLN=float(spec["earlyRedemptionFeePLN"]),
                isFamilyBond=bool(spec["isFamilyBond"]),
                indexation=str(spec["indexation"]),
                payoutType=str(spec["payoutType"]),
            )
        )
    return series_list


def simulate_bond_holding_return(
    series: BondOfferSeriesModel,
    holding_years: int,
    inflation_rate_pct: float,
    nbp_rate_pct: float,
) -> Optional[BondComparisonOptionModel]:
    """
    Calculates exact net return per 100 PLN bond when holding `series` for `holding_years` years
    (where 1 <= holding_years <= series.durationYears).
    Accounts for annual capitalization vs. annual/monthly payouts, early redemption fee
    ('opłata za przedterminowy wykup'), and 19% Belka capital gains tax.
    """
    if series.durationYears < 1 or holding_years < 1 or holding_years > series.durationYears:
        return None

    is_early = holding_years < series.durationYears
    r1 = series.firstYearRatePct / 100.0
    cpi = max(0.0, inflation_rate_pct) / 100.0
    nbp = max(0.0, nbp_rate_pct) / 100.0
    margin = series.marginPct / 100.0

    if series.payoutType == "annual_capitalized":
        # TOS, EDO, ROS, ROD: Compounded annually, taxed once at redemption/maturity
        val = 100.0
        for yr in range(1, holding_years + 1):
            if yr == 1:
                r = r1
            elif series.indexation == "fixed":
                r = r1
            else:
                r = cpi + margin
            val = round(val * (1.0 + r), 2)

        gross_interest = round(val - 100.0, 2)
        fee = min(gross_interest, series.earlyRedemptionFeePLN) if is_early else 0.0
        taxable = max(0.0, round(gross_interest - fee, 2))
        tax = round(taxable * 0.19, 2)
        net_profit = round(taxable - tax, 2)

    elif series.payoutType == "annual_payout":
        # COI: Annual interest paid out each year and taxed at 19% annually
        gross_total = 0.0
        tax_total = 0.0
        for yr in range(1, holding_years + 1):
            r = r1 if yr == 1 else (cpi + margin)
            yr_gross = round(100.0 * r, 2)
            gross_total = round(gross_total + yr_gross, 2)
            if yr < holding_years or not is_early:
                yr_tax = round(yr_gross * 0.19, 2)
                tax_total = round(tax_total + yr_tax, 2)
            else:
                # Early redemption at end of year `holding_years`
                fee_here = min(gross_total, series.earlyRedemptionFeePLN)
                yr_taxable = max(0.0, round(yr_gross - fee_here, 2))
                yr_tax = round(yr_taxable * 0.19, 2)
                tax_total = round(tax_total + yr_tax, 2)

        fee = min(gross_total, series.earlyRedemptionFeePLN) if is_early else 0.0
        net_profit = round(gross_total - fee - tax_total, 2)
        gross_interest = gross_total
        tax = tax_total

    else:
        # ROR, DOR: Monthly interest payout
        total_months = holding_years * 12
        gross_total = 0.0
        tax_total = 0.0
        for m in range(1, total_months + 1):
            r_annual = r1 if m == 1 else (nbp + margin)
            m_gross = round(100.0 * (r_annual / 12.0), 2)
            gross_total = round(gross_total + m_gross, 2)
            if m < total_months or not is_early:
                m_tax = round(m_gross * 0.19, 2)
                tax_total = round(tax_total + m_tax, 2)
            else:
                fee_here = min(gross_total, series.earlyRedemptionFeePLN)
                m_taxable = max(0.0, round(m_gross - fee_here, 2))
                m_tax = round(m_taxable * 0.19, 2)
                tax_total = round(tax_total + m_tax, 2)

        fee = min(gross_total, series.earlyRedemptionFeePLN) if is_early else 0.0
        net_profit = round(gross_total - fee - tax_total, 2)
        gross_interest = gross_total
        tax = tax_total

    net_payout = round(100.0 + net_profit, 2)
    eff_annual_pct = round((((100.0 + max(0.0, net_profit)) / 100.0) ** (1.0 / holding_years) - 1.0) * 100.0, 2)

    return BondComparisonOptionModel(
        bondCode=series.code,
        bondType=series.type,
        nativeDurationYears=series.durationYears,
        holdingYears=holding_years,
        isEarlyRedemption=is_early,
        grossInterestPerBondPLN=gross_interest,
        earlyRedemptionFeePerBondPLN=round(fee, 2),
        taxPerBondPLN=tax,
        netProfitPerBondPLN=net_profit,
        netPayoutPerBondPLN=net_payout,
        effectiveAnnualRatePct=eff_annual_pct,
    )


def parse_held_bond_code(details: str) -> Optional[Tuple[str, int, int]]:
    """
    Parses a bond series code like 'COI0730' or 'EDO1034' into (bond_type, maturity_month, maturity_year).
    """
    s = (details or "").strip().upper()
    m = re.search(r"([A-Z]{2,4})\s*(\d{2})(\d{2})", s)
    if m:
        b_type = m.group(1)
        mm = int(m.group(2))
        yy = int(m.group(3))
        if 1 <= mm <= 12:
            return (b_type, mm, 2000 + yy)
    return None


def calculate_bond_planner(
    holdings_rows: List[dict],
    settings: BondPlannerSettingsModel,
    ref_date: Optional[date] = None,
    reference_month: Optional[int] = None,
) -> BondPlannerResponse:
    if ref_date is None:
        ref_date = datetime.now(timezone.utc).date()

    issue_year = ref_date.year
    issue_month = reference_month if (reference_month and 1 <= reference_month <= 12) else ref_date.month

    market_raw = get_bond_market_data(ref_date)
    live_cpi = float(market_raw["liveInflationRatePct"])
    live_nbp = float(market_raw["liveNbpReferenceRatePct"])

    eff_cpi = settings.customInflationRatePct if settings.customInflationRatePct is not None else live_cpi
    eff_nbp = settings.customNbpRatePct if settings.customNbpRatePct is not None else live_nbp

    all_series = build_offer_series_for_month(issue_year, issue_month, market_raw["scrapedSpecs"])
    eligible_series = [s for s in all_series if (settings.includeFamilyBonds or not s.isFamilyBond)]

    market_model = BondMarketConditionsModel(
        referenceDate=ref_date.strftime("%Y-%m-%d"),
        issueMonth=issue_month,
        issueYear=issue_year,
        issueMonthLabel=f"{issue_month:02d}.{issue_year}",
        liveInflationRatePct=live_cpi,
        liveNbpReferenceRatePct=live_nbp,
        effectiveInflationRatePct=eff_cpi,
        effectiveNbpReferenceRatePct=eff_nbp,
        sourceUrl=market_raw["sourceUrl"],
        availableSeries=eligible_series,
    )

    # Aggregate held bonds by (maturity_year, maturity_month)
    held_by_ym: Dict[Tuple[int, int], List[dict]] = {}
    total_held_nominal = 0.0
    total_held_actual = 0.0

    for row in holdings_rows:
        nom = round(float(row.get("nominal_amount_pln") or 0.0), 2)
        act = round(float(row.get("amount_pln") or nom), 2)
        details = str(row.get("details") or "").strip().upper()
        total_held_nominal = round(total_held_nominal + nom, 2)
        total_held_actual = round(total_held_actual + act, 2)

        parsed = parse_held_bond_code(details)
        if parsed:
            b_type, mat_m, mat_y = parsed
            held_by_ym.setdefault((mat_y, mat_m), []).append(
                {
                    "code": details,
                    "type": b_type,
                    "maturityMonth": mat_m,
                    "maturityYear": mat_y,
                    "nominalPLN": nom,
                    "actualPLN": act,
                }
            )

    target_monthly = max(0.0, round(settings.targetMonthlyNominal, 2))
    horizon_years = max(1, min(12, settings.horizonYears))
    remaining_budget = max(0.0, math.floor(settings.investmentBudget / 100.0) * 100.0)

    # Step 1: Evaluate target month `issue_month` continuity across upcoming years: issue_year + 1 .. issue_year + horizon_years
    continuity_slots: List[YearlyContinuitySlotModel] = []
    purchase_map: Dict[str, dict] = {}
    proposed_by_ym: Dict[Tuple[int, int], float] = {}

    total_required_continuity = 0.0
    budget_allocated_continuity = 0.0
    covered_years_count = 0

    for t in range(1, horizon_years + 1):
        target_year = issue_year + t
        ym = (target_year, issue_month)
        existing_slices = held_by_ym.get(ym, [])
        existing_nom = round(sum(s["nominalPLN"] for s in existing_slices), 2)
        existing_act = round(sum(s["actualPLN"] for s in existing_slices), 2)

        raw_shortfall = max(0.0, round(target_monthly - existing_nom, 2))
        # Round shortfall up to nearest 100 PLN (1 bond = 100 PLN)
        shortfall_nom = math.ceil(raw_shortfall / 100.0) * 100.0 if raw_shortfall > 0 else 0.0
        total_required_continuity = round(total_required_continuity + shortfall_nom, 2)

        # Rank all eligible bond series with durationYears >= t
        options: List[BondComparisonOptionModel] = []
        for s in eligible_series:
            sim = simulate_bond_holding_return(s, t, eff_cpi, eff_nbp)
            if sim is not None:
                options.append(sim)

        # Sort by highest net profit per bond, then prefer native maturity (non-early redemption) on ties
        options.sort(key=lambda o: (o.netProfitPerBondPLN, not o.isEarlyRedemption, -o.nativeDurationYears), reverse=True)
        best_opt = options[0] if options else None

        allocated_nom = 0.0
        if shortfall_nom > 0 and remaining_budget >= 100.0 and best_opt is not None:
            allocated_nom = min(remaining_budget, shortfall_nom)
            remaining_budget = round(remaining_budget - allocated_nom, 2)
            budget_allocated_continuity = round(budget_allocated_continuity + allocated_nom, 2)

        allocated_units = int(round(allocated_nom / 100.0))
        unfunded_gap = max(0.0, round(shortfall_nom - allocated_nom, 2))

        if existing_nom + allocated_nom >= target_monthly and target_monthly > 0:
            covered_years_count += 1

        proposed_by_ym[ym] = round(proposed_by_ym.get(ym, 0.0) + allocated_nom, 2)

        slot_net_profit = round(allocated_units * best_opt.netProfitPerBondPLN, 2) if best_opt else 0.0
        slot_payout = round(allocated_nom + slot_net_profit, 2)
        target_label = f"{issue_month:02d}.{target_year}"

        if allocated_units > 0 and best_opt is not None:
            series_obj = next(s for s in eligible_series if s.code == best_opt.bondCode)
            rec_entry = purchase_map.setdefault(
                best_opt.bondCode,
                {
                    "series": series_obj,
                    "totalUnits": 0,
                    "totalNominalPLN": 0.0,
                    "requiredContinuityNominalPLN": 0.0,
                    "surplusNominalPLN": 0.0,
                    "projectedTotalNetProfitPLN": 0.0,
                    "weightedRateSum": 0.0,
                    "allocations": [],
                },
            )
            rec_entry["totalUnits"] += allocated_units
            rec_entry["totalNominalPLN"] = round(rec_entry["totalNominalPLN"] + allocated_nom, 2)
            rec_entry["requiredContinuityNominalPLN"] = round(rec_entry["requiredContinuityNominalPLN"] + allocated_nom, 2)
            rec_entry["projectedTotalNetProfitPLN"] = round(rec_entry["projectedTotalNetProfitPLN"] + slot_net_profit, 2)
            rec_entry["weightedRateSum"] += allocated_nom * best_opt.effectiveAnnualRatePct
            rec_entry["allocations"].append(
                PurchaseAllocationItemModel(
                    targetLabel=target_label,
                    targetYear=target_year,
                    targetMonth=issue_month,
                    holdingYears=t,
                    units=allocated_units,
                    nominalPLN=allocated_nom,
                    isEarlyRedemption=best_opt.isEarlyRedemption,
                    isSurplus=False,
                    projectedNetProfitPLN=slot_net_profit,
                )
            )

        continuity_slots.append(
            YearlyContinuitySlotModel(
                id=f"{target_year}-{issue_month:02d}",
                year=target_year,
                month=issue_month,
                label=target_label,
                holdingYears=t,
                targetNominalPLN=target_monthly,
                existingNominalPLN=existing_nom,
                existingActualPLN=existing_act,
                shortfallNominalPLN=shortfall_nom,
                allocatedNewNominalPLN=allocated_nom,
                allocatedUnits=allocated_units,
                unfundedGapNominalPLN=unfunded_gap,
                recommendedBondCode=best_opt.bondCode if best_opt else None,
                recommendedBondType=best_opt.bondType if best_opt else None,
                isEarlyRedemption=best_opt.isEarlyRedemption if best_opt else False,
                earlyRedemptionTargetLabel=target_label if (best_opt and best_opt.isEarlyRedemption) else None,
                projectedNetProfitPLN=slot_net_profit,
                projectedTotalPayoutPLN=slot_payout,
                effectiveAnnualRatePct=best_opt.effectiveAnnualRatePct if best_opt else 0.0,
                heldBonds=[f"{s['code']} ({int(s['nominalPLN'])} PLN)" for s in existing_slices],
                alternatives=options[:4],
            )
        )

    # Step 2: Surplus Budget Optimization
    # If remaining_budget >= 100 PLN after filling all required cash flow shortfalls for the target month across horizon_years,
    # allocate the surplus to the highest-CAGR bond held to its native maturity (or max horizon).
    budget_allocated_surplus = 0.0
    if remaining_budget >= 100.0 and eligible_series:
        surplus_candidates: List[Tuple[BondComparisonOptionModel, BondOfferSeriesModel]] = []
        for s in eligible_series:
            if s.durationYears >= 1:
                sim = simulate_bond_holding_return(s, s.durationYears, eff_cpi, eff_nbp)
                if sim:
                    surplus_candidates.append((sim, s))

        surplus_candidates.sort(key=lambda pair: (pair[0].effectiveAnnualRatePct, pair[0].netProfitPerBondPLN), reverse=True)
        if surplus_candidates:
            best_surplus_sim, best_surplus_series = surplus_candidates[0]
            surplus_units = int(round(remaining_budget / 100.0))
            surplus_nom = round(surplus_units * 100.0, 2)
            surplus_profit = round(surplus_units * best_surplus_sim.netProfitPerBondPLN, 2)
            budget_allocated_surplus = surplus_nom
            remaining_budget = 0.0

            mat_ym = (best_surplus_series.maturityYear, best_surplus_series.maturityMonth)
            proposed_by_ym[mat_ym] = round(proposed_by_ym.get(mat_ym, 0.0) + surplus_nom, 2)

            rec_entry = purchase_map.setdefault(
                best_surplus_series.code,
                {
                    "series": best_surplus_series,
                    "totalUnits": 0,
                    "totalNominalPLN": 0.0,
                    "requiredContinuityNominalPLN": 0.0,
                    "surplusNominalPLN": 0.0,
                    "projectedTotalNetProfitPLN": 0.0,
                    "weightedRateSum": 0.0,
                    "allocations": [],
                },
            )
            rec_entry["totalUnits"] += surplus_units
            rec_entry["totalNominalPLN"] = round(rec_entry["totalNominalPLN"] + surplus_nom, 2)
            rec_entry["surplusNominalPLN"] = round(rec_entry["surplusNominalPLN"] + surplus_nom, 2)
            rec_entry["projectedTotalNetProfitPLN"] = round(rec_entry["projectedTotalNetProfitPLN"] + surplus_profit, 2)
            rec_entry["weightedRateSum"] += surplus_nom * best_surplus_sim.effectiveAnnualRatePct
            rec_entry["allocations"].append(
                PurchaseAllocationItemModel(
                    targetLabel=best_surplus_series.maturityLabel,
                    targetYear=best_surplus_series.maturityYear,
                    targetMonth=best_surplus_series.maturityMonth,
                    holdingYears=best_surplus_series.durationYears,
                    units=surplus_units,
                    nominalPLN=surplus_nom,
                    isEarlyRedemption=False,
                    isSurplus=True,
                    projectedNetProfitPLN=surplus_profit,
                )
            )

    purchase_recommendations: List[BondPurchaseRecommendationModel] = []
    total_projected_profit = 0.0
    for code, item in purchase_map.items():
        s: BondOfferSeriesModel = item["series"]
        tot_nom = item["totalNominalPLN"]
        avg_rate = round(item["weightedRateSum"] / tot_nom, 2) if tot_nom > 0 else 0.0
        total_projected_profit = round(total_projected_profit + item["projectedTotalNetProfitPLN"], 2)
        purchase_recommendations.append(
            BondPurchaseRecommendationModel(
                id=code,
                bondCode=code,
                bondType=s.type,
                bondName=s.name,
                nativeMaturityLabel=s.maturityLabel,
                totalUnits=item["totalUnits"],
                totalNominalPLN=tot_nom,
                requiredContinuityNominalPLN=item["requiredContinuityNominalPLN"],
                surplusNominalPLN=item["surplusNominalPLN"],
                projectedTotalNetProfitPLN=item["projectedTotalNetProfitPLN"],
                effectiveAnnualRatePct=avg_rate,
                firstYearRatePct=s.firstYearRatePct,
                marginPct=s.marginPct,
                earlyRedemptionFeePLN=s.earlyRedemptionFeePLN,
                allocations=item["allocations"],
            )
        )

    # Sort purchase recommendations by continuity priority then total amount
    purchase_recommendations.sort(key=lambda r: (r.requiredContinuityNominalPLN > 0, r.totalNominalPLN), reverse=True)

    # Step 3: Build 12-Month x Horizon-Year Maturity Calendar Grid
    calendar_rows: List[YearlyMaturityRowModel] = []
    for y in range(issue_year + 1, issue_year + horizon_years + 1):
        month_cells: List[MonthlyMaturityCellModel] = []
        yr_existing = 0.0
        yr_proposed = 0.0
        yr_target = 0.0

        for m in range(1, 13):
            ym = (y, m)
            slices = held_by_ym.get(ym, [])
            ex_nom = round(sum(s["nominalPLN"] for s in slices), 2)
            prop_nom = round(proposed_by_ym.get(ym, 0.0), 2)
            combined_nom = round(ex_nom + prop_nom, 2)
            shortfall = max(0.0, round(target_monthly - combined_nom, 2))
            surplus = max(0.0, round(combined_nom - target_monthly, 2))
            cov_pct = round((combined_nom / target_monthly) * 100.0, 1) if target_monthly > 0 else (100.0 if combined_nom > 0 else 0.0)

            yr_existing = round(yr_existing + ex_nom, 2)
            yr_proposed = round(yr_proposed + prop_nom, 2)
            yr_target = round(yr_target + target_monthly, 2)

            month_cells.append(
                MonthlyMaturityCellModel(
                    id=f"{y:04d}-{m:02d}",
                    year=y,
                    month=m,
                    monthShortLabel=MONTH_NAMES_SHORT[m - 1],
                    label=f"{m:02d}.{y}",
                    targetNominalPLN=target_monthly,
                    existingNominalPLN=ex_nom,
                    proposedNominalPLN=prop_nom,
                    shortfallNominalPLN=shortfall,
                    surplusNominalPLN=surplus,
                    coveragePct=cov_pct,
                    isCurrentIssueMonth=(m == issue_month),
                    heldBonds=[
                        HeldBondSliceModel(code=s["code"], nominalPLN=s["nominalPLN"], actualPLN=s["actualPLN"])
                        for s in slices
                    ],
                )
            )

        calendar_rows.append(
            YearlyMaturityRowModel(
                id=str(y),
                year=y,
                totalExistingNominalPLN=yr_existing,
                totalProposedNominalPLN=yr_proposed,
                totalTargetNominalPLN=yr_target,
                months=month_cells,
            )
        )

    # Step 4: Existing Portfolio Early Termination ("Przedterminowy Wykup") Advisor
    # Find held bond positions that have surplus over their maturity month's target (or mature beyond the horizon)
    # and recommend which existing bonds can be early redeemed to cover upcoming shortfalls without breaking target continuity.
    early_redemption_recs: List[EarlyRedemptionRecommendationModel] = []
    candidate_pool: List[dict] = []
    horizon_end_year = issue_year + horizon_years

    for (mat_y, mat_m), slices in sorted(held_by_ym.items()):
        if (mat_y, mat_m) <= (issue_year, issue_month):
            continue
        month_total_nom = sum(s["nominalPLN"] for s in slices)
        is_beyond_horizon = mat_y > horizon_end_year
        # If the bond matures within our planning horizon, only the excess above target_monthly is safe to early-redeem.
        # If the bond matures beyond our planning horizon, its entire nominal value can act as a long-dated reserve.
        surplus_in_month = month_total_nom if is_beyond_horizon else max(0.0, month_total_nom - target_monthly)
        if surplus_in_month < 100.0:
            continue

        for s in slices:
            b_type = s["type"]
            dur = BOND_DURATION_YEARS.get(b_type, 4)
            issue_y = mat_y - dur if dur > 0 else mat_y
            spec_fee = next((sp["earlyRedemptionFeePLN"] for sp in DEFAULT_BOND_SPECS if sp["type"] == b_type), 2.0)
            avail_surplus = min(s["nominalPLN"], surplus_in_month)
            surplus_in_month = max(0.0, surplus_in_month - avail_surplus)
            if avail_surplus >= 100.0:
                candidate_pool.append(
                    {
                        "code": s["code"],
                        "type": b_type,
                        "maturityYear": mat_y,
                        "maturityMonth": mat_m,
                        "issueYear": issue_y,
                        "availableRedeemablePLN": math.floor(avail_surplus / 100.0) * 100.0,
                        "isBeyondHorizon": is_beyond_horizon,
                        "feePerBondPLN": spec_fee,
                    }
                )

    # Check upcoming months (prioritizing the current issue month ladder first, then upcoming 12 months) that still have a shortfall
    shortfall_cells: List[MonthlyMaturityCellModel] = []
    for row in calendar_rows:
        for cell in row.months:
            if cell.shortfallNominalPLN <= 0:
                continue
            months_ahead = (cell.year - issue_year) * 12 + (cell.month - issue_month)
            if cell.isCurrentIssueMonth or (1 <= months_ahead <= 12):
                shortfall_cells.append(cell)

    shortfall_cells.sort(key=lambda c: (not c.isCurrentIssueMonth, c.year, c.month))

    for cell in shortfall_cells:
        needed_pln = math.ceil(cell.shortfallNominalPLN / 100.0) * 100.0
        # Filter candidates that were issued before (cell.year, cell.month) and mature strictly after (cell.year, cell.month)
        eligible_cands = [
            c
            for c in candidate_pool
            if (c["maturityYear"], c["maturityMonth"]) > (cell.year, cell.month)
            and (c["issueYear"], c["maturityMonth"]) < (cell.year, cell.month)
            and c["availableRedeemablePLN"] >= 100.0
        ]
        if not eligible_cands:
            continue

        # Prioritize: 1) anniversary month matches cell.month, 2) true surplus within horizon vs beyond-horizon reserve, 3) lowest fee per bond, 4) furthest maturity
        eligible_cands.sort(
            key=lambda c: (
                c["maturityMonth"] == cell.month,
                not c["isBeyondHorizon"],
                -c["feePerBondPLN"],
                c["maturityYear"],
            ),
            reverse=True,
        )

        for cand in eligible_cands:
            if needed_pln < 100.0:
                break
            redeem_pln = min(needed_pln, cand["availableRedeemablePLN"])
            if redeem_pln < 100.0:
                continue

            redeem_units = int(round(redeem_pln / 100.0))
            est_fee = round(redeem_units * cand["feePerBondPLN"], 2)
            anniv_match = cand["maturityMonth"] == cell.month

            cand["availableRedeemablePLN"] = round(cand["availableRedeemablePLN"] - redeem_pln, 2)
            needed_pln = round(needed_pln - redeem_pln, 2)

            reason_parts = []
            if not cand["isBeyondHorizon"]:
                reason_parts.append(f"Surplus above {cand['maturityMonth']:02d}.{cand['maturityYear']} target")
            else:
                reason_parts.append(f"Beyond {horizon_years}Y horizon ({cand['maturityMonth']:02d}.{cand['maturityYear']})")
            if anniv_match:
                reason_parts.append("Matches annual interest anniversary month")
            reason_parts.append(f"Early exit fee: {cand['feePerBondPLN']:.2f} PLN/bond")

            early_redemption_recs.append(
                EarlyRedemptionRecommendationModel(
                    id=f"er_{cell.label}_{cand['code']}",
                    targetYear=cell.year,
                    targetMonth=cell.month,
                    targetLabel=cell.label,
                    shortfallNominalPLN=cell.shortfallNominalPLN,
                    sourceBondCode=cand["code"],
                    sourceBondType=cand["type"],
                    sourceMaturityLabel=f"{cand['maturityMonth']:02d}.{cand['maturityYear']}",
                    recommendedRedeemUnits=redeem_units,
                    recommendedRedeemNominalPLN=redeem_pln,
                    estimatedFeePLN=est_fee,
                    isAnniversaryMonthMatch=anniv_match,
                    reason=" • ".join(reason_parts),
                )
            )

    unfunded_total = max(0.0, round(total_required_continuity - budget_allocated_continuity, 2))
    summary = BondPlannerSummaryModel(
        totalHeldBondsNominalPLN=total_held_nominal,
        totalHeldBondsActualPLN=total_held_actual,
        currentMonthTargetSeriesCount=horizon_years,
        currentMonthCoveredYearsCount=covered_years_count,
        totalRequiredForContinuityPLN=total_required_continuity,
        budgetAllocatedToContinuityPLN=budget_allocated_continuity,
        budgetAllocatedToSurplusPLN=budget_allocated_surplus,
        unfundedContinuityGapPLN=unfunded_total,
        projectedTotalNetProfitFromBudgetPLN=total_projected_profit,
    )

    return BondPlannerResponse(
        settings=settings,
        market=market_model,
        summary=summary,
        yearlyContinuitySlots=continuity_slots,
        purchaseRecommendations=purchase_recommendations,
        earlyRedemptionRecommendations=early_redemption_recs,
        maturityCalendar=calendar_rows,
    )
