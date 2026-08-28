from nse import NSE
from datetime import datetime, timedelta, timezone
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# Connect to Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

TOP_N_BY_VALUE = 150  # how many top-traded stocks get ongoing history tracking

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


def get_sector(ticker):
    return SECTOR_MAP.get(ticker, "Other")


def get_held_tickers():
    docs = db.collection("investments").stream()
    tickers = {doc.to_dict().get("ticker") for doc in docs if doc.to_dict().get("ticker")}
    print(f"Held tickers: {tickers or '(none yet)'}")
    return tickers


HELD_TICKERS = get_held_tickers()

bhav_file = None
used_date = None

with NSE(download_folder="./") as nse:
    for days_back in range(0, 7):
        try_date = datetime.now() - timedelta(days=days_back)
        try:
            print(f"Trying {try_date.strftime('%d-%m-%Y')}...")
            bhav_file = nse.equityBhavcopy(date=try_date)
            used_date = try_date
            print(f"Found data for {try_date.strftime('%d-%m-%Y')}")
            break
        except RuntimeError as e:
            print(f"  Not available: {e}")
            continue

    if bhav_file is None:
        print("Could not find Bhavcopy data for the last 7 days. Stopping.")
    else:
        df = pd.read_csv(bhav_file)

        symbol_col = "TckrSymb" if "TckrSymb" in df.columns else "SYMBOL"
        close_col = "ClsPric" if "ClsPric" in df.columns else "CLOSE_PRICE"
        prev_close_col = "PrvsClsgPric" if "PrvsClsgPric" in df.columns else "PREV_CLOSE"
        series_col = "SctySrs" if "SctySrs" in df.columns else ("SERIES" if "SERIES" in df.columns else None)
        value_col = "TtlTrfVal" if "TtlTrfVal" in df.columns else ("TOTTRDVAL" if "TOTTRDVAL" in df.columns else None)

        print(f"Using columns: {symbol_col} / {close_col} / {prev_close_col} / series={series_col} / value={value_col}")

        if series_col:
            df[series_col] = df[series_col].astype(str).str.strip()
            df = df[df[series_col] == "EQ"]
        print(f"Total equity stocks to save: {len(df)}")

        # Recompute today's top-N most-traded tickers fresh each day -- keeps
        # history tracking focused on what's actually relevant/active,
        # adapting automatically as market activity shifts.
        if value_col:
            top_tickers = set(
                df.sort_values(value_col, ascending=False)
                .head(TOP_N_BY_VALUE)[symbol_col].astype(str).str.strip()
            )
        else:
            top_tickers = set(df[symbol_col].astype(str).str.strip().head(TOP_N_BY_VALUE))

        TRACK_HISTORY_FOR = top_tickers | HELD_TICKERS
        print(f"Tracking history for {len(TRACK_HISTORY_FOR)} tickers "
              f"({len(top_tickers)} top-traded + {len(HELD_TICKERS)} held).")

        date_str = used_date.strftime("%Y-%m-%d")
        batch = db.batch()
        batch_count = 0
        total_saved = 0
        history_saved = 0

        for _, row in df.iterrows():
            ticker = str(row[symbol_col]).strip()
            try:
                close_price = float(row[close_col])
            except (ValueError, TypeError):
                continue

            change_pct = None
            if prev_close_col in df.columns:
                try:
                    prev_close = float(row[prev_close_col])
                    if prev_close > 0:
                        change_pct = ((close_price - prev_close) / prev_close) * 100
                except (ValueError, TypeError):
                    change_pct = None

            sector = get_sector(ticker)

            # --- stockPrices: ALL equity stocks, overwritten daily (powers search) ---
            doc_data = {
                "ticker": ticker,
                "price": close_price,
                "sector": sector,
                "dataDate": date_str,
                "updatedAt": datetime.now(timezone.utc),
            }
            if change_pct is not None:
                doc_data["changePct"] = round(change_pct, 2)

            batch.set(db.collection("stockPrices").document(ticker), doc_data)
            batch_count += 1
            total_saved += 1

            # --- priceHistory: top-150-traded + anything actually held ---
            if ticker in TRACK_HISTORY_FOR:
                history_id = f"{ticker}_{date_str}"
                batch.set(db.collection("priceHistory").document(history_id), {
                    "ticker": ticker,
                    "price": close_price,
                    "sector": sector,
                    "date": date_str,
                })
                batch_count += 1
                history_saved += 1

            if batch_count >= 500:
                batch.commit()
                print(f"  Committed batch (total saved so far: {total_saved})")
                batch = db.batch()
                batch_count = 0

        if batch_count > 0:
            batch.commit()
            print(f"  Committed final batch of {batch_count}")

        print(f"Done. Saved {total_saved} current prices, "
              f"{history_saved} history records for {date_str}.")