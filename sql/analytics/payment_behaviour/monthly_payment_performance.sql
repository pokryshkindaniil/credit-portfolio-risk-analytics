-- Monthly payment performance by scheduled due month.
-- One row per calendar month with installments due by the report date.
-- Future installments are excluded from monthly performance metrics.
-- Payments are attributed to the month of the scheduled due date.

SET search_path TO credit_portfolio;

WITH payment_base AS (
  SELECT
    ps.payment_schedule_id,
    ps.loan_contract_id,
    ps.due_date,
    p.payment_date,
    ps.total_due AS scheduled_amount,
    COALESCE(p.payment_amount, 0) AS paid_amount,
    p.payment_status,
    DATE_TRUNC('month', ps.due_date)::DATE AS payment_month,

    CASE
      WHEN ps.due_date > CURRENT_DATE
        THEN 'not_due'
      WHEN p.payment_date IS NULL
        THEN 'unpaid'
      WHEN p.payment_date <= ps.due_date
        THEN 'on_time'
      ELSE 'late'
    END AS payment_state,

    CASE
      WHEN p.payment_date > ps.due_date
        THEN p.payment_date - ps.due_date
      ELSE NULL
    END AS payment_delay_days

  FROM payment_schedule ps

  LEFT JOIN payments p
    ON p.payment_schedule_id = ps.payment_schedule_id
    AND p.payment_status = 'posted'
)

SELECT
  payment_month,

  COUNT(*) AS scheduled_installments,

  COUNT(*)
    FILTER (WHERE payment_state IN ('on_time', 'late'))
    AS paid_installments,

  COUNT(*)
    FILTER (WHERE payment_state = 'on_time')
    AS on_time_installments,

  COUNT(*)
    FILTER (WHERE payment_state = 'late')
    AS late_installments,

  COUNT(*)
    FILTER (WHERE payment_state = 'unpaid')
    AS unpaid_installments,

  SUM(scheduled_amount) AS scheduled_amount,
  SUM(paid_amount) AS paid_amount,

  ROUND(
    COUNT(*) FILTER (WHERE payment_state = 'on_time')::NUMERIC
    / NULLIF(COUNT(*), 0)
    * 100,
    2
  ) AS on_time_payment_rate_pct,

  ROUND(
    SUM(paid_amount)::NUMERIC
    / NULLIF(SUM(scheduled_amount), 0)
    * 100,
    2
  ) AS collection_rate_pct,

  ROUND(
    AVG(payment_delay_days)
      FILTER (WHERE payment_state = 'late'),
    2
  ) AS average_payment_delay_days

FROM payment_base

WHERE payment_state <> 'not_due'

GROUP BY
  payment_month

ORDER BY
  payment_month;
