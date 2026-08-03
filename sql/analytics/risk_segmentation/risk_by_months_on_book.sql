-- Current portfolio risk by months on book.
-- One row per MOB segment.
-- MOB is calculated as full months since contract start.
-- Excludes closed contracts.

WITH mob_segments AS (
  SELECT *
  FROM (
    VALUES
      ('0-6 months', 1),
      ('7-12 months', 2),
      ('13-24 months', 3),
      ('25+ months', 4)
  ) AS segments(mob_segment, sort_order)
),
  
months AS (
  SELECT
    loan_contract_id,
    principal_amount,
    outstanding_principal,
    current_dpd,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, start_date)) * 12
    + EXTRACT(MONTH FROM AGE(CURRENT_DATE, start_date)) AS duration
  FROM portfolio_snapshot
  WHERE contract_status IN ('active', 'defaulted', 'restructured')
),
  
months_on_book AS (
  SELECT
    *,
    CASE
      WHEN duration <= 6 THEN '0-6 months'
      WHEN duration <= 12 THEN '7-12 months'
      WHEN duration <= 24 THEN '13-24 months'
      ELSE '25+ months'
    END AS mob_segment
  FROM months
)

SELECT
  ms.mob_segment,

  COUNT(mob.loan_contract_id) AS contract_count,

  COALESCE(SUM(mob.principal_amount), 0) AS total_principal,

  COALESCE(SUM(mob.outstanding_principal), 0) AS total_outstanding,

  ROUND(
  COALESCE(SUM(mob.outstanding_principal), 0)::NUMERIC
  / NULLIF(
      SUM(SUM(mob.outstanding_principal)) OVER (),
      0
    )
  * 100,
  2
) AS share_of_outstanding_pct,

  COUNT(mob.loan_contract_id)
    FILTER (WHERE mob.current_dpd > 0) AS delinquent_contracts,

  ROUND(
    COUNT(mob.loan_contract_id)
      FILTER (WHERE mob.current_dpd > 0)::NUMERIC
    / NULLIF(COUNT(mob.loan_contract_id), 0)
    * 100,
    2
  ) AS delinquency_rate_pct,

  COUNT(mob.loan_contract_id)
    FILTER (WHERE mob.current_dpd >= 30) AS dpd_30_plus_contracts,

  ROUND(
    COUNT(mob.loan_contract_id)
      FILTER (WHERE mob.current_dpd >= 30)::NUMERIC
    / NULLIF(COUNT(mob.loan_contract_id), 0)
    * 100,
    2
  ) AS dpd_30_plus_rate_pct,

  ROUND(
    COALESCE(
      SUM(mob.outstanding_principal)
        FILTER (WHERE mob.current_dpd >= 30),
      0
    )::NUMERIC
    / NULLIF(SUM(mob.outstanding_principal), 0)
    * 100,
    2
  ) AS par_30_pct,

  ROUND(
    COALESCE(AVG(mob.outstanding_principal), 0),
    2
  ) AS average_outstanding

FROM mob_segments ms
LEFT JOIN months_on_book mob
  ON ms.mob_segment = mob.mob_segment

GROUP BY
  ms.mob_segment,
  ms.sort_order

ORDER BY
  ms.sort_order;
