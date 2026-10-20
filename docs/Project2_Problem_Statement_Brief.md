# Problem Statement Brief: Payment Reliability & Failed Transactions

**Company:** PayBridge NG (fictional) | **Project:** 2 of 9 | **Review period:** FY2025 vs FY2024 | **Status:** Draft for approval

---

## Executive summary

Every payment that fails costs PayBridge NG twice: the fee it would have earned is lost, and the processing cost of the attempt is still paid. Project 1 showed that unsuccessful attempts rose from 6.1% to 7.2% of volume in 2025, with fees forgone on failed transactions growing from ₦6.9M to ₦9.9M and the cost of those attempts from ₦2.8M to ₦4.3M.

This brief defines the problem, the decisions it supports, the questions to answer, the KPIs to track and the hypotheses to test, before any further analysis is done.

> **Core question:** Where, when and why do payments fail, how much of that loss can PayBridge NG actually recover, and what should Operations fix first?

## 1. Business problem

- **Rising failures.** The unsuccessful-attempt rate is up about one point year over year, and nobody can say which part of the platform is responsible.
- **No separation of causes.** A failed payment can be the customer's fault (insufficient funds), the issuing bank's, the network's, or PayBridge's own platform. Today they are all reported as one number, so teams cannot tell what they control.
- **Unquantified loss.** Forgone fees and the cost of failed attempts are not reported together, so the true price of unreliability is invisible to finance.
- **Unknown retry value.** Some failed customers try again and succeed. The business does not know how much revenue this recovers or how much more it could.

## 2. Business objective

Management must decide **where to focus reliability effort and spending** to recover lost revenue. The analysis should support four decisions:

1. Which channels, issuer banks and time windows to fix or escalate first.
2. Which failures PayBridge can influence, and which it can only manage with partners.
3. Whether to improve or introduce automatic retry for retryable failures.
4. What peak-hour and festive-season capacity the platform needs.

**Deliverable:** a one-page Power BI dashboard, a short report with quantified recommendations, and a README documenting the method.

## 3. Stakeholders

| Stakeholder | Interest | What they need |
|---|---|---|
| Head of Operations (primary) | Platform reliability and uptime | Where and when failures cluster, and what they cost |
| Head of Product / Engineering | Platform faults and retry design | Platform-caused failures separated from external causes, and the value of retries |
| Head of Partnerships | Issuer bank relationships | Which banks drive failures, as evidence for escalation |
| Head of Merchant Success | Merchant experience | Which channels and merchant segments suffer most |
| CFO | Revenue leakage | The naira cost of failure, and the recoverable share |
| Risk & Compliance | Control and integrity | Clear, auditable definitions, and the size of fraud-related declines |

## 4. Analytical questions

**Scale and trend**
- What share of attempts fail, and how has that moved month by month?
- How many naira of fees are forgone, and how much extra cost do failed attempts incur?

**Where**
- Which channels, issuer banks, bank types and cities have the highest failure rates?
- Do some merchant segments suffer more than others?

**When**
- Which hours, weekdays and months have the highest failure rates?
- Is the festive season worse, and by how much?

**Why**
- What response codes and failure categories (customer, issuer bank, network, platform, fraud) explain the failures?
- What share is within PayBridge's control?

**Recovery**
- How many failures are retryable, how many are retried, and how many retries succeed?
- How much revenue do retries recover, and how much recoverable revenue is left?

## 5. Proposed KPIs

| KPI | Definition | Why it matters |
|---|---|---|
| Success rate % | Successful attempts ÷ all attempts | Headline reliability |
| Failure rate % | Failed attempts ÷ all attempts | Mirror of the above, used for drill-downs |
| Unsuccessful rate % | Failed and reversed attempts ÷ all attempts | Comparable to the Project 1 figure |
| Fees forgone | List fee on failed attempts | Revenue lost |
| Cost on failed attempts | Processing, switching and other costs incurred on failures | Cost with no revenue |
| Total cost of failure | Fees forgone + cost on failed attempts | The full price of unreliability |
| Addressable failure rate % | Failures excluding customer-caused failures and fraud declines ÷ all attempts | What the business and its partners can influence |
| Platform-fault rate % | Failures flagged as PayBridge's fault ÷ all attempts | What PayBridge controls directly |
| Retry rate % | Retries ÷ retryable failures | How often recovery is attempted |
| Retry recovery rate % | Successful retries ÷ retries | How well recovery works |
| Peak-hour uplift | Failure rate in peak hours ÷ rate off-peak | Capacity signal |

**Note on fees forgone.** It is an upper bound: not every failed customer would have completed the payment. The addressable version (excluding customer-caused failures and fraud declines) gives a more realistic figure.

## 6. Initial hypotheses

Each is written before further analysis, so it can be proved wrong.

| # | Hypothesis | How we test it |
|---|---|---|
| H1 | USSD has the highest failure rate of any channel | Failure rate by channel |
| H2 | Failures peak at midday and in the evening | Failure rate by hour, peak against off-peak |
| H3 | Microfinance issuers fail more than commercial banks and fintechs | Failure rate by bank type and bank |
| H4 | Failures are rising through the year, and the festive season is worse | Monthly failure rate, Nov to Dec against the rest |
| H5 | Most failures are caused by customers or issuing banks, so the controllable part (platform faults) is a minority | Failure category and platform-fault share |
| H6 | Retries recover a meaningful share of failures, but a large retryable pool is never retried | Retry rate and recovery rate against the retryable pool |

**Working view:** H1 to H3 should locate the failures, H5 should size what is controllable, and H6 should reveal the cheapest recovery lever.

## 7. Data and scope

- **Source:** PayBridgeDB, the same synthetic dataset as Project 1.
- **Tables used:** Transactions (status, response code, hour, channel, issuer bank, retry flags, list fee and costs), ResponseCode (failure category, platform fault, retryable), Bank, Channel, Merchant, Location and Date.
- **Limitations to state upfront:**
  - Fraud declines are a small share of failures, so no fraud conclusions will be drawn.
  - There are no system incident logs or downtime records, so causes are inferred from response codes.
  - Retries are modelled simply, and there is no customer-level history.
  - All figures come from a simulation, so patterns show what the method can find, not real-world rates.

## 8. Plan (the seven core steps)

| Step | What happens | Output |
|---|---|---|
| 1. Define the problem | This brief | `docs/` |
| 2. Source the data | SQL views for failures, retries and response codes | `sql/` |
| 3. Explore and clean | Distributions, consistency checks, definitions documented | Notes in README |
| 4. Analyse | SQL queries testing H1 to H6 | Findings table |
| 5. Visualise | One-page Power BI dashboard | `powerbi/`, screenshot |
| 6. Document and tell the story | README and a short report | `README.md`, `report/` |
| 7. Publish | GitHub, LinkedIn and portfolio | Links |

*PayBridge NG is a fictional company created for a portfolio analytics project. Figures from Project 1 are quoted from that analysis.*
