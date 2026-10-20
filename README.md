# Project 2: Payment Reliability & Failed Transactions

**Where, when and why do payments fail, and how much of the loss can PayBridge NG recover?**

*Project 2 of 9 built on the PayBridge dataset. Tools: SQL Server, Power BI.*

![Payment Reliability dashboard](images/dashboard.png)
<!-- Add your finished dashboard screenshot to the images folder as dashboard.png -->

> **About this project.** PayBridge NG is a fictional company and all data is synthetic. Some patterns were built into the simulation so the analysis has something to find. The purpose is to demonstrate the method: framing a business problem, building a reliable analytical layer, testing hypotheses, and recommending action with a naira value attached.

---

## Headline finding

Failed payments rose **46%** in 2025, twice as fast as transaction volume (+23%). They cost PayBridge NG **₦14.1M** (fees it never earned plus processing costs it still paid), which is about **10% of fee revenue**. Roughly two-thirds of the failures are not caused by customers, so most of that loss is addressable.

---

## 1. Problem and context

Every failed payment costs twice: the fee is lost, and the cost of the attempt is still paid. Project 1 showed that unsuccessful attempts rose from 6.1% to 7.2% of volume, but nobody could say which part of the platform was responsible, or how much could be recovered.

**Primary question:** where, when and why do payments fail, how much of that loss can PayBridge NG recover, and what should Operations fix first?

**Stakeholders:** Head of Operations (primary), Product and Engineering, Partnerships, Merchant Success, CFO, Risk and Compliance.

**Decisions supported:** where to focus reliability effort, which partners to escalate with, whether to improve automatic retry, and what peak-hour and festive-season capacity is needed.

The full problem statement, with KPIs and six hypotheses, is in `docs/Project2_Problem_Statement_Brief.md`.

## 2. Data

| Item | Detail |
|---|---|
| Source | PayBridgeDB (SQL Server), the same synthetic dataset as Project 1 |
| Scale | About 1 million transaction attempts, January 2024 to December 2025 |
| Analytical layer | Three SQL views in a separate `rel` schema: attempt-level flags and descriptors, a retry pool, and a monthly summary |
| Key fields | Status, response code and failure category, hour, channel, issuer bank and bank type, retry links, list fee and costs |

## 3. Exploration and cleaning

The data was tested before any analysis:

- **Consistency checks** (all passed, so no rows were removed or changed): status agrees with response code, only successful attempts earn fees, no bank charge on failures, every retry points to a real failed attempt on the same day, and expected missing values only.
- **Reconciliation with Project 1:** the unsuccessful rate (6.1% to 7.2%), fees forgone (₦6.9M to ₦9.9M) and cost on failed attempts (₦2.8M to ₦4.3M) match exactly.
- **Definitions that shape every number:**
  1. Attempts include retries, so rates are per attempt, not per customer intent.
  2. Reversals count as unsuccessful, but not as failures. They stayed flat at about 0.73%, so the rise comes entirely from outright failures.
  3. Fees forgone use the list fee, so they are an upper bound.
  4. Addressable failures exclude customer-caused failures and fraud declines (blocking fraud is the system working).

## 4. Analysis

Each hypothesis was tested with SQL (2025 against 2024 where relevant).

| # | Hypothesis | Evidence | Verdict |
|---|---|---|---|
| H1 | USSD fails most | 12.07% in 2025 against 4.22% for POS (2.9 times). About half of the overall rise comes from USSD's growing share, and half from every channel getting a little worse. | **Supported** |
| H2 | Failures peak at midday and in the evening | Peak hours fail 22% to 25% more than off-peak in every channel. Six hours of the day carry 43% of attempts but 48% of failures. | **Supported** |
| H3 | Microfinance issuers fail more | 7.86% against 5.89% for commercial banks and 5.44% for fintechs. The largest naira losses sit with big commercial banks. | **Supported** |
| H4 | Failures are rising, worse in the festive season | Monthly rate climbed from 4.53% (Jan 2024) to 7.66% (Dec 2025). Nov to Dec runs 1.6 to 1.7 points above the rest of the year. | **Supported** |
| H5 | Most failures are outside PayBridge's control | Customers and issuing banks cause 59.5%. Platform faults are 14.6%, but grew 47% against 23% volume growth. | **Supported** |
| H6 | Retries recover value, but many are never retried | 76% of retries succeed, yet only 35% of retryable failures are retried. ₦4.9M of fees at stake were never retried in 2025. | **Supported** |

