/* =====================================================================
   PayBridge NG | Project 2: Payment Reliability & Failed Transactions
   Script 03: Analysis queries (Step 4), one section per hypothesis
   Run each query separately and copy the result into your findings table.
   "Failure rate" below means failed attempts / all attempts (reversals excluded).
   ===================================================================== */

USE PayBridgeDB;
GO

/* =====================================================================
   COST OF FAILURE (the headline for the whole project)
   ===================================================================== */
SELECT [year],
       SUM(is_failed)                                                       AS failed_attempts,
       ROUND(SUM(fees_forgone_ngn) / 1e6, 2)                                AS fees_forgone_m,
       ROUND(SUM(addressable_fees_forgone_ngn) / 1e6, 2)                    AS addressable_fees_forgone_m,
       ROUND(SUM(cost_on_failed_ngn) / 1e6, 2)                              AS cost_on_failed_m,
       ROUND((SUM(fees_forgone_ngn) + SUM(cost_on_failed_ngn)) / 1e6, 2)    AS total_cost_of_failure_m
FROM rel.vw_Attempts
GROUP BY [year]
ORDER BY [year];


/* =====================================================================
   H1: USSD has the highest failure rate of any channel
   Look for: which channel tops each year, and by how much.
   ===================================================================== */
SELECT [year], channel_name,
       COUNT(*)                                          AS attempts,
       SUM(is_failed)                                    AS failed,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct
FROM rel.vw_Attempts
GROUP BY [year], channel_name
ORDER BY [year], failure_rate_pct DESC;


/* =====================================================================
   H2: Failures peak at midday and in the evening
   2a. By hour of day.  2b. Peak against off-peak.
   2c. The same split inside each channel, to check the peak effect is not just channel mix.
   ===================================================================== */
SELECT txn_hour,
       COUNT(*)                                          AS attempts,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct
FROM rel.vw_Attempts
GROUP BY txn_hour
ORDER BY txn_hour;

SELECT CASE WHEN is_peak_hour = 1 THEN 'Peak (12-14, 18-20)' ELSE 'Off-peak' END AS period,
       COUNT(*)                                          AS attempts,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct
FROM rel.vw_Attempts
GROUP BY is_peak_hour;

SELECT channel_name,
       ROUND(100.0 * SUM(CASE WHEN is_peak_hour = 1 THEN is_failed END) / NULLIF(SUM(CASE WHEN is_peak_hour = 1 THEN 1 END), 0), 2) AS peak_failure_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN is_peak_hour = 0 THEN is_failed END) / NULLIF(SUM(CASE WHEN is_peak_hour = 0 THEN 1 END), 0), 2) AS offpeak_failure_rate_pct
FROM rel.vw_Attempts
GROUP BY channel_name
ORDER BY channel_name;


/* =====================================================================
   H3: Microfinance issuers fail more than commercial banks and fintechs
   3a. By bank type.  3b. By bank.
   ===================================================================== */
SELECT bank_type,
       COUNT(*)                                          AS attempts,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct
FROM rel.vw_Attempts
GROUP BY bank_type
ORDER BY failure_rate_pct DESC;

SELECT bank_name, bank_type,
       COUNT(*)                                          AS attempts,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct,
       ROUND(SUM(fees_forgone_ngn) / 1e6, 2)             AS fees_forgone_m
FROM rel.vw_Attempts
GROUP BY bank_name, bank_type
ORDER BY failure_rate_pct DESC;


/* =====================================================================
   H4: Failures are rising through the year, and the festive season is worse
   4a. Month by month.  4b. Festive months (Nov-Dec) against the rest, by year.
   ===================================================================== */
SELECT year_month, attempts, failures, failure_rate_pct
FROM rel.vw_MonthlyReliability
ORDER BY year_month;

SELECT [year],
       CASE WHEN month_num IN (11, 12) THEN 'Nov-Dec' ELSE 'Jan-Oct' END AS period,
       SUM(attempts)                                                    AS attempts,
       ROUND(100.0 * SUM(failures) / SUM(attempts), 2)                  AS failure_rate_pct
FROM rel.vw_MonthlyReliability
GROUP BY [year], CASE WHEN month_num IN (11, 12) THEN 'Nov-Dec' ELSE 'Jan-Oct' END
ORDER BY [year], period;


/* =====================================================================
   H5: Most failures are caused by customers or issuing banks;
       the controllable part (platform faults) is a minority
   ===================================================================== */
SELECT [year], failure_category,
       COUNT(*)                                                         AS failed_attempts,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY [year]), 1) AS pct_of_failures,
       ROUND(SUM(fees_forgone_ngn) / 1e6, 2)                            AS fees_forgone_m
FROM rel.vw_Attempts
WHERE is_failed = 1
GROUP BY [year], failure_category
ORDER BY [year], failed_attempts DESC;


/* =====================================================================
   H6: Retries recover a meaningful share, but a large retryable pool is never retried
   6a. By year and failure category.  6b. How quickly do customers retry?
   ===================================================================== */
SELECT [year], failure_category,
       COUNT(*)                                                                     AS retryable_failures,
       SUM(was_retried)                                                             AS retried,
       ROUND(100.0 * SUM(was_retried) / COUNT(*), 1)                                AS retry_rate_pct,
       SUM(retry_succeeded)                                                         AS recovered,
       ROUND(100.0 * SUM(retry_succeeded) / NULLIF(SUM(was_retried), 0), 1)         AS recovery_rate_pct,
       ROUND(SUM(fee_recovered_ngn) / 1e6, 2)                                       AS fees_recovered_m,
       ROUND(SUM(CASE WHEN was_retried = 0 THEN fee_at_stake_ngn ELSE 0 END) / 1e6, 2) AS unretried_fees_at_stake_m
FROM rel.vw_RetryPool
GROUP BY [year], failure_category
ORDER BY [year], retryable_failures DESC;

SELECT COUNT(*)                          AS retries,
       AVG(1.0 * seconds_to_retry)       AS avg_seconds_to_retry,
       MIN(seconds_to_retry)             AS min_seconds,
       MAX(seconds_to_retry)             AS max_seconds
FROM rel.vw_RetryPool
WHERE was_retried = 1;


/* =====================================================================
   WHO IS AFFECTED? (exploratory: a flat result is also a finding)
   ===================================================================== */
SELECT merchant_segment,
       COUNT(*)                                          AS attempts,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct,
       ROUND(SUM(fees_forgone_ngn) / 1e6, 2)             AS fees_forgone_m
FROM rel.vw_Attempts
GROUP BY merchant_segment
ORDER BY failure_rate_pct DESC;

SELECT market_type,
       COUNT(*)                                          AS attempts,
       ROUND(100.0 * SUM(is_failed) / COUNT(*), 2)       AS failure_rate_pct
FROM rel.vw_Attempts
GROUP BY market_type
ORDER BY failure_rate_pct DESC;