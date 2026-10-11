import os
import tempfile
import unittest
from pathlib import Path
from fastapi.testclient import TestClient

# Set temp DB before importing app
tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DB_PATH"] = tmp_db.name

import sys
sys.path.insert(0, str(Path(__file__).parent))

from app import app, init_db, get_db, record_portfolio_snapshot


class TestPortfolioHistory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        cls.client = TestClient(app)

    def test_get_portfolio_history_structure(self):
        resp = self.client.get("/api/portfolio/history")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        # Check top-level keys
        self.assertIn("summary", data)
        self.assertIn("snapshots", data)
        self.assertIn("monthlySavings", data)
        self.assertIn("yearlySavings", data)

        # Check summary keys
        summary = data["summary"]
        self.assertIn("currentTotal", summary)
        self.assertIn("startingTotal", summary)
        self.assertIn("totalSaved", summary)
        self.assertIn("totalGrowthPct", summary)
        self.assertIn("monthlyAverageSaved", summary)
        self.assertIn("yearlyAverageSaved", summary)
        self.assertIn("currentMonthSaved", summary)
        self.assertIn("currentYearSaved", summary)

        # Check snapshots format
        self.assertGreater(len(data["snapshots"]), 0)
        s = data["snapshots"][0]
        self.assertIn("id", s)
        self.assertIn("date", s)
        self.assertIn("totalAmount", s)
        self.assertIn("nominalAmount", s)
        self.assertIn("amountSaved", s)

        # Check monthly savings format
        self.assertGreater(len(data["monthlySavings"]), 0)
        m = data["monthlySavings"][0]
        self.assertIn("id", m)
        self.assertIn("year", m)
        self.assertIn("month", m)
        self.assertIn("label", m)
        self.assertIn("shortLabel", m)
        self.assertIn("amount", m)

        # Check yearly savings format
        self.assertGreater(len(data["yearlySavings"]), 0)
        y = data["yearlySavings"][0]
        self.assertIn("id", y)
        self.assertIn("year", y)
        self.assertIn("label", y)
        self.assertIn("amount", y)

    def test_force_snapshot_and_fixed_asset_sync(self):
        # Create a cash fixed asset
        resp = self.client.post("/api/fixed-assets", json={
            "assetType": "cash",
            "details": "Emergency Fund Test",
            "amount": 25000.0,
            "currency": "PLN"
        })
        self.assertEqual(resp.status_code, 200)

        # Force a snapshot
        resp_snap = self.client.post("/api/portfolio/history/snapshot?date=2026-09-30")
        self.assertEqual(resp_snap.status_code, 200)

        # Verify history reflects updated snapshot
        resp_hist = self.client.get("/api/portfolio/history")
        self.assertEqual(resp_hist.status_code, 200)
        data = resp_hist.json()
        self.assertGreaterEqual(data["summary"]["currentTotal"], 25000.0)


if __name__ == "__main__":
    unittest.main()
