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

from app import app, init_db, get_gold_price, GOLD_PRICE_CACHE, TROY_OUNCE_IN_GRAMS


class TestGoldValuation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        cls.client = TestClient(app)

    def test_get_gold_price_pln_and_caching(self):
        price_oz, price_g, date_str = get_gold_price("PLN")
        self.assertGreater(price_g, 0)
        self.assertGreater(price_oz, 0)
        self.assertAlmostEqual(price_oz, price_g * TROY_OUNCE_IN_GRAMS, delta=0.1)
        self.assertEqual(len(date_str), 10)
        self.assertGreater(len(GOLD_PRICE_CACHE), 0)

    def test_get_gold_price_foreign_currency(self):
        price_oz_usd, price_g_usd, _ = get_gold_price("USD")
        price_oz_pln, _, _ = get_gold_price("PLN")
        self.assertGreater(price_oz_usd, 0)
        self.assertLess(price_oz_usd, price_oz_pln)

    def test_market_gold_price_endpoint(self):
        resp = self.client.get("/api/market/gold-price?currency=PLN")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["currency"], "PLN")
        self.assertGreater(data["pricePerGram"], 0)
        self.assertGreater(data["pricePerOz"], 0)

    def test_create_gold_fixed_asset_with_weight(self):
        payload = {
            "assetType": "gold",
            "details": "1 oz Krugerrand Bullion",
            "amount": 10000.0,
            "currency": "PLN",
            "weightOz": 1.0,
        }
        resp = self.client.post("/api/fixed-assets", json=payload)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        asset_id = data["id"]
        self.assertEqual(data["assetType"], "gold")
        self.assertEqual(data["weightOz"], 1.0)
        self.assertEqual(data["amount"], 10000.0)

        # Verify get_fixed_assets returns weightOz
        list_resp = self.client.get("/api/fixed-assets")
        self.assertEqual(list_resp.status_code, 200)
        items = list_resp.json()
        item = next((i for i in items if i["id"] == asset_id), None)
        self.assertIsNotNone(item)
        self.assertEqual(item["weightOz"], 1.0)

        # Verify update_fixed_asset updates weightOz
        update_payload = {
            "weightOz": 0.5,
            "amount": 5500.0,
        }
        put_resp = self.client.put(f"/api/fixed-assets/{asset_id}", json=update_payload)
        self.assertEqual(put_resp.status_code, 200)
        self.assertEqual(put_resp.json()["weightOz"], 0.5)
        self.assertEqual(put_resp.json()["amount"], 5500.0)

    def test_portfolio_details_gold_valuation(self):
        payload = {
            "assetType": "gold",
            "details": "1 oz Vienna Philharmonic",
            "amount": 10000.0,
            "currency": "PLN",
            "weightOz": 1.0,
        }
        create_resp = self.client.post("/api/fixed-assets", json=payload)
        self.assertEqual(create_resp.status_code, 200)

        resp = self.client.get("/api/portfolio/details")
        self.assertEqual(resp.status_code, 200)
        details = resp.json()

        gold_item = next((d for d in details if d["details"] == "1 oz Vienna Philharmonic"), None)
        self.assertIsNotNone(gold_item)
        self.assertEqual(gold_item["weightOz"], 1.0)
        self.assertEqual(gold_item["nominalAmount"], 10000.0)

        spot_oz, _, _ = get_gold_price("PLN")
        self.assertAlmostEqual(gold_item["totalAmount"], spot_oz, delta=0.1)
        self.assertAlmostEqual(gold_item["profitOrLoss"], spot_oz - 10000.0, delta=0.1)
        self.assertEqual(gold_item["profitOrLossPct"], round(((spot_oz - 10000.0) / 10000.0 * 100.0), 2))

    def test_portfolio_details_gold_without_purchase_price(self):
        payload = {
            "assetType": "gold",
            "details": "50g Cast Bar",
            "amount": 0.0,
            "currency": "PLN",
            "weightOz": 1.6075,
        }
        create_resp = self.client.post("/api/fixed-assets", json=payload)
        self.assertEqual(create_resp.status_code, 200)

        resp = self.client.get("/api/portfolio/details")
        self.assertEqual(resp.status_code, 200)
        details = resp.json()

        bar_item = next((d for d in details if d["details"] == "50g Cast Bar"), None)
        self.assertIsNotNone(bar_item)
        self.assertEqual(bar_item["weightOz"], 1.6075)
        self.assertEqual(bar_item["nominalAmount"], bar_item["totalAmount"])
        self.assertEqual(bar_item["profitOrLoss"], 0.0)
        self.assertEqual(bar_item["profitOrLossPct"], 0.0)


if __name__ == "__main__":
    unittest.main()
