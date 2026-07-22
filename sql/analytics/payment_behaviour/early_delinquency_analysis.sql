-- Early delinquency timing and lifetime credit performance.
-- One row per delinquency timing group.
-- Includes all contracts, including closed contracts.

SET search_path TO credit_portfolio;

WITH contract_delinquency AS (
  SELECT
    lc.loan_contract_id,
    lc.contract_status,

    MIN(ps.installment_number)
      FILTER (WHERE de.delinquency_event_id IS NOT NULL)
      AS first_delinquency_installment,

    COALESCE(MAX(de.max_dpd), 0) AS max_dpd_lifetime

  FROM loan_contracts lc

  LEFT JOIN payment_schedule ps
    ON ps.loan_contract_id = lc.loan_contract_id

  LEFT JOIN delinquency_events de
    ON de.payment_schedule_id = ps.payment_schedule_id

  GROUP BY
    lc.loan_contract_id,
    lc.contract_status
),

classified_contracts AS (
  SELECT
    loan_contract_id,
    contract_status,
    first_delinquency_installment,
    max_dpd_lifetime,

    CASE
      WHEN first_delinquency_installment IS NULL
        THEN 'No delinquency'
      WHEN first_delinquency_installment <= 3
        THEN 'First 3 installments'
      ELSE 'After 3 installments'
    END AS delinquency_timing

  FROM contract_delinquency
)

SELECT
  delinquency_timing,

  COUNT(*) AS contract_count,

  ROUND(
    COUNT(*)::NUMERIC
    / NULLIF(SUM(COUNT(*)) OVER (), 0)
    * 100,
    2
  ) AS share_of_contracts_pct,

  COUNT(*)
    FILTER (WHERE max_dpd_lifetime > 30)
    AS ever_30_plus_contracts,

  ROUND(
    COUNT(*) FILTER (WHERE max_dpd_lifetime > 30)::NUMERIC
    / NULLIF(COUNT(*), 0)
    * 100,
    2
  ) AS ever_30_plus_rate_pct,

  COUNT(*)
    FILTER (WHERE max_dpd_lifetime > 90)
    AS ever_90_plus_contracts,

  ROUND(
    COUNT(*) FILTER (WHERE max_dpd_lifetime > 90)::NUMERIC
    / NULLIF(COUNT(*), 0)
    * 100,
    2
  ) AS ever_90_plus_rate_pct,

  COUNT(*)
    FILTER (WHERE contract_status = 'defaulted')
    AS defaulted_contracts,

  ROUND(
    COUNT(*) FILTER (WHERE contract_status = 'defaulted')::NUMERIC
    / NULLIF(COUNT(*), 0)
    * 100,
    2
  ) AS default_rate_pct

FROM classified_contracts

GROUP BY
  delinquency_timing

ORDER BY
  CASE delinquency_timing
    WHEN 'No delinquency' THEN 1
    WHEN 'First 3 installments' THEN 2
    WHEN 'After 3 installments' THEN 3
  END;
