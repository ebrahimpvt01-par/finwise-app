"""
send_daily_notification.py

Run this AFTER fetch_prices.py has finished updating stockPrices and
priceHistory for the day. It calculates today's total portfolio value
and gain/loss versus the previous recorded day, then sends a push
notification to every registered device (stored in the `fcmTokens`
collection by the Flutter app).

Setup (one-time):
1. In Firebase console: Project settings -> Service accounts ->
   Generate new private key. Save the downloaded JSON file as
   `serviceAccountKey.json` in the same folder as this script.
   (Do NOT commit this file to GitHub - add it to .gitignore.)
2. pip install firebase-admin
"""

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from datetime import datetime

# ---- Setup ----
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()


def get_portfolio_value_for_date(date_str):
    """Sum quantity * price across all investments, using priceHistory
    for the given date. Returns 0 if no price data exists for that date."""
    investments = db.collection("investments").stream()
    total = 0.0
    for doc in investments:
        data = doc.to_dict()
        ticker = data.get("ticker", "")
        qty = data.get("quantity", 0)
        buy_date = str(data.get("buyDate", ""))[:10]
        if buy_date > date_str:
            continue  # not bought yet as of this date

        price_doc_id = f"{ticker}_{date_str}"
        price_doc = db.collection("priceHistory").document(price_doc_id).get()
        if price_doc.exists:
            price = price_doc.to_dict().get("price", 0)
            total += qty * price
    return total


def get_previous_trading_date(today_str):
    """Find the most recent priceHistory date before today, across all
    tickers, so we can compute day-over-day change even across weekends."""
    docs = (
        db.collection("priceHistory")
        .where("date", "<", today_str)
        .order_by("date", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )
    for doc in docs:
        return doc.to_dict().get("date")
    return None


def send_notification_to_all(title, body):
    tokens_ref = db.collection("fcmTokens").stream()
    tokens = [doc.id for doc in tokens_ref]

    if not tokens:
        print("No registered devices found in fcmTokens - nothing to send.")
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        tokens=tokens,
    )
    response = messaging.send_each_for_multicast(message)
    print(f"Sent to {response.success_count} device(s), {response.failure_count} failed.")


def main():
    today_str = datetime.now().strftime("%Y-%m-%d")
    today_value = get_portfolio_value_for_date(today_str)

    prev_date = get_previous_trading_date(today_str)
    prev_value = get_portfolio_value_for_date(prev_date) if prev_date else 0

    change = today_value - prev_value
    change_pct = (change / prev_value * 100) if prev_value else 0
    arrow = "+" if change >= 0 else ""

    title = "Portfolio Update"
    body = f"₹{today_value:,.2f} ({arrow}₹{change:,.2f}, {arrow}{change_pct:.2f}%)"

    print(f"Today: {today_str} | Value: {today_value} | Change: {change} ({change_pct:.2f}%)")
    send_notification_to_all(title, body)


if __name__ == "__main__":
    main()