-- Portfolio snapshot grain check.
-- Flags loan contracts represented by more than one row in the portfolio snapshot.
-- A valid snapshot should return no rows.
-- Grain: one row per duplicated loan contract.

SET search_path TO credit_portfolio;

SELECT
    loan_contract_id,
    COUNT(*) AS row_count
FROM portfolio_snapshot
GROUP BY loan_contract_id
HAVING COUNT(*) > 1;