## 5. The dashboard

A one-page Power BI report built on a dark theme and a set of analytical visuals: KPI cards, a monthly trend, a decomposition tree of failure causes, a success-rate gauge, a retry funnel, a channel by hour-band heatmap, a bank scorecard and a key-influencers view. It answers four questions in order: how big is the problem, where and when does it happen, why does it happen, and how much can be recovered.

## 6. Key insights

1. **Failure is expensive:** ₦14.1M in 2025 (₦9.9M in fees forgone plus ₦4.3M of cost on failed attempts), up 47%. The ₦4.3M is 4.6% of all transaction costs, spent on payments that earned nothing.
2. **USSD is the weak point.** It fails 2.9 times as often as POS, and it is also the lowest-margin channel from Project 1.
3. **Peak load hurts everywhere.** The 22% to 25% uplift in every channel points to a platform-wide capacity limit, not a single weak channel.
4. **The problem is spread across the platform.** Every channel, bank type and merchant segment got worse. Failure rates differ little by segment (5.9% to 6.5%), but Enterprise merchants bear 64% of the naira loss because of their volume.
5. **Platform faults are growing faster than volume**, from 0.79% to 0.94% of attempts. This is the portion PayBridge controls completely.
6. **Half of failures need partners.** Issuing banks (29.3%) and the network (22.6%) cause 52% of failures, and four large commercial banks account for about 45% of fees forgone.
7. **Retry is the cheapest lever.** Customers retry within about 160 seconds on average and succeed 76% of the time, but two-thirds of retryable failures are never retried.

## 7. Recommendations

| Priority | Action | Estimated value | Basis |
|---|---|---|---|
| 1 | **Automatic or prompted retry** for non-customer failures (network, issuer bank, platform) | About ₦1.1M a year, up to ₦2.0M | Raising the retry rate from 34% to 70% on that pool, or to 100%, at the observed 76% recovery rate |
| 2 | **Fix platform faults** | About ₦2.1M a year if eliminated, ₦0.3M to return to the 2024 rate | 5,195 platform failures at the average failure cost. Engineering owns this one. |
| 3 | **Reduce USSD failures** toward the level of other digital channels | Up to about ₦2.3M a year | If USSD matched Web Checkout (6.3%). An upper bound, since some USSD failures are customer-caused. |
| 4 | **Add peak-hour capacity** (12 to 14 and 18 to 20) | About ₦1.2M a year | If peak failure rates matched off-peak rates |
| 5 | **Prepare for the festive season** (Nov to Dec) | About ₦0.7M a year | If the Nov to Dec failure rate held at the Jan to Oct level |
| 6 | **Escalate with issuing banks**, starting with the four largest commercial banks and the three microfinance banks | About ₦0.6M a year | A 20% improvement on ₦3.0M of issuer-bank fees forgone |

**Reading the numbers:** the estimates use the average cost of a failed attempt (about ₦398: lost fee plus processing cost) and the 2025 figures. They are sizing estimates, not forecasts, and they overlap, so they cannot simply be added. Even so, a realistic programme could address roughly half of the ₦14.1M.

## 8. Limitations

- Synthetic and simplified: no customer table, system incident logs or downtime records, so causes are inferred from response codes
- Fraud declines are too few, and too undesigned, to support any fraud conclusion
- Retries are modelled simply, and there is no customer-level history
- Fees forgone assume a failed customer would have completed the payment, so the headline figure is an upper bound
- The analysis shows where and when failures occur, not proof of why. Estimates rest on the stated assumptions


**Author:** Sanya Ajibola Ebenezer | [LinkedIn](#) <!-- add your link -->
