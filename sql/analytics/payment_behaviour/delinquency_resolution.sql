-- Delinquency resolution by maximum DPD bucket.
-- One row per DPD bucket.
-- Closed events are evaluated by time to resolution.
-- Open events are evaluated by age as of the report date.

SET search_path TO credit_portfolio;

WITH params AS (
    SELECT DATE '2026-07-25' AS report_date
),

dpd_buckets(dpd_bucket, sort_order) AS (
    VALUES
        ('1-7', 1),
        ('8-30', 2),
        ('31-60', 3),
        ('61-90', 4),
        ('91+', 5)
),

delinquency_snapshot AS (
    SELECT
        de.delinquency_event_id,
        de.delinquency_status AS event_status,
        de.max_dpd,

        CASE
            WHEN de.delinquency_status = 'closed'
                THEN de.delinquency_end_date
                    - de.delinquency_start_date
        END AS days_to_resolution,

        CASE
            WHEN de.delinquency_status = 'open'
                THEN p.report_date
                    - de.delinquency_start_date
        END AS open_duration_days,

        CASE
            WHEN de.max_dpd BETWEEN 1 AND 7 THEN '1-7'
            WHEN de.max_dpd BETWEEN 8 AND 30 THEN '8-30'
            WHEN de.max_dpd BETWEEN 31 AND 60 THEN '31-60'
            WHEN de.max_dpd BETWEEN 61 AND 90 THEN '61-90'
            WHEN de.max_dpd > 90 THEN '91+'
        END AS dpd_bucket

    FROM delinquency_events de

    CROSS JOIN params p

    WHERE de.max_dpd > 0
),

delinquency_summary AS (
    SELECT
        db.dpd_bucket,
        db.sort_order,

        COUNT(ds.delinquency_event_id) AS total_events,

        COUNT(ds.delinquency_event_id)
            FILTER (WHERE ds.event_status = 'closed')
            AS closed_events,

        COUNT(ds.delinquency_event_id)
            FILTER (WHERE ds.event_status = 'open')
            AS open_events,

        ROUND(
            COUNT(ds.delinquency_event_id)
                FILTER (WHERE ds.event_status = 'closed')::NUMERIC
            / NULLIF(COUNT(ds.delinquency_event_id), 0)
            * 100,
            2
        ) AS resolution_rate_pct,

        ROUND(
            AVG(ds.days_to_resolution)
                FILTER (WHERE ds.event_status = 'closed'),
            2
        ) AS avg_days_to_resolution,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY ds.days_to_resolution)
            FILTER (WHERE ds.event_status = 'closed')
            AS median_days_to_resolution,

        ROUND(
            AVG(ds.open_duration_days)
                FILTER (WHERE ds.event_status = 'open'),
            2
        ) AS avg_open_duration_days

    FROM dpd_buckets db

    LEFT JOIN delinquency_snapshot ds
        ON ds.dpd_bucket = db.dpd_bucket

    GROUP BY
        db.dpd_bucket,
        db.sort_order
)

SELECT
    dpd_bucket,
    total_events,
    closed_events,
    open_events,
    resolution_rate_pct,
    avg_days_to_resolution,
    median_days_to_resolution,
    avg_open_duration_days

FROM delinquency_summary

ORDER BY
    sort_order;
