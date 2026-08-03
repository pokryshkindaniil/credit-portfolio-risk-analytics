-- Credit risk metrics by original loan size.
-- One row per loan size segment.
-- Excludes closed contracts.

WITH loan_size_segments AS (
  SELECT *
  FROM (
    VALUES
      ('Up to 1M', 1),
      ('1M-3M', 2),
      ('3M+', 3)
  ) AS segments(loan_size_segment, sort_order)
),

portfolio_by_size AS (
  SELECT
    loan_contract_id,
    principal_amount,
    outstanding_principal,
    current_dpd,
    CASE
      WHEN principal_amount <= 1000000 THEN 'Up to 1M'
      WHEN principal_amount <= 3000000 THEN '1M-3M'
      ELSE '3M+'
    END AS loan_size_segment
  FROM portfolio_snapshot
  WHERE contract_status IN ('active', 'defaulted', 'restructured')
)

SELECT
  ls.loan_size_segment,

  COUNT(p.loan_contract_id) AS contract_count,

  COALESCE(SUM(p.principal_amount), 0) AS total_principal,

  COALESCE(SUM(p.outstanding_principal), 0) AS total_outstanding,

  COUNT(p.loan_contract_id)
    FILTER (WHERE p.current_dpd > 0) AS delinquent_contracts,

  ROUND(
    COUNT(p.loan_contract_id)
      FILTER (WHERE p.current_dpd > 0)::NUMERIC
    / NULLIF(COUNT(p.loan_contract_id), 0)
    * 100,
    2
  ) AS delinquency_rate_pct,

  COUNT(p.loan_contract_id)
    FILTER (WHERE p.current_dpd >= 30) AS dpd_30_plus_contracts,

  ROUND(
    COUNT(p.loan_contract_id)
      FILTER (WHERE p.current_dpd >= 30)::NUMERIC
    / NULLIF(COUNT(p.loan_contract_id), 0)
    * 100,
    2
  ) AS dpd_30_plus_rate_pct,

  ROUND(
    COALESCE(
      SUM(p.outstanding_principal)
        FILTER (WHERE p.current_dpd >= 30),
      0
    )::NUMERIC
    / NULLIF(SUM(p.outstanding_principal), 0)
    * 100,
    2
  ) AS par_30_pct,

  ROUND(
    COALESCE(AVG(p.outstanding_principal), 0),
    2
  ) AS average_outstanding

FROM loan_size_segments ls
LEFT JOIN portfolio_by_size p
  ON p.loan_size_segment = ls.loan_size_segment

GROUP BY
  ls.loan_size_segment,
  ls.sort_order

ORDER BY
  ls.sort_order;
