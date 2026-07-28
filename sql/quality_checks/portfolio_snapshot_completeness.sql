-- Portfolio snapshot completeness check.
-- Flags loan contracts missing from the portfolio snapshot.
-- A valid snapshot should return no rows.
-- Grain: one row per missing loan contract.

SELECT
  lc.loan_contract_id,
  lc.contract_number,
  lc.contract_status
FROM loan_contracts lc
LEFT JOIN portfolio_snapshot ps ON ps.loan_contract_id = lc.loan_contract_id
WHERE ps.loan_contract_id IS NULL
