/* =====================================================================
   PayBridge NG | Project 2: Payment Reliability & Failed Transactions
   Script 02: Explore and check the data (Step 3)
   Run each block separately in SSMS and compare with the expected result.
   Part A tests that the data is internally consistent (cleaning checks).
   Part B describes its shape (exploration).
   ===================================================================== */

USE PayBridgeDB;
GO

/* =====================================================================
   PART A: CONSISTENCY CHECKS
   ===================================================================== */

/* A1. Status and response code must agree.
       Expected: 0 violations. */
SELECT COUNT(*) AS violations
FROM rel.vw_Attempts
WHERE (txn_status = 'Success'  AND response_code <> '00')
   OR (txn_status = 'Reversed' AND response_code <> 'RV')
   OR (txn_status = 'Failed'   AND response_code IN ('00', 'RV'));

/* A2. Fee logic.
       Expected: both counts 0 (only successful attempts earn a fee, and every success earns one). */
SELECT SUM(CASE WHEN txn_status <> 'Success' AND fee_charged_ngn <> 0 THEN 1 ELSE 0 END) AS non_success_with_fee,
       SUM(CASE WHEN txn_status = 'Success'  AND fee_charged_ngn <= 0 THEN 1 ELSE 0 END) AS success_without_fee
FROM fact.Transactions;

/* A3. Cost logic on failures.
       Expected: bank charge is never incurred on a failure (0), and "other" cost on a failure
       appears only on channel 4 (USSD), so the second query should return a single row. */
SELECT COUNT(*) AS failed_with_bank_charge
FROM fact.Transactions
WHERE txn_status = 'Failed' AND bank_charge_ngn <> 0;

SELECT channel_id, COUNT(*) AS failed_with_other_cost
FROM fact.Transactions
WHERE txn_status = 'Failed' AND other_cost_ngn > 0
GROUP BY channel_id;

/* A4. Retry integrity.
       Expected: retries = 16,235 (matches the retry pool), and every other column is 0. */
SELECT COUNT(*)                                                             AS retries,
       SUM(CASE WHEN o.transaction_id IS NULL THEN 1 ELSE 0 END)            AS orphan_retries,
       SUM(CASE WHEN o.txn_status <> 'Failed' THEN 1 ELSE 0 END)            AS retry_of_a_non_failure,
       SUM(CASE WHEN rt.transaction_ts < o.transaction_ts THEN 1 ELSE 0 END) AS retry_before_original,
       SUM(CASE WHEN rt.date_key <> o.date_key THEN 1 ELSE 0 END)           AS retry_on_a_different_day
FROM fact.Transactions AS rt
LEFT JOIN fact.Transactions AS o ON o.transaction_id = rt.original_txn_id
WHERE rt.is_retry = 1;

/* A5. Expected missing values.
       Expected: all four counts 0. */
SELECT SUM(CASE WHEN channel_id = 1  AND terminal_id IS NULL     THEN 1 ELSE 0 END) AS pos_without_terminal,
       SUM(CASE WHEN channel_id <> 1 AND terminal_id IS NOT NULL THEN 1 ELSE 0 END) AS non_pos_with_terminal,
       SUM(CASE WHEN txn_status = 'Success'  AND settlement_date_key IS NULL     THEN 1 ELSE 0 END) AS success_without_settlement,
       SUM(CASE WHEN txn_status <> 'Success' AND settlement_date_key IS NOT NULL THEN 1 ELSE 0 END) AS other_with_settlement
FROM fact.Transactions;


/* =====================================================================
   PART B: EXPLORATION (what does the data look like?)
   ===================================================================== */

/* B1. Outcome mix by year. Reversals should be under 1%. */
SELECT [year], txn_status,
       COUNT(*) AS attempts,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY [year]), 2) AS pct_of_year
FROM rel.vw_Attempts
GROUP BY [year], txn_status
ORDER BY [year], txn_status;

/* B2. Response codes. Which codes appear, and how often? */
SELECT response_code, response_description, failure_category,
       COUNT(*) AS attempts
FROM rel.vw_Attempts
GROUP BY response_code, response_description, failure_category
ORDER BY attempts DESC;

/* B3. Volume by channel. This is the denominator for every failure rate by channel. */
SELECT channel_name,
       COUNT(*) AS attempts,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_attempts
FROM rel.vw_Attempts
GROUP BY channel_name
ORDER BY attempts DESC;

/* B4. Volume by hour band. Night should be quiet, and midday and evening busy. */
SELECT hour_band,
       COUNT(*) AS attempts,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_attempts
FROM rel.vw_Attempts
GROUP BY hour_band
ORDER BY attempts DESC;

/* B5. Monthly volume. December should be the highest month in each year. */
SELECT year_month, attempts, failure_rate_pct, unsuccessful_rate_pct
FROM rel.vw_MonthlyReliability
ORDER BY year_month;

/* B6. Ticket sizes in naira. Look for odd values (zero, negative or absurdly large). */
SELECT CASE WHEN transaction_amount_ngn <      1000 THEN '1) under 1,000'
            WHEN transaction_amount_ngn <      5000 THEN '2) 1,000 to 4,999'
            WHEN transaction_amount_ngn <     20000 THEN '3) 5,000 to 19,999'
            WHEN transaction_amount_ngn <    100000 THEN '4) 20,000 to 99,999'
            WHEN transaction_amount_ngn <   1000000 THEN '5) 100,000 to 999,999'
            ELSE '6) 1,000,000 and above' END AS amount_band,
       COUNT(*) AS attempts
FROM fact.Transactions
GROUP BY CASE WHEN transaction_amount_ngn <      1000 THEN '1) under 1,000'
              WHEN transaction_amount_ngn <      5000 THEN '2) 1,000 to 4,999'
              WHEN transaction_amount_ngn <     20000 THEN '3) 5,000 to 19,999'
              WHEN transaction_amount_ngn <    100000 THEN '4) 20,000 to 99,999'
              WHEN transaction_amount_ngn <   1000000 THEN '5) 100,000 to 999,999'
              ELSE '6) 1,000,000 and above' END
ORDER BY amount_band;