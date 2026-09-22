# Spec Addendum — Resolved Design Decisions

This addendum resolves the gaps flagged in review. These rules are binding for
all phases; the original spec's sections are unchanged except where noted.

## 1. Loans ↔ Accounts linkage (resolves Gap #1)

Every loan-related action moves money through an account, exactly like an
income/expense would:

| Action | Effect |
|---|---|
| Borrow money (loan received) | Selected account **balance increases** by principal. Recorded as a non-income "loan inflow" transaction (excluded from Income reports, included in cash flow). |
| Lend money to someone | Selected account **balance decreases** by principal. Recorded as a non-expense "loan outflow" transaction. |
| Receive a loan payment (money lent, repaid to you) | Selected account **balance increases**. |
| Make a loan payment (money you borrowed, you're repaying) | Selected account **balance decreases**. |

Every `loan_payments` row and every loan creation must carry an `account_id`
(already present in `loan_payments`; add `account_id` to `loans` for the
initial principal movement). All of these are wrapped in a DB transaction
alongside the account balance update (ties into Section 34's requirement).

Dashboard "Balance" (Sec. 6) is always **derived from account balances**,
never independently tracked — this keeps it mathematically consistent with
loan activity by construction.

## 2. Interest model (resolves Gap #2)

MVP/Phase 2 supports exactly two interest modes, both **flat, not
compounding**, calculated once at loan creation:

- **Fixed amount**: user enters a flat birr amount added to principal.
- **Flat percentage of principal**: `interest = principal × rate`, applied
  once regardless of loan duration (i.e., a 10% loan is +10% flat whether it's
  repaid in 1 month or 12 — no annualization, no daily accrual).

`total_amount = principal + interest_amount`, fixed at creation. This value
does not change as time passes. Per-period/APR-style interest is explicitly
deferred to a future phase (not Phase 2) and is *not* implied by anything in
Section 15.

## 3. Payment allocation order (resolves Gap #3)

Partial payments reduce the loan in this fixed order: **interest first, then
principal.** This is the simplest rule to reason about and display, since
`total_amount` (principal + interest) is fixed at creation — a payment simply
reduces `total_amount` remaining, tracked as a single running balance. No
separate principal/interest amortization schedule in Phase 1/2.

## 4. PIN recovery (resolves Gap #4)

PIN protection ships with an explicit, disclosed tradeoff:

- On PIN setup, show a one-time warning: *"There is no password recovery.
  If you forget your PIN, you can only regain access by restoring from a
  backup file, or by erasing all app data."*
- Add a **"Forgot PIN?"** link on the lock screen with two actions:
  1. Restore from a backup file (re-enter/create a new PIN during restore).
  2. Erase all local data and start fresh (destructive, double-confirmed).
- No security questions, no email recovery — consistent with "no server, no
  account" (Sec. 36).

## 5. Backup encryption (resolves Gap #5)

Exported backups (Sec. 24) support **optional password protection**:

- If the user sets an export password, the JSON backup is encrypted
  (AES via a package such as `encrypt`) before being written/shared.
- If no password is set, show a one-line warning that the file is
  human-readable and contains financial data, before the share sheet opens.
- Restore auto-detects encrypted vs. plain backups and prompts for the
  password only when needed.

## 6. Currency scope for MVP (resolves moderate gap)

**One currency per installation for Phase 1/2.** The currency chosen in
first-time setup (Sec. 5) applies to all accounts, transactions, loans, and
reports — there is no per-account currency and no conversion. "Allow other
currencies" (Sec. 5) means the user can *pick a different single currency* at
setup, not mix currencies. True multi-currency with exchange rates stays in
Phase 4 as originally scoped, and the `currency` column on `accounts` is kept
for forward-compatibility but is not user-editable per account in Phase 1/2.

## 7. Recurring transactions trigger (resolves moderate gap)

No background OS jobs (unreliable cross-platform on iOS/Android for a
zero-permission offline app). Instead:

- On every app launch, the app checks all active `recurring_transactions`
  rows where `next_date <= today`, silently creates the due transaction(s),
  and advances `next_date` by the frequency interval.
- A local notification (Sec. 17 infrastructure) additionally reminds the user
  in advance of the next due recurring item, but transaction creation itself
  never depends on the notification firing — only on app-open catch-up.

## 8. Restore behavior (resolves moderate gap)

Restore is **full overwrite by default**, not merge (merge logic across
IDs/timestamps is a correctness hazard for a financial ledger). The restore
screen states this plainly: *"Restoring will replace all current data with
the contents of this backup. This cannot be undone."* A "merge" mode is
explicitly out of scope until a future phase, if ever.

## 9. Overdue + interest (resolves moderate gap)

Since interest is flat and fixed at creation (see #2), "Overdue" is purely a
**date-based status flag** (today > due_date and remaining balance > 0) — it
does not trigger any recalculation of `total_amount`. No late fees or
accruing penalty interest in Phase 1/2.

## 10. Ethiopian calendar (resolves minor gap)

Phase 1/2 stores and computes all dates in the **Gregorian calendar only**
(matches SQLite date functions and `intl` package support directly). An
Ethiopian-calendar *display toggle* (convert Gregorian → Ethiopian for
on-screen display only, storage unchanged) is noted as a Phase 3/4 candidate,
not required for MVP.

## 11. Export localization (minor)

PDF/CSV exports (Sec. 25) use the app's currently selected UI language for
all labels and headers — no separate export-language setting in Phase 1/2.

## 12. Auto-backup reminder (minor)

Add a local notification, off by default, that can be enabled in Settings →
Backup: *"Remind me to back up"* with a Weekly/Monthly/Off choice. This is a
thin addition to the existing reminder infrastructure (Sec. 17), not a new
subsystem.
