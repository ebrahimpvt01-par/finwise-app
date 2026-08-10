# FinWise — Firestore Schema Reference

This is the source of truth for what's actually in our Firestore database. If you're building a screen that reads or writes data, check here first instead of guessing field names — mismatched names are the #1 cause of "why is my data blank" bugs.

Firebase project: `finwise-app-1a295` (Mumbai region)

---

## ✅ Already built (live in Firestore right now)

### `investments` collection
One document per stock a user has bought.

| Field | Type | Example | Notes |
|---|---|---|---|
| `ticker` | string | `"RELIANCE"` | NSE ticker symbol, always uppercase |
| `quantity` | number (int) | `10` | Number of shares |
| `buyPrice` | number (double) | `1350.50` | Price per share at time of purchase, in ₹ |
| `buyDate` | string (ISO date) | `"2026-08-09T18:36:33.034884"` | When the user bought it |
| `createdAt` | timestamp | — | When the record was added to the app |
| `userId` | string | *(not yet added)* | **Coming soon** — will link each investment to the logged-in user once Auth is wired in. Until then, all investments are visible to everyone. |

Written by: `AddInvestmentScreen` (Flutter)
Read by: `MyInvestmentsScreen` (Flutter)

---

### `stockPrices` collection
One document per stock ticker, holding its latest known price. Document ID = the ticker itself (e.g. the doc for Reliance is literally named `RELIANCE`).

| Field | Type | Example | Notes |
|---|---|---|---|
| `ticker` | string | `"RELIANCE"` | Same as the document ID |
| `price` | number (double) | `1387.5` | Closing price from NSE Bhavcopy, in ₹ |
| `sector` | string | `"Energy"` | From a static sector map — see `fetch_prices.py`. Defaults to `"Other"` if not in the map. |
| `dataDate` | string | `"2026-08-08"` | The actual market date this price is from (Bhavcopy is end-of-day, not live-live) |
| `updatedAt` | timestamp (UTC) | — | When our script last refreshed this document |

Written by: `fetch_prices.py` (Python script, runs daily via Windows Task Scheduler at 7:30 PM)
Read by: `StockPricesScreen`, `MyInvestmentsScreen` (Flutter)

**Note:** this collection only contains tickers that either (a) someone has actually added as an investment, or (b) are in the `DEFAULT_WATCHLIST` fallback in the script. It is not the full NSE list.

---

## 🚧 Planned, not yet built

These were agreed on during our Phase 0 schema call. Field names below are the plan — whoever builds these screens should update this file once they're actually implemented, since real field names sometimes shift slightly during coding.

### `insurance` collection (planned)
| Field | Type | Notes |
|---|---|---|
| `type` | string | e.g. "Term", "Health" |
| `sumAssured` | number | ₹ |
| `premium` | number | ₹ |
| `dueDate` | string (date) | Next renewal date |
| `userId` | string | Once Auth exists |

Owner: Data & Auth Lead

### `income` collection (planned)
| Field | Type | Notes |
|---|---|---|
| `category` | string | e.g. "Salary", "Rent" |
| `amount` | number | ₹ |
| `date` | string (date) | |
| `type` | string | "income" or "expense" |
| `userId` | string | Once Auth exists |

Owner: Data & Auth Lead

### `goals` collection (planned)
| Field | Type | Notes |
|---|---|---|
| `name` | string | e.g. "Emergency Fund" |
| `targetAmount` | number | ₹ |
| `deadline` | string (date) | |
| `userId` | string | Once Auth exists |

Owner: TBD (likely Logic & Analytics Lead, since it feeds the savings-goal calculator)

### `users` collection (planned)
Standard Firebase Auth will handle login itself — this collection is for extra profile info Auth doesn't store natively (risk profile, onboarding answers, etc.)

| Field | Type | Notes |
|---|---|---|
| `riskProfile` | string | From the risk-profiling questionnaire |
| `email` | string | |

Owner: Data & Auth Lead

---

## Ground rules

1. **Before building a new screen that touches Firestore, check this file first.**
2. **If you add a new field or collection, update this file in the same commit.** A schema doc nobody updates is worse than no schema doc — it actively misleads people.
3. Ticker symbols are always stored **uppercase**, no exceptions (`.trim().toUpperCase()` in the Add Investment form enforces this).
4. Once Auth is live, every collection above gets a `userId` field, and every read query needs to filter by the logged-in user. This is a known follow-up task, tracked here so it doesn't get forgotten.

*Last updated by: Ebrahim (Investment & API Lead)*
