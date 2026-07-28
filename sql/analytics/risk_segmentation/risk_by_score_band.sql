-- Risk analysis by score band.
-- Compares original application scores with observed delinquency and default outcomes.
-- Includes contract-level risk rates and outstanding exposure by score band.
-- Grain: one row per score band.

SET search_path TO credit_portfolio;

WITH score_bands (score_band, sort_order) AS (
    VALUES
        ('350-449', 1),
        ('450-549', 2),
        ('550-649', 3),
        ('650-749', 4),
        ('750-850', 5)
),

application_score_bands AS (
    SELECT
        aps.loan_application_id,
        aps.score,
        aps.probability_of_default,
        CASE
            WHEN aps.score BETWEEN 350 AND 449 THEN '350-449'
            WHEN aps.score BETWEEN 450 AND 549 THEN '450-549'
            WHEN aps.score BETWEEN 550 AND 649 THEN '550-649'
            WHEN aps.score BETWEEN 650 AND 749 THEN '650-749'
            WHEN aps.score BETWEEN 750 AND 850 THEN '750-850'
        END AS score_band
    FROM application_scores aps
),

contract_score_snapshot AS (
    SELECT
        lc.loan_contract_id,
        lc.contract_status,
        aps.score,
        aps.probability_of_default,
        aps.score_band,
        ps.outstanding_principal,
        ps.max_dpd
    FROM loan_contracts lc
    LEFT JOIN application_score_bands aps
        ON aps.loan_application_id = lc.loan_application_id
    LEFT JOIN portfolio_snapshot ps
        ON ps.loan_contract_id = lc.loan_contract_id
)

SELECT
    sb.score_band,
    COUNT(cs.loan_contract_id) AS total_contracts,
    ROUND(AVG(cs.score), 2) AS avg_score,
    ROUND(AVG(cs.probability_of_default) * 100, 2) AS avg_pd_pct,

    COUNT(cs.loan_contract_id)
        FILTER (WHERE cs.max_dpd >= 30)
        AS ever_dpd_30_plus_contracts,

    COUNT(cs.loan_contract_id)
        FILTER (WHERE cs.max_dpd >= 90)
        AS ever_dpd_90_plus_contracts,

    COUNT(cs.loan_contract_id)
        FILTER (WHERE cs.contract_status = 'defaulted')
        AS status_defaulted_contracts,

    ROUND(
        (
            COUNT(cs.loan_contract_id)
                FILTER (WHERE cs.max_dpd >= 30)
        )::NUMERIC
        / NULLIF(COUNT(cs.loan_contract_id), 0)
        * 100,
        2
    ) AS ever_dpd_30_plus_rate_pct,

    ROUND(
        (
            COUNT(cs.loan_contract_id)
                FILTER (WHERE cs.max_dpd >= 90)
        )::NUMERIC
        / NULLIF(COUNT(cs.loan_contract_id), 0)
        * 100,
        2
    ) AS ever_dpd_90_plus_rate_pct,

    ROUND(
        (
            COUNT(cs.loan_contract_id)
                FILTER (WHERE cs.contract_status = 'defaulted')
        )::NUMERIC
        / NULLIF(COUNT(cs.loan_contract_id), 0)
        * 100,
        2
    ) AS status_default_rate_pct,

    COALESCE(
        SUM(cs.outstanding_principal),
        0
    ) AS total_outstanding,

    COALESCE(
        SUM(cs.outstanding_principal)
            FILTER (WHERE cs.max_dpd >= 30),
        0
    ) AS ever_dpd_30_plus_outstanding,

    ROUND(
        COALESCE(
            SUM(cs.outstanding_principal)
                FILTER (WHERE cs.max_dpd >= 30),
            0
        )
        / NULLIF(SUM(cs.outstanding_principal), 0)
        * 100,
        2
    ) AS ever_dpd_30_plus_outstanding_share_pct,

    COALESCE(
        SUM(cs.outstanding_principal)
            FILTER (WHERE cs.max_dpd >= 90),
        0
    ) AS ever_dpd_90_plus_outstanding,

    ROUND(
        COALESCE(
            SUM(cs.outstanding_principal)
                FILTER (WHERE cs.max_dpd >= 90),
            0
        )
        / NULLIF(SUM(cs.outstanding_principal), 0)
        * 100,
        2
    ) AS ever_dpd_90_plus_outstanding_share_pct

FROM score_bands sb
LEFT JOIN contract_score_snapshot cs
    ON cs.score_band = sb.score_band
GROUP BY
    sb.score_band,
    sb.sort_order
ORDER BY
    sb.sort_order;
