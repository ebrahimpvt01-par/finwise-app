"""
One-time script: backfills priceHistory for the ~150 most actively traded
NSE stocks (by trading value) plus anything currently held in investments.
Run ONCE from C:\\finwise-scripts.
"""
from nse import NSE
from datetime import datetime, timedelta
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

DAYS_TO_BACKFILL = 45
TOP_N_BY_VALUE = 150

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

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


def get_held_tickers():
    docs = db.collection("investments").stream()
    return {doc.to_dict().get("ticker") for doc in docs if doc.to_dict().get("ticker")}


def load_bhavcopy(nse, days_back):
    """Find the most recent available Bhavcopy starting from `days_back` days ago."""
    for extra in range(0, 7):
        try_date = datetime.now() - timedelta(days=days_back + extra)
        try:
            path = nse.equityBhavcopy(date=try_date)
            return path, try_date
        except RuntimeError:
            continue
    return None, None


held = get_held_tickers()
print(f"Held tickers (always included): {held or '(none yet)'}")

with NSE(download_folder="./") as nse:
    # Step 1: figure out today's top N most-traded tickers, used as a
    # FIXED set across the whole backfill window (keeps each stock's
    # chart continuous instead of gaining/losing tickers day to day).
    latest_path, latest_date = load_bhavcopy(nse, 0)
    if latest_path is None:
        print("Could not fetch a recent Bhavcopy to determine top tickers. Stopping.")
        raise SystemExit

    latest_df = pd.read_csv(latest_path)
    symbol_col = "TckrSymb" if "TckrSymb" in latest_df.columns else "SYMBOL"
    series_col = "SctySrs" if "SctySrs" in latest_df.columns else ("SERIES" if "SERIES" in latest_df.columns else None)
    value_col = "TtlTrfVal" if "TtlTrfVal" in latest_df.columns else ("TOTTRDVAL" if "TOTTRDVAL" in latest_df.columns else None)

    if series_col:
        latest_df[series_col] = latest_df[series_col].astype(str).str.strip()
        latest_df = latest_df[latest_df[series_col] == "EQ"]

    if value_col:
        top_tickers = set(
            latest_df.sort_values(value_col, ascending=False)
            .head(TOP_N_BY_VALUE)[symbol_col].astype(str).str.strip()
        )
    else:
        print("No trading-value column found -- falling back to first 150 alphabetically.")
        top_tickers = set(latest_df[symbol_col].astype(str).str.strip().head(TOP_N_BY_VALUE))

    TRACK_TICKERS = top_tickers | held
    print(f"Tracking history for {len(TRACK_TICKERS)} tickers "
          f"({len(top_tickers)} top-traded + {len(held)} held).")

    # Step 2: walk backwards through the days, writing history only for
    # tickers in TRACK_TICKERS.
    close_col = "ClsPric" if "ClsPric" in latest_df.columns else "CLOSE_PRICE"
    saved = 0
    skipped_days = 0

    for days_back in range(0, DAYS_TO_BACKFILL):
        target_date = datetime.now() - timedelta(days=days_back)
        try:
            bhav_file = nse.equityBhavcopy(date=target_date)
        except RuntimeError:
            skipped_days += 1
            continue

        df = pd.read_csv(bhav_file)
        date_str = target_date.strftime("%Y-%m-%d")
        batch = db.batch()
        batch_count = 0

        for ticker in TRACK_TICKERS:
            row = df[df[symbol_col] == ticker]
            if row.empty:
                continue
            try:
                close_price = float(row.iloc[0][close_col])
            except (ValueError, TypeError):
                continue

            history_id = f"{ticker}_{date_str}"
            batch.set(db.collection("priceHistory").document(history_id), {
                "ticker": ticker,
                "price": close_price,
                "sector": SECTOR_MAP.get(ticker, "Other"),
                "date": date_str,
            })
            batch_count += 1
            saved += 1

            if batch_count >= 500:
                batch.commit()
                batch = db.batch()
                batch_count = 0

        if batch_count > 0:
            batch.commit()

        print(f"Backfilled {date_str} ({days_back + 1}/{DAYS_TO_BACKFILL})")

print(f"\nDone. Saved {saved} history records across {len(TRACK_TICKERS)} tickers. "
      f"Skipped {skipped_days} non-trading days.")