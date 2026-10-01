"""
send_daily_notification.py

Run this AFTER fetch_prices.py has finished updating stockPrices
and priceHistory for the day.

This script:
1. Sends the existing portfolio update notification.
2. Checks insurance premium due dates.
3. Sends insurance reminders to the correct user's device.

Insurance reminders:
- 7 days before the due date
- 1 day before the due date
- On the due date
"""

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from datetime import datetime


# ---------------------------------------------------------
# Firebase Setup
# ---------------------------------------------------------

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()


# ---------------------------------------------------------
# Portfolio Functions
# ---------------------------------------------------------

def get_portfolio_value_for_date(date_str):
    """Calculate total portfolio value for a specific date."""

    investments = db.collection("investments").stream()

    total = 0.0

    for doc in investments:
        data = doc.to_dict()

        ticker = data.get("ticker", "")
        qty = data.get("quantity", 0)
        buy_date = str(data.get("buyDate", ""))[:10]

        if buy_date > date_str:
            continue

        price_doc_id = f"{ticker}_{date_str}"

        price_doc = (
            db.collection("priceHistory")
            .document(price_doc_id)
            .get()
        )

        if price_doc.exists:
            price = price_doc.to_dict().get("price", 0)
            total += qty * price

    return total


def get_previous_trading_date(today_str):
    """Find the most recent priceHistory date before today."""

    docs = (
        db.collection("priceHistory")
        .where("date", "<", today_str)
        .order_by(
            "date",
            direction=firestore.Query.DESCENDING
        )
        .limit(1)
        .stream()
    )

    for doc in docs:
        return doc.to_dict().get("date")

    return None


# ---------------------------------------------------------
# Existing Portfolio Notification
# ---------------------------------------------------------

def send_notification_to_all(title, body):
    """Send the portfolio notification to all registered devices."""

    tokens_ref = db.collection("fcmTokens").stream()

    tokens = []

    for doc in tokens_ref:
        token = doc.to_dict().get("token")

        if token:
            tokens.append(token)

    if not tokens:
        print("No registered devices found in fcmTokens.")
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        tokens=tokens,
    )

    response = messaging.send_each_for_multicast(message)

    print(
        f"Portfolio notification: "
        f"{response.success_count} sent, "
        f"{response.failure_count} failed."
    )


# ---------------------------------------------------------
# Insurance Notification
# ---------------------------------------------------------

def send_insurance_reminders():
    """
    Check insurance policies and send premium reminders.

    Reminders:
    - 7 days before due date
    - 1 day before due date
    - On due date
    """

    today = datetime.now().date()

    insurance_docs = db.collection("insurance").stream()

    for doc in insurance_docs:

        policy = doc.to_dict()

        # Get the user who owns this insurance policy.
        user_id = policy.get("userId")

        # Get insurance information.
        due_date_string = policy.get("dueDate")
        premium = policy.get("premium", 0)
        insurance_type = policy.get("type", "Insurance")

        # Skip incomplete records.
        if not user_id or not due_date_string:
            print(
                f"Skipping insurance document {doc.id}: "
                f"missing userId or dueDate."
            )
            continue

        # -------------------------------------------------
        # Convert stored ISO date into Python date
        # -------------------------------------------------

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

        # Calculate number of days until premium is due.
        days_remaining = (due_date - today).days

        # -------------------------------------------------
        # Decide whether to send notification
        # -------------------------------------------------

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
            # No notification required today.
            continue

        # -------------------------------------------------
        # Find the FCM token belonging to this user
        # -------------------------------------------------

        token_docs = (
            db.collection("fcmTokens")
            .where("userId", "==", user_id)
            .stream()
        )

        tokens = []

        for token_doc in token_docs:

            token_data = token_doc.to_dict()

            token = token_data.get("token")

            if token:
                tokens.append(token)

        # No device registered for this user.
        if not tokens:

            print(
                f"No FCM token found for insurance user "
                f"{user_id}"
            )

            continue

        # -------------------------------------------------
        # Send notification
        # -------------------------------------------------

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            tokens=tokens,
        )

        response = messaging.send_each_for_multicast(message)

        print(
            f"Insurance reminder sent for "
            f"insurance document {doc.id}: "
            f"{response.success_count} succeeded, "
            f"{response.failure_count} failed."
        )


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main():

    today_str = datetime.now().strftime("%Y-%m-%d")

    # -----------------------------------------------------
    # Existing portfolio notification
    # -----------------------------------------------------

    today_value = get_portfolio_value_for_date(today_str)

    prev_date = get_previous_trading_date(today_str)

    prev_value = (
        get_portfolio_value_for_date(prev_date)
        if prev_date
        else 0
    )

    change = today_value - prev_value

    change_pct = (
        change / prev_value * 100
        if prev_value
        else 0
    )

    arrow = "+" if change >= 0 else ""

    title = "Portfolio Update"

    body = (
        f"₹{today_value:,.2f} "
        f"({arrow}₹{change:,.2f}, "
        f"{arrow}{change_pct:.2f}%)"
    )

    print(
        f"Today: {today_str} | "
        f"Value: {today_value} | "
        f"Change: {change} "
        f"({change_pct:.2f}%)"
    )

    send_notification_to_all(title, body)

    # -----------------------------------------------------
    # Insurance notifications
    # -----------------------------------------------------

    send_insurance_reminders()


# ---------------------------------------------------------
# Run
# ---------------------------------------------------------

if __name__ == "__main__":
    main()