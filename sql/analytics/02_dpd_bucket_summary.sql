-- Руководителю кредитных рисков нужен отчёт о распределении текущего кредитного портфеля по уровням просрочки. 

WITH dpd_buckets(dpd_bucket, sort_order) AS (
    VALUES
        ('Current', 1),
        ('1-30', 2),
        ('31-60', 3),
        ('61-90', 4),
        ('90+', 5)
)

SELECT
  db.dpd_bucket,
  COUNT(ps.loan_contract_id) AS contract_count,
  COALESCE(SUM(ps.principal_amount), 0) AS total_principal,
  COALESCE(SUM(ps.outstanding_principal), 0) AS outstanding_principal,
  COALESCE(SUM(ps.overdue_principal), 0) AS overdue_principal,
  ROUND(COUNT(ps.loan_contract_id)::NUMERIC / 
    (
      SELECT COUNT(*) 
      FROM portfolio_snapshot 
      WHERE contract_status IN ('active', 'defaulted', 'restructured')
    )* 100, 2) AS share_of_contracts_pct,
  ROUND(COALESCE(SUM(ps.outstanding_principal), 0)::NUMERIC / NULLIF(
    (
      SELECT SUM(outstanding_principal)
      FROM portfolio_snapshot
      WHERE contract_status IN ('active', 'defaulted', 'restructured')
    ), 0) * 100, 2) AS share_of_outstanding_pct
FROM portfolio_snapshot ps
RIGHT JOIN dpd_buckets db ON ps.dpd_bucket = db.dpd_bucket AND contract_status IN ('active', 'defaulted', 'restructured')
GROUP BY db.dpd_bucket, db.sort_order
ORDER BY db.sort_order
