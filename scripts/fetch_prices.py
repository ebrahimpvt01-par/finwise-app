from nse import NSE
from datetime import datetime, timedelta, timezone
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# Connect to Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Curated list of common NSE large-caps. These are ALWAYS fetched, regardless
# of whether anyone has invested in them yet - this is what powers the
# dropdown in the Add Investment screen, so users have real choices to pick
# from instead of a chicken-and-egg "ticker not recognized" problem.
CURATED_WATCHLIST = [
    "RELIANCE", "TCS", "INFY", "WIPRO", "HCLTECH",
    "HDFCBANK", "ICICIBANK", "SBIN", "KOTAKBANK", "AXISBANK",
    "ITC", "HINDUNILVR", "NESTLEIND",
    "BHARTIARTL", "LT", "MARUTI", "TATAMOTORS",
    "SUNPHARMA", "TITAN", "ASIANPAINT", "BAJFINANCE",
]

# Static ticker -> sector mapping, used for the diversification/concentration
# recommendation rule.
SECTOR_MAP = {
    "RELIANCE": "Energy",
    "TCS": "IT",
    "INFY": "IT",
    "WIPRO": "IT",
    "HCLTECH": "IT",
    "HDFCBANK": "Banking",
    "ICICIBANK": "Banking",
    "SBIN": "Banking",
    "KOTAKBANK": "Banking",
    "AXISBANK": "Banking",
    "ITC": "FMCG",
    "HINDUNILVR": "FMCG",
    "NESTLEIND": "FMCG",
    "BHARTIARTL": "Telecom",
    "LT": "Infrastructure",
    "MARUTI": "Automobile",
    "TATAMOTORS": "Automobile",
    "SUNPHARMA": "Pharma",
    "TITAN": "Consumer Goods",
    "ASIANPAINT": "Consumer Goods",
    "BAJFINANCE": "Financial Services",
}


def get_sector(ticker):
    return SECTOR_MAP.get(ticker, "Other")


def get_watchlist():
    """Combines the curated default list with any extra tickers users have
    actually invested in (in case someone's investment isn't in the curated
    list). This guarantees the dropdown always has good options AND real
    investments always get their prices fetched."""
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

# Try today, then step backwards day by day until we find a file that exists
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

        # NSE's new UDiFF format (since July 2024) uses different column names
        # than the old format. Handle both, in case the library ever reverts.
        symbol_col = "TckrSymb" if "TckrSymb" in df.columns else "SYMBOL"
        close_col = "ClsPric" if "ClsPric" in df.columns else "CLOSE_PRICE"
        prev_close_col = "PrvsClsgPric" if "PrvsClsgPric" in df.columns else "PREV_CLOSE"

        print(f"Using columns: {symbol_col} / {close_col} / {prev_close_col}")

        for ticker in WATCHLIST:
            row = df[df[symbol_col] == ticker]
            if not row.empty:
                close_price = float(row.iloc[0][close_col])

                # Daily % change, if the previous-close column is available
                change_pct = None
                if prev_close_col in df.columns:
                    try:
                        prev_close = float(row.iloc[0][prev_close_col])
                        if prev_close > 0:
                            change_pct = ((close_price - prev_close) / prev_close) * 100
                    except (ValueError, TypeError):
                        change_pct = None

                sector = get_sector(ticker)

                doc_data = {
                    "ticker": ticker,
                    "price": close_price,
                    "sector": sector,
                    "dataDate": used_date.strftime("%Y-%m-%d"),
                    "updatedAt": datetime.now(timezone.utc),
                }
                if change_pct is not None:
                    doc_data["changePct"] = round(change_pct, 2)

                db.collection("stockPrices").document(ticker).set(doc_data)

                change_str = f", {change_pct:+.2f}%" if change_pct is not None else ""
                print(f"Updated {ticker} ({sector}): Rs.{close_price}{change_str} "
                      f"(data from {used_date.strftime('%d-%m-%Y')})")
            else:
                print(f"{ticker} not found in Bhavcopy for {used_date.strftime('%d-%m-%Y')}")

        print("Done.")