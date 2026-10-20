/* =====================================================================
   PayBridge NG | Project 2: Payment Reliability & Failed Transactions
   Script 01: Reliability views (Step 2, source the data)
   Run in SSMS against PayBridgeDB, after the Project 1 load is complete.
   Creates a new schema, rel, so nothing in the original tables changes.

   Views:
     rel.vw_Attempts            one row per transaction attempt, with descriptive columns and flags
     rel.vw_RetryPool           one row per retryable failed first attempt: was it retried, did it recover?
     rel.vw_MonthlyReliability  one row per month, for quick checks and trend queries
   ===================================================================== */

USE PayBridgeDB;
GO

IF SCHEMA_ID(N'rel') IS NULL EXEC(N'CREATE SCHEMA rel');
GO

/* ---------------------------------------------------------------------
   1. rel.vw_Attempts: the main table for the dashboard
   Flags are 0/1 integers so they can be summed directly in SQL and DAX.
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW rel.vw_Attempts AS
SELECT
    t.transaction_id,
    t.transaction_ts,
    d.full_date                                   AS txn_date,
    d.[year],
    d.month_num,
    d.year_month,
    d.day_of_week,                                -- 1 = Monday
    d.is_weekend,
    d.is_public_holiday,
    d.is_peak_season,                             -- Nov and Dec
    t.txn_hour,
    CASE WHEN t.txn_hour BETWEEN 0  AND 5  THEN 'Night (0-5)'
         WHEN t.txn_hour BETWEEN 6  AND 11 THEN 'Morning (6-11)'
         WHEN t.txn_hour BETWEEN 12 AND 14 THEN 'Midday (12-14)'
         WHEN t.txn_hour BETWEEN 15 AND 17 THEN 'Afternoon (15-17)'
         WHEN t.txn_hour BETWEEN 18 AND 20 THEN 'Evening (18-20)'
         ELSE 'Late evening (21-23)' END          AS hour_band,
    CASE WHEN t.txn_hour BETWEEN 12 AND 14
           OR t.txn_hour BETWEEN 18 AND 20 THEN 1 ELSE 0 END AS is_peak_hour,

    c.channel_name,
    c.channel_type,
    p.product_name,
    b.bank_name,
    b.bank_type,
    t.merchant_id,
    m.merchant_segment,
    l.city,
    l.[state],
    l.market_type,

    t.response_code,
    r.[description]                               AS response_description,
    r.failure_category,                           -- None, Customer, Issuer bank, Network, Platform, Fraud
    r.is_platform_fault,
    r.is_retryable,

    t.txn_status,                                 -- Success, Failed, Reversed
    CASE WHEN t.txn_status = 'Success'  THEN 1 ELSE 0 END AS is_success,
    CASE WHEN t.txn_status = 'Failed'   THEN 1 ELSE 0 END AS is_failed,
    CASE WHEN t.txn_status = 'Reversed' THEN 1 ELSE 0 END AS is_reversed,
    CASE WHEN t.txn_status <> 'Success' THEN 1 ELSE 0 END AS is_unsuccessful,   -- failed or reversed (matches Project 1)
    CASE WHEN t.txn_status = 'Failed' AND r.failure_category <> 'Customer'
         THEN 1 ELSE 0 END                        AS is_addressable_failure,    -- failures the business or its partners can influence
    CASE WHEN t.txn_status = 'Failed' AND r.is_platform_fault = 1
         THEN 1 ELSE 0 END                        AS is_platform_failure,

    t.is_retry,
    t.original_txn_id,

    t.transaction_amount_ngn,
    t.list_fee_ngn,
    t.fee_charged_ngn,
    t.processing_cost_ngn + t.switching_cost_ngn + t.bank_charge_ngn + t.other_cost_ngn AS total_cost_ngn,

    CASE WHEN t.txn_status = 'Failed' THEN t.list_fee_ngn ELSE 0 END AS fees_forgone_ngn,
    CASE WHEN t.txn_status = 'Failed' AND r.failure_category <> 'Customer'
         THEN t.list_fee_ngn ELSE 0 END           AS addressable_fees_forgone_ngn,
    CASE WHEN t.txn_status = 'Failed'
         THEN t.processing_cost_ngn + t.switching_cost_ngn + t.bank_charge_ngn + t.other_cost_ngn
         ELSE 0 END                               AS cost_on_failed_ngn
FROM fact.Transactions AS t
JOIN dim.[Date]        AS d ON d.date_key        = t.date_key
JOIN dim.Channel       AS c ON c.channel_id      = t.channel_id
JOIN dim.Product       AS p ON p.product_id      = t.product_id
JOIN dim.Bank          AS b ON b.issuer_bank_id  = t.issuer_bank_id
JOIN dim.ResponseCode  AS r ON r.response_code   = t.response_code
JOIN dim.Merchant      AS m ON m.merchant_id     = t.merchant_id
JOIN dim.Location      AS l ON l.location_key    = t.location_key;
GO

/* ---------------------------------------------------------------------
   2. rel.vw_RetryPool: first attempts that failed for a retryable reason
   Answers: how many were retried, how many recovered, how much revenue came back?
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW rel.vw_RetryPool AS
SELECT
    a.transaction_id,
    a.txn_date,
    a.[year],
    a.year_month,
    a.channel_name,
    a.bank_name,
    a.bank_type,
    a.merchant_segment,
    a.response_code,
    a.response_description,
    a.failure_category,
    a.list_fee_ngn                                           AS fee_at_stake_ngn,
    CASE WHEN rt.transaction_id IS NULL THEN 0 ELSE 1 END    AS was_retried,
    CASE WHEN rt.txn_status = 'Success' THEN 1 ELSE 0 END    AS retry_succeeded,
    CASE WHEN rt.txn_status = 'Success' THEN rt.fee_charged_ngn ELSE 0 END AS fee_recovered_ngn,
    DATEDIFF(SECOND, a.transaction_ts, rt.transaction_ts)    AS seconds_to_retry
FROM rel.vw_Attempts AS a
LEFT JOIN fact.Transactions AS rt
       ON rt.original_txn_id = a.transaction_id
WHERE a.txn_status   = 'Failed'
  AND a.is_retry     = 0
  AND a.is_retryable = 1;
GO

/* ---------------------------------------------------------------------
   3. rel.vw_MonthlyReliability: one row per month, handy for checks and trend queries
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW rel.vw_MonthlyReliability AS
SELECT
    year_month,
    MIN([year])                                            AS [year],
    MIN(month_num)                                         AS month_num,
    COUNT(*)                                               AS attempts,
    SUM(is_success)                                        AS successes,
    SUM(is_failed)                                         AS failures,
    SUM(is_reversed)                                       AS reversals,
    CAST(100.0 * SUM(is_failed)       / COUNT(*) AS DECIMAL(6,2)) AS failure_rate_pct,
    CAST(100.0 * SUM(is_unsuccessful) / COUNT(*) AS DECIMAL(6,2)) AS unsuccessful_rate_pct,
    CAST(SUM(fees_forgone_ngn)  AS DECIMAL(18,2))          AS fees_forgone_ngn,
    CAST(SUM(cost_on_failed_ngn) AS DECIMAL(18,2))         AS cost_on_failed_ngn
FROM rel.vw_Attempts
GROUP BY year_month;
GO

/* =====================================================================
   VALIDATION: run each block and compare with the expected result.
   The expected figures come from the Project 1 analysis.
   ===================================================================== */

