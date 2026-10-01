"""
send_daily_notification.py

Run this AFTER fetch_prices.py has finished updating stockPrices
and priceHistory for the day.

This script:
1. Sends each user their OWN portfolio update (only to that user's devices).
2. Sends insurance premium reminders to the owner's devices:
   - 7 days before the due date
   - 1 day before the due date
   - On the due date

Safety rules:
- A portfolio notification is skipped if today's prices are not in
  priceHistory yet, or any holding has no price. It never sends a
  value of 0 because of missing data.
- Devices whose token is no longer valid are removed from fcmTokens.
"""

from datetime import datetime

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter


# ---------------------------------------------------------
# Firebase setup
# ---------------------------------------------------------

cred = credentials.Certificate("serviceAccountKey.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()


# ---------------------------------------------------------
# Notification helpers
# ---------------------------------------------------------

def get_tokens_for_user(user_id):
    """Return the unique FCM tokens registered to this user."""

    docs = (
        db.collection("fcmTokens")
        .where(filter=FieldFilter("userId", "==", user_id))
        .stream()
    )

    tokens = []

    for doc in docs:
        token = doc.to_dict().get("token")

        if token:
            tokens.append(token)

    return list(dict.fromkeys(tokens))


def send_to_tokens(tokens, title, body):
    """Send one notification to each token. Returns (sent, failed)."""

    if not tokens:
        return 0, 0

    messages = [
        messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
        )
        for token in tokens
    ]

    response = messaging.send_each(messages)

    # Remove tokens that no longer belong to an installed app.
    for token, result in zip(tokens, response.responses):
        if not result.success and isinstance(
            result.exception, messaging.UnregisteredError
        ):
            db.collection("fcmTokens").document(token).delete()
            print(f"  Removed dead token {token[:12]}...")

    return response.success_count, response.failure_count


# ---------------------------------------------------------
# Portfolio
# ---------------------------------------------------------

_price_cache = {}


def get_price(ticker, date_str):
    """Price of a ticker on a date from priceHistory, or None."""

    key = (ticker, date_str)

    if key not in _price_cache:
        doc = (
            db.collection("priceHistory")
            .document(f"{ticker}_{date_str}")
            .get()
        )

        _price_cache[key] = doc.to_dict().get("price") if doc.exists else None

    return _price_cache[key]


def find_price_date(operator, date_str):
    """Most recent priceHistory date matching the comparison."""

    docs = (
        db.collection("priceHistory")
        .where(filter=FieldFilter("date", operator, date_str))
        .order_by("date", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )

    for doc in docs:
        return doc.to_dict().get("date")

    return None


def load_holdings_by_user():
    """Group every investment by the user who owns it."""

    by_user = {}

    for doc in db.collection("investments").stream():
        data = doc.to_dict()
        user_id = data.get("userId")

        # Without an owner we cannot tell whose device to notify.
        if not user_id:
            continue

        by_user.setdefault(user_id, []).append(
            {
                "ticker": data.get("ticker", ""),
                "qty": float(data.get("quantity", 0) or 0),
                "buy_date": str(data.get("buyDate", ""))[:10],
            }
        )

    return by_user


def portfolio_value(holdings, date_str):
    """Return (total value, list of tickers with no price that day)."""

    total = 0.0
    missing = []

    for h in holdings:
        if h["buy_date"] > date_str:
            continue

        price = get_price(h["ticker"], date_str)

        if price is None:
            missing.append(h["ticker"])
            continue

        total += h["qty"] * price

    return total, missing


def send_portfolio_notifications():
    today_str = datetime.now().strftime("%Y-%m-%d")

    latest = find_price_date("<=", today_str)

    if latest != today_str:
        print(
            f"Prices for {today_str} are not in priceHistory yet "
            f"(latest: {latest}). Skipping portfolio notifications. "
            f"Run fetch_prices.py first."
        )
        return

    prev_date = find_price_date("<", today_str)

    for user_id, holdings in load_holdings_by_user().items():
        today_value, missing = portfolio_value(holdings, today_str)

        if missing:
            print(
                f"User {user_id[:6]}...: missing prices for "
                f"{sorted(set(missing))}. Skipping."
            )
            continue

        if today_value <= 0:
            print(f"User {user_id[:6]}...: value is 0. Skipping.")
            continue

        body = f"₹{today_value:,.2f}"

        if prev_date:
            prev_value, prev_missing = portfolio_value(holdings, prev_date)

            if prev_value > 0 and not prev_missing:
                change = today_value - prev_value
                pct = change / prev_value * 100
                sign = "+" if change >= 0 else "-"

                body += f" ({sign}₹{abs(change):,.2f}, {sign}{abs(pct):.2f}%)"

        tokens = get_tokens_for_user(user_id)

        if not tokens:
            print(f"User {user_id[:6]}...: no registered device.")
            continue

        sent, failed = send_to_tokens(tokens, "Portfolio Update", body)

        print(
            f"Portfolio update for user {user_id[:6]}...: "
            f"{sent} sent, {failed} failed. ({body})"
        )


# ---------------------------------------------------------
# Insurance
# ---------------------------------------------------------

def send_insurance_reminders():
    today = datetime.now().date()

    for doc in db.collection("insurance").stream():
        policy = doc.to_dict()

        user_id = policy.get("userId")
        due_date_string = policy.get("dueDate")
        premium = policy.get("premium", 0) or 0
        insurance_type = policy.get("type", "Insurance")

        if not user_id or not due_date_string:
            print(
                f"Skipping insurance document {doc.id}: "
                f"missing userId or dueDate."
            )
            continue

        try:
            due_date = datetime.fromisoformat(
                str(due_date_string).replace("Z", "+00:00")
            ).date()
        except ValueError:
            print(
                f"Could not parse dueDate for insurance "
                f"document {doc.id}: {due_date_string}"
            )
            continue

        days_remaining = (due_date - today).days

        if days_remaining == 7:
            title = "Insurance Premium Reminder"
            body = (
                f"Your {insurance_type} insurance premium "
                f"of ₹{premium:,.2f} is due in 7 days."
            )
        elif days_remaining == 1:
            title = "Insurance Premium Reminder"
            body = (
                f"Your {insurance_type} insurance premium "
                f"of ₹{premium:,.2f} is due tomorrow."
            )
        elif days_remaining == 0:
            title = "Insurance Premium Due Today"
            body = (
                f"Your {insurance_type} insurance premium "
                f"of ₹{premium:,.2f} is due today."
            )
        else:
            continue

        tokens = get_tokens_for_user(user_id)

        if not tokens:
            print(f"No FCM token found for insurance user {user_id[:6]}...")
            continue

        sent, failed = send_to_tokens(tokens, title, body)

        print(
            f"Insurance reminder for document {doc.id}: "
            f"{sent} succeeded, {failed} failed."
        )


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main():
    send_portfolio_notifications()
    send_insurance_reminders()


if __name__ == "__main__":
    main()