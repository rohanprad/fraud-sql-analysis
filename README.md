# Fraud SQL Analysis

## Overview
End-to-end SQL analysis of financial transaction fraud using the 
IEEE-CIS Fraud Detection dataset (~590,000 transactions).

## Business Questions
- What is the overall fraud rate and how is it distributed?
- Which transaction types, card types, and amounts carry the highest fraud risk?
- Can we identify patterns in fraudulent behaviour by time, device, and email domain?

## Dataset
- Source: [IEEE-CIS Fraud Detection](https://www.kaggle.com/c/ieee-fraud-detection)
- Tables: `transactions` (590k rows) and `identity` (144k rows)
- Platform: Google BigQuery

## Structure
| Folder | Contents |
|---|---|
| `queries/` | All SQL files in order of analysis |
| `results/` | CSV exports from BigQuery |
| `findings/` | Written insights and conclusions |

## Tools Used
- Google BigQuery
- Google Cloud Storage
- GitHub