/* 1. Row count. Expected: 1,000,151 (same as fact.Transactions) */
SELECT COUNT(*) AS attempts_in_view FROM rel.vw_Attempts;

/* 2. Did any rows drop out in the joins? Both numbers must match. */
SELECT (SELECT COUNT(*) FROM fact.Transactions) AS fact_rows,
       (SELECT COUNT(*) FROM rel.vw_Attempts)   AS view_rows;

/* 3. Yearly reliability. Expected (approximately):
      2024 -> unsuccessful 6.1% | fees forgone 6.9m | cost on failed 2.8m
      2025 -> unsuccessful 7.2% | fees forgone 9.9m | cost on failed 4.3m */
SELECT [year],
       COUNT(*)                                                       AS attempts,
       ROUND(100.0 * SUM(is_unsuccessful) / COUNT(*), 1)              AS unsuccessful_pct,
       ROUND(SUM(fees_forgone_ngn) / 1e6, 1)                          AS fees_forgone_m,
       ROUND(SUM(cost_on_failed_ngn) / 1e6, 1)                        AS cost_on_failed_m
FROM rel.vw_Attempts
GROUP BY [year]
ORDER BY [year];

/* 4. Failure categories (a quick look at what the failures are made of) */
SELECT failure_category,
       COUNT(*)                                                        AS failed_attempts,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)              AS pct_of_failures
FROM rel.vw_Attempts
WHERE is_failed = 1
GROUP BY failure_category
ORDER BY failed_attempts DESC;

/* 5. Retry pool. Check the three numbers make sense:
      retried <= pool, recovered <= retried */
SELECT COUNT(*)              AS retryable_failures,
       SUM(was_retried)      AS retried,
       SUM(retry_succeeded)  AS recovered,
       ROUND(SUM(fee_recovered_ngn) / 1e6, 2) AS fees_recovered_m
FROM rel.vw_RetryPool;