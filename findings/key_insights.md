# Key Insights — Exploratory Data Analysis
**Dataset:** IEEE-CIS Fraud Detection  
**Queries:** `02_eda.sql`  
**Rows Analysed:** 590,540 transactions

---

## 1. Fraud Rate Overview

Out of 590,540 transactions, 20,663 are fraudulent — an overall fraud rate of **3.5%**. 

This heavy class imbalance is important to flag: a model that predicted every transaction as legitimate would still achieve 96.5% accuracy, which makes accuracy a misleading metric for this problem. In a real-world setting this would steer us toward precision/recall and F1 scoring instead.

---

## 2. Transaction Amount Distribution

| Amount Range | Transactions | Fraud Rate |
|---|---|---|
| Under $10 | 6,795 | 8.33% |
| $10–$50 | 180,720 | 3.83% |
| $50–$200 | 302,555 | 2.85% |
| $200–$1,000 | 92,890 | 4.71% |
| Over $1,000 | 7,580 | 2.47% |

Two findings stand out here. First, very small transactions (under $10) have the highest fraud rate at 8.33% — likely representing card testing, where fraudsters make a tiny charge to verify a stolen card is active before making larger purchases. Second, mid-to-high value transactions ($200–$1,000) have an elevated fraud rate of 4.71%, which aligns with fraudsters maximising value before a stolen card is blocked.

Counterintuitively, transactions over $1,000 have the *lowest* fraud rate at 2.47%, possibly because high-value purchases trigger additional verification by banks.

---

## 3. Fraud by Card Network and Type

| Card Network | Card Type | Fraud Rate |
|---|---|---|
| Discover | Credit | 7.93% |
| Mastercard | Credit | 6.92% |
| Visa | Credit | 6.81% |
| American Express | Debit | 3.47% |
| Visa | Debit | 2.55% |
| Mastercard | Debit | 2.16% |

Credit cards are consistently frauded at a higher rate than debit cards across all networks — credit cards average ~7% fraud rate vs ~2.5% for debit. This makes sense: credit card details are more widely used for online transactions, making them a more common target for data breaches and phishing.

Discover credit cards have the highest fraud rate at 7.93% despite relatively low transaction volume (6,304 transactions), suggesting they may be disproportionately targeted or used in higher-risk contexts.

---

## 4. Fraud by Product Category

| Product | Transactions | Fraud Rate | Avg Transaction |
|---|---|---|---|
| C | 68,519 | 11.69% | $42.87 |
| S | 11,628 | 5.90% | $60.27 |
| H | 33,024 | 4.77% | $73.17 |
| R | 37,699 | 3.78% | $168.31 |
| W | 439,670 | 2.04% | $153.16 |

Product category C has by far the highest fraud rate at 11.69% — nearly 3x the dataset average — despite having low average transaction values ($42.87). This combination of low value and high fraud is consistent with the card testing pattern identified in the amount analysis above.

Category W dominates by volume (74% of all transactions) but has the lowest fraud rate at 2.04%, suggesting it may represent lower-risk transaction types such as standard retail purchases.

---

## 5. Fraud by Email Domain

| Email Domain | Fraud Rate | Avg Transaction |
|---|---|---|
| mail.com | 18.96% | $157.61 |
| outlook.es | 13.01% | $41.09 |
| aim.com | 12.70% | $128.74 |
| outlook.com | 9.46% | $112.94 |
| hotmail.com | 5.30% | $99.93 |
| gmail.com | 4.35% | $128.63 |
| anonymous.com | 2.32% | $169.49 |

mail.com has the highest fraud rate at 18.96% — nearly 5x the overall average. Regional email domains (outlook.es, hotmail.es, live.com.mx) also appear in the top fraud tiers, which may indicate geographic targeting patterns worth investigating further.

Interestingly, anonymous.com — which might be expected to be high risk — has a below-average fraud rate of 2.32%, suggesting that privacy-conscious users are not necessarily fraudulent.

Gmail, the most common domain with 228,355 transactions, sits close to the dataset average at 4.35%, making it a reasonable baseline for email domain risk.

---

## 6. Fraud by Device Type

| Device Type | Transactions | Fraud Rate | Avg Transaction |
|---|---|---|---|
| Mobile | 55,645 | 10.17% | $69.50 |
| Desktop | 85,165 | 6.52% | $92.60 |

Mobile transactions have a significantly higher fraud rate than desktop (10.17% vs 6.52%) despite lower average transaction values. This could reflect weaker authentication on mobile platforms, greater exposure to SMS phishing, or the fact that stolen card details are more commonly used via mobile interfaces.

Note that only 140,810 of 590,540 transactions (23.8%) have a device type recorded, so these figures represent a subset of overall activity and should be interpreted with some caution.

---

## 7. Data Quality — Null Check

| Column | Missing Values | % Missing |
|---|---|---|
| TransactionID | 0 | 0% |
| TransactionAmt | 0 | 0% |
| isFraud | 0 | 0% |
| card4 | 1,577 | 0.27% |
| card6 | 1,571 | 0.27% |
| P_emaildomain | 94,456 | 16.0% |
| ProductCD | 0 | 0% |

The core fields (ID, amount, fraud label, product) are fully complete — no missing values. Card network and type have minimal missingness (0.27%) which is unlikely to affect analysis.

The most significant data quality issue is `P_emaildomain`, which is missing for 16% of transactions. This should be kept in mind when drawing conclusions from the email domain analysis — it is possible that missing email domains are not randomly distributed and could skew results.

---

## Summary of Key Risk Signals

Based on the EDA, the following factors are associated with elevated fraud rates:

1. **Very small transaction amounts** (under $10) — likely card testing activity
2. **Credit cards** over debit cards, particularly Discover
3. **Product category C** — highest fraud rate at 11.69%
4. **Certain email domains** — mail.com, outlook.es, and aim.com are highest risk
5. **Mobile devices** — 10.17% fraud rate vs 6.52% on desktop

These signals will feed directly into the rule-based risk scoring model in Step 5.
