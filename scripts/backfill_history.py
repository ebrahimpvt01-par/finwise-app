"""
One-time script: backfills priceHistory with the last N days of Bhavcopy data,
so charts have real history to show right away instead of waiting weeks.
Run this ONCE from C:\\finwise-scripts (same folder as fetch_prices.py).
"""
from nse import NSE
from datetime import datetime, timedelta
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

DAYS_TO_BACKFILL = 60  # ~2 months of trading history

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

WATCHLIST = [
    "RELIANCE", "TCS", "INFY", "WIPRO", "HCLTECH",
    "HDFCBANK", "ICICIBANK", "SBIN", "KOTAKBANK", "AXISBANK",
    "ITC", "HINDUNILVR", "NESTLEIND",
    "BHARTIARTL", "LT", "MARUTI", "TATAMOTORS",
    "SUNPHARMA", "TITAN", "ASIANPAINT", "BAJFINANCE",
]

SECTOR_MAP = {
    "RELIANCE": "Energy", "TCS": "IT", "INFY": "IT", "WIPRO": "IT", "HCLTECH": "IT",
    "HDFCBANK": "Banking", "ICICIBANK": "Banking", "SBIN": "Banking",
    "KOTAKBANK": "Banking", "AXISBANK": "Banking",
    "ITC": "FMCG", "HINDUNILVR": "FMCG", "NESTLEIND": "FMCG",
    "BHARTIARTL": "Telecom", "LT": "Infrastructure",
    "MARUTI": "Automobile", "TATAMOTORS": "Automobile",
    "SUNPHARMA": "Pharma", "TITAN": "Consumer Goods",
    "ASIANPAINT": "Consumer Goods", "BAJFINANCE": "Financial Services",
}

saved_count = 0
skipped_count = 0

with NSE(download_folder="./") as nse:
    for days_back in range(1, DAYS_TO_BACKFILL + 1):
        target_date = datetime.now() - timedelta(days=days_back)
        try:
            bhav_file = nse.equityBhavcopy(date=target_date)
        except RuntimeError:
            skipped_count += 1
            continue  # weekend/holiday - no file, just skip silently

        df = pd.read_csv(bhav_file)
        symbol_col = "TckrSymb" if "TckrSymb" in df.columns else "SYMBOL"
        close_col = "ClsPric" if "ClsPric" in df.columns else "CLOSE_PRICE"
        date_str = target_date.strftime("%Y-%m-%d")

        for ticker in WATCHLIST:
            row = df[df[symbol_col] == ticker]
            if not row.empty:
                close_price = float(row.iloc[0][close_col])
                history_id = f"{ticker}_{date_str}"
                db.collection("priceHistory").document(history_id).set({
                    "ticker": ticker,
                    "price": close_price,
                    "sector": SECTOR_MAP.get(ticker, "Other"),
                    "date": date_str,
                })
                saved_count += 1

        print(f"Backfilled {date_str} ({days_back}/{DAYS_TO_BACKFILL})")

print(f"\nDone. Saved {saved_count} price records, skipped {skipped_count} non-trading days.")