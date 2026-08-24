from nse import NSE
from datetime import datetime, timedelta, timezone
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# Connect to Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

CURATED_WATCHLIST = [
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


def get_sector(ticker):
    return SECTOR_MAP.get(ticker, "Other")


def get_watchlist():
    investment_docs = db.collection("investments").stream()
    invested_tickers = set()
    for doc in investment_docs:
        data = doc.to_dict()
        ticker = data.get("ticker")
        if ticker:
            invested_tickers.add(ticker)

    combined = set(CURATED_WATCHLIST) | invested_tickers
    print(f"Watchlist: {len(combined)} tickers "
          f"({len(CURATED_WATCHLIST)} curated + {len(invested_tickers)} from investments)")
    return sorted(combined)


WATCHLIST = get_watchlist()

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

        print(f"Using columns: {symbol_col} / {close_col} / {prev_close_col}")
        date_str = used_date.strftime("%Y-%m-%d")

        for ticker in WATCHLIST:
            row = df[df[symbol_col] == ticker]
            if not row.empty:
                close_price = float(row.iloc[0][close_col])

                change_pct = None
                if prev_close_col in df.columns:
                    try:
                        prev_close = float(row.iloc[0][prev_close_col])
                        if prev_close > 0:
                            change_pct = ((close_price - prev_close) / prev_close) * 100
                    except (ValueError, TypeError):
                        change_pct = None

                sector = get_sector(ticker)

                # --- Current price (overwritten daily -- used for live gain/loss) ---
                doc_data = {
                    "ticker": ticker,
                    "price": close_price,
                    "sector": sector,
                    "dataDate": date_str,
                    "updatedAt": datetime.now(timezone.utc),
                }
                if change_pct is not None:
                    doc_data["changePct"] = round(change_pct, 2)
                db.collection("stockPrices").document(ticker).set(doc_data)

                # --- NEW: Historical record (never overwritten -- one doc per ticker per day) ---
                history_id = f"{ticker}_{date_str}"
                db.collection("priceHistory").document(history_id).set({
                    "ticker": ticker,
                    "price": close_price,
                    "sector": sector,
                    "date": date_str,
                })

                change_str = f", {change_pct:+.2f}%" if change_pct is not None else ""
                print(f"Updated {ticker} ({sector}): Rs.{close_price}{change_str} "
                      f"(data from {used_date.strftime('%d-%m-%Y')})")
            else:
                print(f"{ticker} not found in Bhavcopy for {used_date.strftime('%d-%m-%Y')}")

        print("Done.")