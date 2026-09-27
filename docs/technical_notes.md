# Technical notes

Detail behind the [README](../README.md).

## Data

[IEEE-CIS Fraud Detection](https://www.kaggle.com/competitions/ieee-fraud-detection) (Vesta), loaded into BigQuery.

| Table | Rows | Contents |
|---|---|---|
| `transactions` | 590,540 | Amount, product, card attributes, billing region, email domain, time offset, fraud label |
| `identity` | 144,233 | Device and browser data for about a quarter of transactions |

- **182 days**, 20,663 frauds (**3.5%**). Heavily anonymised: many columns are codes without official meanings.
- **Time** (`TransactionDT`) is seconds from an unknown start point, not a timestamp.
- **Labels:** once an account is reported for fraud, its later linked transactions are also labelled fraud.
  "Repeat fraud" is partly a product of how the labels were made.
- **Licence:** competition data, non-commercial use. Only aggregates are published here.

## Corrections to the first draft

| First draft said | What the data shows | Fix |
|---|---|---|
| "Card 9633: 741 frauds over 182 days, never blocked" | `card1` is a shared attribute: value 15885 alone covers 10,361 transactions, 32 billing regions and ~709 accounts. "182 days" is the dataset's whole span | Approximate account ID: `card1` + `addr1` + (transaction day − `D1`) |
| Card-testing sequences per card | The "previous transaction" was often a different customer's | Recomputed per account, within 24 hours |
| "Fraud peaks 04:00–09:00" | Volume is lowest at those derived hours (~2.5k vs 42k/hour), so they're the real night | Described as "overnight": hours under 25% of peak volume |
| "mail.com + Product R: 54% fraud" | Based on 24 transactions | Minimum of 500 transactions before a rate is used |
| — | `01_data_verification.sql` contained a placeholder project ID | Fixed |

**Account ID check:** if the ID identifies real accounts, the labelling rule above means accounts should be
all-fraud or all-genuine.

| Grouped by | Groups | Fraud groups that are all fraud | Multi-transaction groups with one label |
|---|---|---|---|
| Account ID | 199,070 | 74.5% | 98.5% |
| `card1` | 13,553 | 11.7% | 84.8% |

11.3% of transactions lack `addr1` or `D1`, so their account ID is partial; velocity and card-testing features
are left blank for them.

## Pipeline

| Step | File | Output |
|---|---|---|
| 1 | [01_data_verification.sql](../sql/01_data_verification.sql) | Row counts, schema, previews |
| 2 | [02_eda.sql](../sql/02_eda.sql) | First-look breakdowns (amount, card, product, email, device, nulls) |
| 3 | [03_accounts.sql](../sql/03_accounts.sql) | `txn_enriched`: account ID, day, dataset hour, train/test split |
| 4 | [04_fraud_patterns.sql](../sql/04_fraud_patterns.sql) | `txn_features` (overnight, amount band, card testing, 24h velocity), `signal_rates` |
| 5 | [05_risk_score.sql](../sql/05_risk_score.sql) | `signal_points`, `txn_scored` |
| 6 | [06_evaluation.sql](../sql/06_evaluation.sql) | `capture_curve`: review rate vs fraud caught, train and test |
| 7 | [07_expected_loss.sql](../sql/07_expected_loss.sql) | `score_calibration`, `txn_expected_loss`, `capture_compare` |

**Train / test:** days 1–127 (437,511 transactions, 3.51% fraud) build every rule; days 128–182
(153,029 transactions, 3.48% fraud) test them.

**No leakage:** features use only information available at payment time. "The account's previous transaction was
fraud" is deliberately excluded, because fraud is confirmed weeks later via chargebacks.

## Risk score

Points from each warning sign's training-period lift (fraud rate ÷ average):
+3 for ≥2.5×, +2 for 1.5–2.5×, +1 for 1.2–1.5×, −1 for <0.8×, 0 otherwise. Signals: time of day, product,
card type, amount band, device, email domain, 24h velocity. Groups under 500 training transactions score 0.
Full table: [results/signal_points.csv](../results/signal_points.csv).

**Performance on the test period** (review everything at or above a cut-off):

| Cut-off | Reviewed | Frauds caught | Hit rate | vs random |
|---|---|---|---|---|
| 8+ | 4.2% | 22.9% | 19.1% | 5.5× |
| 7+ | 7.1% | 28.5% | 14.1% | 4.0× |
| 6+ | 10.5% | 38.2% | 12.7% | 3.6× |
| 5+ | 13.4% | 46.0% | 12.0% | 3.4× |

Training results at the same cut-offs are within 2 percentage points (e.g. 8+: 23.0% train vs 22.9% test).

**Benchmark:** "review all product C" (10.4% of transactions) catches 39.2% of fraud, the same as the score at
that load. The score adds value at tighter capacity (≈4%: 22.9% vs ~16%).

## Expected loss

`expected loss = chance of fraud × amount`, where chance of fraud is the training-period fraud rate at each score.
Scores of 12+ are grouped (they have 13–409 transactions each), and small groups are smoothed towards the
average (weight 200 transactions).

| Reviewed (test) | Method | Frauds caught | Fraud value caught | Hit rate |
|---|---|---|---|---|
| 5% | Risk score | 24.5% | 9.3% | 17.0% |
| 5% | Biggest first | 8.4% | 44.4% | 5.9% |
| 5% | **Expected loss** | 13.6% | **47.4%** | 9.5% |
| 10% | Risk score | 37.0% | 15.1% | 12.9% |
| 10% | Biggest first | 14.8% | 58.3% | 5.2% |
| 10% | **Expected loss** | 23.9% | **63.2%** | 8.3% |

## Repeat fraud (accounts with a complete ID)

- 4,825 accounts had fraud; 42.5% had more than one fraudulent transaction.
- 63% of fraud transactions came after the account's first fraud.
- For 75% of accounts, first to last fraud was within 17 hours.

## Limitations

- **Approximate account ID**, and 11.3% of transactions have a partial one.
- **Anonymised data:** the meaning of product codes (C, W, …) is not published.
- **Offset time:** "overnight" is inferred from volume, not from real clock times.
- **Unknown capacity and costs:** the fraud team's real review capacity and cost per review aren't known, so results are shown across review levels rather than at one fixed point.
- **Value vs count:** expected loss protects the most money; the risk score finds the most cases. The right choice depends on whether the goal is losses or stopping fraudsters.

## Reproduce

1. Load `train_transaction.csv` and `train_identity.csv` from Kaggle into a BigQuery dataset `fraud_analysis`.
2. Run `sql/01` to `sql/07` in order (replace the project ID). In the free BigQuery sandbox, create a
   `fraud_work` dataset with a default table expiry under 60 days first.
3. Export the summary tables to `results/`, then `pip install pandas matplotlib` and run `python charts/make_charts.py`.
