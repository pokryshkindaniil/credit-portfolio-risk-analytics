-- Current portfolio risk KPIs.
-- One row for the entire portfolio.
-- Excludes closed contracts.

SELECT
  CURRENT_DATE AS report_date,
  COUNT(*) AS total_contracts,
  ROUND(COALESCE(SUM(principal_amount), 0), 2) AS total_principal,
  ROUND(COALESCE(SUM(outstanding_principal), 0), 2) AS total_outstanding,
  ROUND(COALESCE(SUM(overdue_principal), 0), 2) AS total_overdue,
  COUNT(*) FILTER (WHERE current_dpd > 0) AS delinquent_contracts,
  ROUND((COUNT(*) FILTER (WHERE current_dpd > 0))::NUMERIC / 
    NULLIF(COUNT(*), 0) * 100, 2) AS delinquency_rate_pct,
  COUNT(*) FILTER (WHERE current_dpd >= 30) AS dpd_30_plus_contracts,
  ROUND((COUNT(*) FILTER (WHERE current_dpd >= 30))::NUMERIC / 
    NULLIF(COUNT(*), 0) * 100, 2) AS dpd_30_plus_rate_pct,
  COUNT(*) FILTER (WHERE current_dpd >= 90) AS dpd_90_plus_contracts,
  ROUND((COUNT(*) FILTER (WHERE current_dpd >= 90))::NUMERIC / 
    NULLIF(COUNT(*), 0) * 100, 2) AS dpd_90_plus_rate_pct,
  ROUND((COALESCE(SUM(outstanding_principal) FILTER (WHERE current_dpd >= 30), 0))::NUMERIC / 
    NULLIF(SUM(outstanding_principal), 0) * 100, 2) AS par_30_pct,
  ROUND((COALESCE(SUM(outstanding_principal) FILTER (WHERE current_dpd >= 90), 0))::NUMERIC / 
    NULLIF(SUM(outstanding_principal), 0) * 100, 2) AS par_90_pct,
  ROUND(SUM(overdue_principal)::NUMERIC / NULLIF(SUM(outstanding_principal), 0) * 100, 2) AS overdue_share_pct
FROM
  portfolio_snapshot
WHERE contract_status IN ('active', 'defaulted', 'restructured');
