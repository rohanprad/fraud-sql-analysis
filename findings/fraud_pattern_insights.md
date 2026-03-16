# Fraud Pattern Analysis — Findings
**Dataset:** IEEE-CIS Fraud Detection  
**Queries:** `03_fraud_patterns.sql`

---

## 1. Card Testing Patterns

Card testing — where fraudsters make a small charge to verify a stolen card is active before making a larger purchase — is clearly present in this dataset.

The top offending card (card1: 15885) shows 50 suspected test-then-real sequences across 10,360 transactions, with a fraud rate of 4.29% and an average transaction value of just $39.46. This low average is consistent with a card being used predominantly for small test charges.

More striking are cards with both high card testing counts *and* high fraud rates. Card 9917 has 8 suspected test sequences, a 33.33% fraud rate, and an average transaction of $42.54 — meaning roughly 1 in 3 of its transactions are fraudulent. Similarly, card 2801 has a 38.05% fraud rate with 5 suspected test sequences, suggesting an actively compromised card that was never blocked.

**Key takeaway:** Card testing is a strong leading indicator of fraud. A rule that flags any card with a sub-$10 transaction followed by a $100+ transaction within the same session should be a first-line detection signal.

---

## 2. Time-Based Fraud Patterns

Fraud rate varies significantly by hour of day, revealing a clear overnight fraud window.

| Period | Hours | Avg Fraud Rate |
|---|---|---|
| Peak fraud window | 05:00–09:00 | ~8–11% |
| Daytime low | 12:00–15:00 | ~2.3–3.0% |
| Evening baseline | 17:00–23:00 | ~3.2–3.7% |

The fraud rate peaks at **07:00 with 10.61%** — more than 3x the daytime average. This is a well-documented pattern in financial fraud: automated fraud scripts run overnight when transaction volumes are low, making anomalies harder to detect in real time, and cardholders are less likely to notice unusual activity while asleep.

Transaction volumes are lowest between 06:00–10:00 (as few as 2,479 transactions at 09:00 vs 42,115 at peak hours), which means the overnight fraud window involves a small number of transactions but a disproportionately high fraud rate.

**Key takeaway:** Time of day is a meaningful risk signal. Transactions between 04:00–09:00 should carry elevated scrutiny, particularly when combined with other risk factors.

---

## 3. Repeat Fraud Cards

The top 50 cards by fraud count reveal some alarming patterns of sustained compromise.

The most frauded card (card1: 9633) has 741 fraudulent transactions out of 4,144 total — a 17.88% fraud rate — with a total transaction value of $182,036. It remained active for over 4,363 hours (~182 days), suggesting it was never successfully blocked despite sustained fraudulent activity.

Card 2939 is the most extreme case by fraud rate: **44.57% of its 175 transactions are fraudulent**, meaning nearly half of all activity on this card is fraud. Its average transaction value of $153.74 is also higher than most other high-fraud cards, suggesting a targeted high-value compromise.

Several cards show very high fraud rates combined with long active windows:
- Card 2801: 38.05% fraud rate, active 4,316 hours
- Card 3867: 32.68% fraud rate, active 4,353 hours  
- Card 9917: 33.37% fraud rate, active 4,362 hours

All top 50 cards were active for roughly 4,300–4,368 hours (~180 days), which is the full span of the dataset. This means none of these compromised cards were blocked during the observation period — a significant real-world risk management failure worth noting in the findings.

**Key takeaway:** A small number of cards account for a disproportionate share of fraud. A velocity check — flagging cards that exceed a fraud count threshold — would catch these cases early. Real-time card blocking rules are critical.

---

## 4. High Risk Email Domains Cross-Referenced with Product Category

The combination of high-risk email domains and product categories reveals compounding fraud signals.

The single riskiest combination in the dataset is **mail.com + Product R**, with a fraud rate of **54.17%** across 24 transactions. This means more than half of all transactions from mail.com email addresses in product category R are fraudulent.

Other standout combinations:
- mail.com + Product H: 40.0% fraud rate
- outlook.com + Product R: 21.48% fraud rate
- mail.com + Product C: 17.31% fraud rate
- outlook.com + Product C: 17.18% fraud rate

In contrast, high-risk email domains show much lower fraud rates for Product W (hotmail.com + W: 1.51%, outlook.com + W: 2.12%), suggesting product category W may have stronger built-in fraud controls or represents lower-risk transaction types.

**Key takeaway:** Risk signals compound. A transaction with both a high-risk email domain and product category R or H should be treated as very high risk. This interaction effect will be built into the risk scoring model in Step 5.

---

## 5. Mobile Device Combined with Email Domain

When mobile device usage is combined with high-risk email domains, fraud rates escalate significantly beyond either signal in isolation.

The most extreme combination is **mail.com on desktop** at **30.26%** — nearly 1 in 3 transactions is fraudulent. Outlook.com on desktop follows at 20.03%, and outlook.es on desktop at 19.1%.

Interestingly, mobile + gmail produces a 13.74% fraud rate, which is notably higher than the overall gmail rate of 4.35% from the EDA. This means mobile device usage amplifies the risk of even moderate-risk email domains significantly.

The pattern of desktop + high-risk domain showing higher fraud rates than mobile + high-risk domain for the same domain (e.g. outlook.com desktop: 20.03% vs mobile: 15.62%) is unexpected and may indicate that fraudsters in this dataset are using automated desktop scripts more than mobile interfaces for targeted high-value attacks.

**Key takeaway:** Device type and email domain interact meaningfully. Mobile + any email domain elevates fraud risk. Desktop + high-risk domain is the single riskiest device/email combination in the dataset.

---

## 6. Fraud Rate Over Time

The cumulative fraud rate climbed steadily from 2.19% on day 1 to a stable plateau of approximately **3.5% from day 90 onwards**, where it remained for the rest of the 182-day observation window.

Several notable spikes are visible in the daily fraud rate:
- **Day 59:** 6.99% — the single highest daily fraud rate in the dataset
- **Day 117:** 6.38%
- **Day 56:** 5.67%
- **Days 50–51:** 5.25% and 5.24%

These spikes likely represent coordinated fraud campaigns or batch processing of stolen card data — a common pattern where fraudsters acquire a large set of credentials and exploit them in a short window before cards are cancelled.

The early period (days 1–25) shows a lower-than-average fraud rate of around 2.2–2.5%, with fraud intensity ramping up from day 28 onwards. This could reflect a dataset collection artefact, or genuine escalation of fraud activity over the observation period.

**Key takeaway:** Fraud is not uniformly distributed over time. Spike detection — flagging days where the fraud rate significantly exceeds the rolling average — would catch coordinated fraud campaigns early. A 7-day rolling average would smooth noise while still detecting genuine spikes.

---

## Summary of Pattern Analysis Findings

| Finding | Signal Strength |
|---|---|
| Card testing (sub-$10 → $100+) | Very High |
| Overnight transactions (04:00–09:00) | High |
| Repeat fraud cards (2+ fraud txns) | Very High |
| mail.com + Product R combination | Extreme (54% fraud rate) |
| Mobile device + high-risk email | High |
| Daily fraud rate spikes | Medium |

These six signals, combined with the five from the EDA, will form the basis of the rule-based risk scoring model in Step 5.
