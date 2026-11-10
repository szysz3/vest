import os
import tempfile
import unittest
from datetime import date
from pathlib import Path
from fastapi.testclient import TestClient

tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DB_PATH"] = tmp_db.name

import sys
sys.path.insert(0, str(Path(__file__).parent))

from app import app, init_db, get_db
from bond_planner import (
    BOND_MARKET_CACHE,
    BondPlannerSettingsModel,
    build_offer_series_for_month,
    calculate_bond_planner,
    simulate_bond_holding_return,
)


class TestBondPlanner(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        cls.client = TestClient(app)
        # Seed deterministic market cache for unit tests
        BOND_MARKET_CACHE["2026-11-10"] = {
            "referenceDate": "2026-11-10",
            "liveNbpReferenceRatePct": 3.75,
            "liveInflationRatePct": 2.50,
            "scrapedSpecs": {},
            "sourceUrl": "https://www.obligacjeskarbowe.pl",
        }

    @classmethod
    def tearDownClass(cls):
        try:
            os.unlink(tmp_db.name)
        except OSError:
            pass

    def test_bond_simulation_math_and_early_redemption(self):
        series_list = build_offer_series_for_month(2026, 11, {})
        by_type = {s.type: s for s in series_list}

        # 3-year TOS held to maturity (3 years at 4.40% fixed, compounded annually)
        tos_3y = simulate_bond_holding_return(by_type["TOS"], 3, inflation_rate_pct=2.5, nbp_rate_pct=3.75)
        self.assertIsNotNone(tos_3y)
        self.assertFalse(tos_3y.isEarlyRedemption)
        self.assertEqual(tos_3y.earlyRedemptionFeePerBondPLN, 0.0)
        self.assertAlmostEqual(tos_3y.grossInterestPerBondPLN, 13.79, places=1)
        self.assertGreater(tos_3y.netProfitPerBondPLN, 11.0)

        # 10-year EDO early redeemed after 1 year vs 1-year ROR
        edo_1y = simulate_bond_holding_return(by_type["EDO"], 1, inflation_rate_pct=2.5, nbp_rate_pct=3.75)
        self.assertTrue(edo_1y.isEarlyRedemption)
        self.assertEqual(edo_1y.earlyRedemptionFeePerBondPLN, 3.00)
        # Gross interest = 5.35 PLN, fee = 3.00 PLN, taxable = 2.35 PLN, net = 1.90 PLN
        self.assertAlmostEqual(edo_1y.grossInterestPerBondPLN, 5.35, places=2)
        self.assertAlmostEqual(edo_1y.netProfitPerBondPLN, 1.90, places=2)

        # Under higher inflation (e.g. 8%), 10-year EDO early redeemed after 2 years (Year 1: 5.35%, Year 2: 8%+2%=10%, minus 3 PLN fee)
        # beats 2-year DOR (at 3.75% NBP)
        edo_2y_high_cpi = simulate_bond_holding_return(by_type["EDO"], 2, inflation_rate_pct=8.0, nbp_rate_pct=3.75)
        dor_2y_high_cpi = simulate_bond_holding_return(by_type["DOR"], 2, inflation_rate_pct=8.0, nbp_rate_pct=3.75)
        self.assertGreater(edo_2y_high_cpi.netProfitPerBondPLN, dor_2y_high_cpi.netProfitPerBondPLN)

    def test_continuity_and_surplus_budget_allocation(self):
        # User wants 3,000 PLN/month nominal for 3 years (11.2027, 11.2028, 11.2029)
        # User already holds 1,000 PLN of COI1127 (maturing 11.2027) and 3,000 PLN of EDO1128 (maturing 11.2028)
        # So:
        # - 11.2027 needs 2,000 PLN
        # - 11.2028 needs 0 PLN (already has 3,000 PLN!)
        # - 11.2029 needs 3,000 PLN
        # Total continuity required = 5,000 PLN.
        # User has budget = 8,000 PLN -> 5,000 PLN goes to continuity, 3,000 PLN goes to surplus!
        holdings = [
            {"details": "COI1127", "nominal_amount_pln": 1000.0, "amount_pln": 1080.0},
            {"details": "EDO1128", "nominal_amount_pln": 3000.0, "amount_pln": 3400.0},
        ]
        settings = BondPlannerSettingsModel(
            targetMonthlyNominal=3000.0,
            horizonYears=3,
            investmentBudget=8000.0,
            includeFamilyBonds=False,
        )
        res = calculate_bond_planner(
            holdings_rows=holdings,
            settings=settings,
            ref_date=date(2026, 11, 10),
            reference_month=11,
        )

        self.assertEqual(res.summary.totalRequiredForContinuityPLN, 5000.0)
        self.assertEqual(res.summary.budgetAllocatedToContinuityPLN, 5000.0)
        self.assertEqual(res.summary.budgetAllocatedToSurplusPLN, 3000.0)
        self.assertEqual(res.summary.unfundedContinuityGapPLN, 0.0)
        self.assertEqual(res.summary.currentMonthCoveredYearsCount, 3)

        slot_2027 = next(s for s in res.yearlyContinuitySlots if s.year == 2027)
        self.assertEqual(slot_2027.existingNominalPLN, 1000.0)
        self.assertEqual(slot_2027.allocatedNewNominalPLN, 2000.0)

        slot_2028 = next(s for s in res.yearlyContinuitySlots if s.year == 2028)
        self.assertEqual(slot_2028.existingNominalPLN, 3000.0)
        self.assertEqual(slot_2028.allocatedNewNominalPLN, 0.0)

        # Verify surplus recommendation exists (3,000 PLN in EDO1136)
        surplus_recs = [r for r in res.purchaseRecommendations if r.surplusNominalPLN > 0]
        self.assertEqual(len(surplus_recs), 1)
        self.assertEqual(surplus_recs[0].surplusNominalPLN, 3000.0)
        self.assertEqual(surplus_recs[0].bondCode, "EDO1136")

    def test_early_redemption_recommendations_from_existing_portfolio(self):
        # User needs 3,000 PLN/month, has 0 budget to buy new bonds today,
        # holds 3,000 PLN of COI0728 (exact match for 07.2028 within 3Y horizon -> NO surplus, must NOT be cannibalized!)
        # and holds 9,000 PLN of EDO1134 (maturing beyond 3Y horizon and with 6,000 PLN surplus over 3,000 PLN target).
        holdings = [
            {"details": "COI0728", "nominal_amount_pln": 3000.0, "amount_pln": 3150.0},
            {"details": "EDO1134", "nominal_amount_pln": 9000.0, "amount_pln": 9800.0},
        ]
        settings = BondPlannerSettingsModel(
            targetMonthlyNominal=3000.0,
            horizonYears=3,
            investmentBudget=0.0,
            includeFamilyBonds=False,
        )
        res = calculate_bond_planner(
            holdings_rows=holdings,
            settings=settings,
            ref_date=date(2026, 11, 10),
            reference_month=11,
        )

        self.assertGreaterEqual(len(res.earlyRedemptionRecommendations), 2)
        first_er = res.earlyRedemptionRecommendations[0]
        self.assertEqual(first_er.targetLabel, "11.2027")
        self.assertEqual(first_er.sourceBondCode, "EDO1134")
        self.assertEqual(first_er.recommendedRedeemNominalPLN, 3000.0)
        self.assertTrue(first_er.isAnniversaryMonthMatch)
        # Ensure COI0728 was never cannibalized
        self.assertTrue(all(r.sourceBondCode != "COI0728" for r in res.earlyRedemptionRecommendations))

    def test_api_endpoints(self):
        # Update settings
        put_resp = self.client.put(
            "/api/bonds/planner/settings",
            json={
                "targetMonthlyNominal": 4000.0,
                "horizonYears": 5,
                "investmentBudget": 12000.0,
                "includeFamilyBonds": False,
                "customInflationRatePct": 3.5,
                "customNbpRatePct": 4.0,
            },
        )
        self.assertEqual(put_resp.status_code, 200)
        self.assertEqual(put_resp.json()["targetMonthlyNominal"], 4000.0)

        # Get planner response
        get_resp = self.client.get("/api/bonds/planner?reference_month=11")
        self.assertEqual(get_resp.status_code, 200)
        data = get_resp.json()
        self.assertEqual(data["settings"]["targetMonthlyNominal"], 4000.0)
        self.assertEqual(len(data["yearlyContinuitySlots"]), 5)
        self.assertEqual(len(data["maturityCalendar"]), 5)
        self.assertEqual(len(data["maturityCalendar"][0]["months"]), 12)


if __name__ == "__main__":
    unittest.main()
