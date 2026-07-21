-- ============================================================
-- Synthetic credit portfolio generator
-- Inserts: 1,000 customers and 1,000 loan contracts
-- Plus dependent income, applications, scores, decisions,
-- collateral, disbursements, payment schedules, payments,
-- and delinquency events.
--
-- Safe behaviour:
-- - does not delete existing data;
-- - every run creates a new synthetic batch;
-- - all inserts are wrapped in one transaction.
-- ============================================================

BEGIN;

SET LOCAL search_path TO credit_portfolio, public;

-- Reproducible random distribution within this run.
-- Change the seed if you want a different portfolio profile.
SELECT setseed(0.260721);

-- One row with the batch identifier and portfolio snapshot date.
CREATE TEMP TABLE tmp_generation_run AS
SELECT
    (
        TO_CHAR(clock_timestamp(), 'YYYYMMDDHH24MISSMS')
        || '-'
        || SUBSTRING(MD5(random()::TEXT), 1, 6)
    ) AS run_key,
    CURRENT_DATE AS as_of_date;

-- ============================================================
-- 1. Generate the source attributes for 1,000 contracts
-- ============================================================

CREATE TEMP TABLE tmp_contract_seed AS
WITH raw AS MATERIALIZED (
    SELECT
        gs AS row_no,
        random() AS r_first_name,
        random() AS r_last_name,
        random() AS r_sex,
        random() AS r_birth,
        random() AS r_city,
        random() AS r_occupation,
        random() AS r_income,
        random() AS r_loan_type,
        random() AS r_amount,
        random() AS r_term,
        random() AS r_rate,
        random() AS r_start,
        random() AS r_score,
        random() AS r_pd_noise,
        random() AS r_behaviour,
        random() AS r_status,
        random() AS r_condition,
        random() AS r_verification
    FROM generate_series(1, 1000) AS gs
),
profile AS (
    SELECT
        r.*,
        gr.run_key,
        gr.as_of_date,

        CASE floor(r.r_first_name * 12)::INT
            WHEN 0 THEN 'Александр'
            WHEN 1 THEN 'Михаил'
            WHEN 2 THEN 'Дмитрий'
            WHEN 3 THEN 'Иван'
            WHEN 4 THEN 'Максим'
            WHEN 5 THEN 'Алексей'
            WHEN 6 THEN 'Анна'
            WHEN 7 THEN 'Мария'
            WHEN 8 THEN 'Елена'
            WHEN 9 THEN 'Ольга'
            WHEN 10 THEN 'Наталья'
            ELSE 'Екатерина'
        END AS first_name,

        CASE floor(r.r_last_name * 14)::INT
            WHEN 0 THEN 'Иванов'
            WHEN 1 THEN 'Петров'
            WHEN 2 THEN 'Смирнов'
            WHEN 3 THEN 'Кузнецов'
            WHEN 4 THEN 'Попов'
            WHEN 5 THEN 'Соколов'
            WHEN 6 THEN 'Лебедев'
            WHEN 7 THEN 'Козлов'
            WHEN 8 THEN 'Новиков'
            WHEN 9 THEN 'Морозов'
            WHEN 10 THEN 'Волков'
            WHEN 11 THEN 'Орлов'
            WHEN 12 THEN 'Макаров'
            ELSE 'Павлов'
        END AS last_name,

        CASE
            WHEN r.r_sex < 0.49 THEN 'male'
            WHEN r.r_sex < 0.98 THEN 'female'
            WHEN r.r_sex < 0.99 THEN 'other'
            ELSE 'not_specified'
        END AS sex,

        (
            DATE '1955-01-01'
            + floor(r.r_birth * (DATE '2003-12-31' - DATE '1955-01-01'))::INT
        ) AS birth_date,

        CASE floor(r.r_city * 12)::INT
            WHEN 0 THEN 'Москва'
            WHEN 1 THEN 'Санкт-Петербург'
            WHEN 2 THEN 'Архангельск'
            WHEN 3 THEN 'Казань'
            WHEN 4 THEN 'Екатеринбург'
            WHEN 5 THEN 'Новосибирск'
            WHEN 6 THEN 'Нижний Новгород'
            WHEN 7 THEN 'Самара'
            WHEN 8 THEN 'Ростов-на-Дону'
            WHEN 9 THEN 'Краснодар'
            WHEN 10 THEN 'Пермь'
            ELSE 'Воронеж'
        END AS city,

        CASE floor(r.r_occupation * 10)::INT
            WHEN 0 THEN 'Инженер'
            WHEN 1 THEN 'Аналитик'
            WHEN 2 THEN 'Менеджер'
            WHEN 3 THEN 'Врач'
            WHEN 4 THEN 'Преподаватель'
            WHEN 5 THEN 'Разработчик'
            WHEN 6 THEN 'Предприниматель'
            WHEN 7 THEN 'Бухгалтер'
            WHEN 8 THEN 'Водитель'
            ELSE 'Специалист'
        END AS occupation,

        ROUND(
            (
                45000
                + POWER(r.r_income, 1.70) * 455000
            )::NUMERIC,
            -2
        ) AS monthly_income,

        CASE
            WHEN r.r_loan_type < 0.50 THEN 'consumer_loan'
            WHEN r.r_loan_type < 0.80 THEN 'auto_loan'
            ELSE 'mortgage'
        END AS loan_type,

        (
            DATE '2022-01-01'
            + floor(
                r.r_start
                * (
                    (gr.as_of_date - 30)
                    - DATE '2022-01-01'
                )
            )::INT
        ) AS start_date,

        (350 + floor(r.r_score * 501)::INT)::SMALLINT AS score
    FROM raw AS r
    CROSS JOIN tmp_generation_run AS gr
),
loan_terms AS (
    SELECT
        p.*,

        CASE p.loan_type
            WHEN 'consumer_loan' THEN
                CASE floor(p.r_term * 3)::INT
                    WHEN 0 THEN 12
                    WHEN 1 THEN 24
                    ELSE 36
                END
            WHEN 'auto_loan' THEN
                CASE floor(p.r_term * 4)::INT
                    WHEN 0 THEN 24
                    WHEN 1 THEN 36
                    WHEN 2 THEN 48
                    ELSE 60
                END
            ELSE
                CASE floor(p.r_term * 4)::INT
                    WHEN 0 THEN 60
                    WHEN 1 THEN 120
                    WHEN 2 THEN 180
                    ELSE 240
                END
        END::SMALLINT AS term_months,

        ROUND(
            CASE p.loan_type
                WHEN 'consumer_loan'
                    THEN (100000 + p.r_amount * 1400000)::NUMERIC
                WHEN 'auto_loan'
                    THEN (800000 + p.r_amount * 4200000)::NUMERIC
                ELSE (2500000 + p.r_amount * 12500000)::NUMERIC
            END,
            -3
        ) AS requested_amount,

        ROUND(
            CASE p.loan_type
                WHEN 'consumer_loan'
                    THEN (19 + p.r_rate * 20)::NUMERIC
                WHEN 'auto_loan'
                    THEN (14 + p.r_rate * 16)::NUMERIC
                ELSE (9 + p.r_rate * 10)::NUMERIC
            END,
            4
        ) AS interest_rate
    FROM profile AS p
),
loan_values AS (
    SELECT
        lt.*,

        CASE
            WHEN lt.loan_type = 'consumer_loan' THEN 0::NUMERIC
            WHEN lt.loan_type = 'auto_loan' THEN
                ROUND(
                    (
                        (
                            lt.requested_amount
                            / (1 - (0.10 + lt.r_condition * 0.20))
                        )
                        * (0.10 + lt.r_condition * 0.20)
                    )::NUMERIC,
                    2
                )
            ELSE
                ROUND(
                    (
                        (
                            lt.requested_amount
                            / (1 - (0.15 + lt.r_condition * 0.20))
                        )
                        * (0.15 + lt.r_condition * 0.20)
                    )::NUMERIC,
                    2
                )
        END AS down_payment,

        CASE
            WHEN lt.loan_type = 'consumer_loan' THEN NULL::NUMERIC
            WHEN lt.loan_type = 'auto_loan' THEN
                ROUND(
                    (
                        lt.requested_amount
                        / (1 - (0.10 + lt.r_condition * 0.20))
                    )::NUMERIC,
                    2
                )
            ELSE
                ROUND(
                    (
                        lt.requested_amount
                        / (1 - (0.15 + lt.r_condition * 0.20))
                    )::NUMERIC,
                    2
                )
        END AS asset_value,

        (
            EXTRACT(YEAR FROM age(lt.as_of_date, lt.start_date))::INT * 12
            + EXTRACT(MONTH FROM age(lt.as_of_date, lt.start_date))::INT
        ) AS months_on_book,

        ROUND(
            GREATEST(
                0.005,
                LEAST(
                    0.600,
                    0.450
                    - (lt.score - 350) * 0.0008
                    + (lt.r_pd_noise - 0.5) * 0.05
                )
            )::NUMERIC,
            6
        ) AS probability_of_default
    FROM loan_terms AS lt
),
initial_behaviour AS (
    SELECT
        lv.*,

        LEAST(
            lv.term_months::INT,
            GREATEST(0, lv.months_on_book)
        ) AS due_installments,

        CASE
            WHEN lv.score >= 720 THEN
                CASE
                    WHEN lv.r_behaviour < 0.82 THEN 'good'
                    WHEN lv.r_behaviour < 0.96 THEN 'mild_late'
                    ELSE 'dpd_30'
                END
            WHEN lv.score >= 620 THEN
                CASE
                    WHEN lv.r_behaviour < 0.62 THEN 'good'
                    WHEN lv.r_behaviour < 0.84 THEN 'mild_late'
                    WHEN lv.r_behaviour < 0.94 THEN 'dpd_30'
                    WHEN lv.r_behaviour < 0.985 THEN 'dpd_60'
                    ELSE 'default'
                END
            WHEN lv.score >= 520 THEN
                CASE
                    WHEN lv.r_behaviour < 0.38 THEN 'good'
                    WHEN lv.r_behaviour < 0.62 THEN 'mild_late'
                    WHEN lv.r_behaviour < 0.78 THEN 'dpd_30'
                    WHEN lv.r_behaviour < 0.90 THEN 'dpd_60'
                    WHEN lv.r_behaviour < 0.97 THEN 'dpd_90'
                    ELSE 'default'
                END
            ELSE
                CASE
                    WHEN lv.r_behaviour < 0.20 THEN 'good'
                    WHEN lv.r_behaviour < 0.38 THEN 'mild_late'
                    WHEN lv.r_behaviour < 0.55 THEN 'dpd_30'
                    WHEN lv.r_behaviour < 0.72 THEN 'dpd_60'
                    WHEN lv.r_behaviour < 0.86 THEN 'dpd_90'
                    ELSE 'default'
                END
        END AS raw_behaviour
    FROM loan_values AS lv
),
final_behaviour AS (
    SELECT
        ib.*,

        CASE
            WHEN ib.due_installments < 2
                 AND ib.raw_behaviour IN ('dpd_30', 'dpd_60', 'dpd_90', 'default')
                THEN 'mild_late'
            WHEN ib.due_installments < 3
                 AND ib.raw_behaviour IN ('dpd_60', 'dpd_90', 'default')
                THEN 'dpd_30'
            WHEN ib.due_installments < 4
                 AND ib.raw_behaviour IN ('dpd_90', 'default')
                THEN 'dpd_60'
            WHEN ib.due_installments < 6
                 AND ib.raw_behaviour = 'default'
                THEN 'dpd_90'
            ELSE ib.raw_behaviour
        END AS behaviour
    FROM initial_behaviour AS ib
),
status_calc AS (
    SELECT
        fb.*,

        (fb.start_date + make_interval(months => fb.term_months))::DATE
            AS maturity_date,

        CASE fb.behaviour
            WHEN 'dpd_30' THEN GREATEST(1, fb.due_installments)
            WHEN 'dpd_60' THEN GREATEST(1, fb.due_installments - 1)
            WHEN 'dpd_90' THEN GREATEST(1, fb.due_installments - 2)
            WHEN 'default' THEN GREATEST(1, fb.due_installments - 5)
            ELSE NULL
        END::SMALLINT AS delinquency_start_installment
    FROM final_behaviour AS fb
)
SELECT
    sc.row_no,
    sc.run_key,
    sc.as_of_date,

    sc.first_name,
    sc.last_name,
    NULL::VARCHAR(100) AS middle_name,
    sc.birth_date,
    sc.sex,
    sc.occupation,
    sc.city,
    'Russia'::VARCHAR(100) AS country,
    (
        'Synthetic address '
        || sc.run_key
        || '-'
        || LPAD(sc.row_no::TEXT, 4, '0')
    )::TEXT AS address,

    sc.monthly_income,
    (
        'Synthetic Employer '
        || (1 + floor(sc.r_occupation * 40)::INT)
    )::TEXT AS employer_name,

    sc.loan_type,
    sc.requested_amount,
    sc.term_months,
    sc.interest_rate,
    sc.down_payment,
    sc.asset_value,

    sc.score,
    sc.probability_of_default,

    sc.start_date,
    (sc.start_date - (5 + floor(sc.r_condition * 26)::INT))::DATE
        AS application_date,
    (sc.start_date - (1 + floor(sc.r_condition * 5)::INT))::DATE
        AS signing_date,
    sc.maturity_date,

    sc.due_installments,
    sc.behaviour,
    sc.delinquency_start_installment,

    CASE
        WHEN sc.behaviour = 'default' THEN 'defaulted'
        WHEN sc.behaviour = 'dpd_90' AND sc.r_status < 0.35
            THEN 'restructured'
        WHEN sc.maturity_date <= sc.as_of_date
             AND sc.behaviour IN ('good', 'mild_late')
            THEN 'closed'
        ELSE 'active'
    END::VARCHAR(30) AS contract_status,

    CASE
        WHEN sc.maturity_date <= sc.as_of_date
             AND sc.behaviour IN ('good', 'mild_late')
            THEN LEAST(
                sc.as_of_date,
                (
                    sc.maturity_date
                    + floor(sc.r_status * 21)::INT
                )::DATE
            )
        ELSE NULL::DATE
    END AS closed_date,

    CASE
        WHEN sc.score < 540 OR sc.r_condition < 0.18
            THEN 'approved_with_conditions'
        ELSE 'approved'
    END::VARCHAR(30) AS decision_type,

    CASE
        WHEN sc.r_verification < 0.60 THEN 'bank_statement'
        WHEN sc.r_verification < 0.85 THEN 'employer_confirmation'
        ELSE 'tax_data'
    END::VARCHAR(50) AS verification_method
FROM status_calc AS sc;

CREATE INDEX ON tmp_contract_seed(row_no);
CREATE INDEX ON tmp_contract_seed(address);

-- ============================================================
-- 2. Customers
-- ============================================================

CREATE TEMP TABLE tmp_customer_map (
    row_no INTEGER PRIMARY KEY,
    customer_id BIGINT NOT NULL
);

WITH inserted AS (
    INSERT INTO customers (
        first_name,
        last_name,
        middle_name,
        birth_date,
        sex,
        occupation,
        city,
        country,
        address,
        customer_status
    )
    SELECT
        first_name,
        last_name,
        middle_name,
        birth_date,
        sex,
        occupation,
        city,
        country,
        address,
        CASE
            WHEN contract_status IN ('active', 'restructured', 'defaulted')
                THEN 'active'
            ELSE 'inactive'
        END
    FROM tmp_contract_seed
    ORDER BY row_no
    RETURNING customer_id, address
)
INSERT INTO tmp_customer_map (row_no, customer_id)
SELECT
    s.row_no,
    i.customer_id
FROM inserted AS i
JOIN tmp_contract_seed AS s
    ON s.address = i.address;

-- ============================================================
-- 3. Income and verification
-- ============================================================

CREATE TEMP TABLE tmp_income_map (
    row_no INTEGER PRIMARY KEY,
    customer_income_id BIGINT NOT NULL
);

WITH inserted AS (
    INSERT INTO customer_income (
        customer_id,
        income_source,
        monthly_income,
        currency,
        employer_name,
        valid_from,
        valid_to
    )
    SELECT
        cm.customer_id,
        'salary',
        s.monthly_income,
        'RUB',
        s.employer_name,
        (s.application_date - INTERVAL '12 months')::DATE,
        NULL
    FROM tmp_contract_seed AS s
    JOIN tmp_customer_map AS cm USING (row_no)
    ORDER BY s.row_no
    RETURNING customer_income_id, customer_id
)
INSERT INTO tmp_income_map (row_no, customer_income_id)
SELECT
    cm.row_no,
    i.customer_income_id
FROM inserted AS i
JOIN tmp_customer_map AS cm
    ON cm.customer_id = i.customer_id;

INSERT INTO income_verifications (
    customer_income_id,
    verification_date,
    verification_method,
    verification_status,
    verified_amount,
    notes
)
SELECT
    im.customer_income_id,
    s.application_date::TIMESTAMPTZ + INTERVAL '1 day',
    s.verification_method,
    'verified',
    ROUND(
        s.monthly_income
        * (0.90 + ((s.score - 350)::NUMERIC / 5000)),
        2
    ),
    'Synthetic verified income'
FROM tmp_contract_seed AS s
JOIN tmp_income_map AS im USING (row_no);

-- ============================================================
-- 4. Applications
-- ============================================================

CREATE TEMP TABLE tmp_application_map (
    row_no INTEGER PRIMARY KEY,
    loan_application_id BIGINT NOT NULL
);

WITH inserted AS (
    INSERT INTO loan_applications (
        customer_id,
        application_date,
        loan_type,
        requested_amount,
        requested_term_months,
        expected_interest_rate,
        down_payment,
        asset_value,
        application_status
    )
    SELECT
        cm.customer_id,
        s.application_date::TIMESTAMPTZ,
        s.loan_type,
        s.requested_amount,
        s.term_months,
        s.interest_rate,
        s.down_payment,
        s.asset_value,
        'approved'
    FROM tmp_contract_seed AS s
    JOIN tmp_customer_map AS cm USING (row_no)
    ORDER BY s.row_no
    RETURNING loan_application_id, customer_id
)
INSERT INTO tmp_application_map (row_no, loan_application_id)
SELECT
    cm.row_no,
    i.loan_application_id
FROM inserted AS i
JOIN tmp_customer_map AS cm
    ON cm.customer_id = i.customer_id;

INSERT INTO application_scores (
    loan_application_id,
    model_name,
    model_version,
    score,
    probability_of_default,
    calculated_at
)
SELECT
    am.loan_application_id,
    'Synthetic Credit Score',
    '1.0',
    s.score,
    s.probability_of_default,
    s.application_date::TIMESTAMPTZ + INTERVAL '1 day'
FROM tmp_contract_seed AS s
JOIN tmp_application_map AS am USING (row_no);

INSERT INTO application_decisions (
    loan_application_id,
    decision_type,
    approved_amount,
    approved_term_months,
    approved_interest_rate,
    reason_code,
    decision_at
)
SELECT
    am.loan_application_id,
    s.decision_type,
    s.requested_amount,
    s.term_months,
    CASE
        WHEN s.decision_type = 'approved_with_conditions'
            THEN s.interest_rate + 1.5000
        ELSE s.interest_rate
    END,
    CASE
        WHEN s.decision_type = 'approved_with_conditions'
            THEN 'HIGHER_RISK_PRICING'
        ELSE 'STANDARD_APPROVAL'
    END,
    s.application_date::TIMESTAMPTZ + INTERVAL '2 days'
FROM tmp_contract_seed AS s
JOIN tmp_application_map AS am USING (row_no);

-- ============================================================
-- 5. Contracts
-- ============================================================

CREATE TEMP TABLE tmp_contract_map (
    row_no INTEGER PRIMARY KEY,
    loan_contract_id BIGINT NOT NULL
);

WITH inserted AS (
    INSERT INTO loan_contracts (
        loan_application_id,
        contract_number,
        signing_date,
        principal_amount,
        interest_rate,
        term_months,
        start_date,
        maturity_date,
        contract_status,
        closed_date
    )
    SELECT
        am.loan_application_id,
        (
            'SYN-'
            || s.run_key
            || '-'
            || LPAD(s.row_no::TEXT, 4, '0')
        ),
        s.signing_date,
        s.requested_amount,
        CASE
            WHEN s.decision_type = 'approved_with_conditions'
                THEN s.interest_rate + 1.5000
            ELSE s.interest_rate
        END,
        s.term_months,
        s.start_date,
        s.maturity_date,
        s.contract_status,
        s.closed_date
    FROM tmp_contract_seed AS s
    JOIN tmp_application_map AS am USING (row_no)
    ORDER BY s.row_no
    RETURNING loan_contract_id, loan_application_id
)
INSERT INTO tmp_contract_map (row_no, loan_contract_id)
SELECT
    am.row_no,
    i.loan_contract_id
FROM inserted AS i
JOIN tmp_application_map AS am
    ON am.loan_application_id = i.loan_application_id;

-- ============================================================
-- 6. Collateral for secured products
-- ============================================================

INSERT INTO loan_collateral (
    loan_contract_id,
    collateral_type,
    collateral_description,
    identification_number,
    market_value,
    valuation_date,
    collateral_status,
    pledged_at,
    released_at
)
SELECT
    cm.loan_contract_id,
    CASE
        WHEN s.loan_type = 'auto_loan' THEN 'vehicle'
        ELSE 'real_estate'
    END,
    CASE
        WHEN s.loan_type = 'auto_loan'
            THEN 'Synthetic vehicle collateral'
        ELSE 'Synthetic residential property collateral'
    END,
    CASE
        WHEN s.loan_type = 'auto_loan'
            THEN 'VIN-' || s.run_key || '-' || LPAD(s.row_no::TEXT, 4, '0')
        ELSE 'CAD-' || s.run_key || '-' || LPAD(s.row_no::TEXT, 4, '0')
    END,
    s.asset_value,
    s.signing_date,
    CASE
        WHEN s.contract_status = 'closed' THEN 'released'
        WHEN s.contract_status = 'defaulted' AND s.score < 470
            THEN 'foreclosed'
        ELSE 'pledged'
    END,
    s.signing_date,
    CASE
        WHEN s.contract_status = 'closed' THEN s.closed_date
        ELSE NULL
    END
FROM tmp_contract_seed AS s
JOIN tmp_contract_map AS cm USING (row_no)
WHERE s.loan_type IN ('auto_loan', 'mortgage');

-- ============================================================
-- 7. Disbursements
-- ============================================================

INSERT INTO loan_disbursements (
    loan_contract_id,
    disbursement_date,
    disbursement_amount,
    disbursement_method,
    transaction_reference
)
SELECT
    cm.loan_contract_id,
    s.start_date,
    s.requested_amount,
    CASE
        WHEN s.loan_type = 'mortgage' THEN 'seller_transfer'
        WHEN s.loan_type = 'auto_loan' THEN 'dealer_transfer'
        ELSE 'account_credit'
    END,
    (
        'TX-'
        || s.run_key
        || '-'
        || LPAD(s.row_no::TEXT, 4, '0')
    )
FROM tmp_contract_seed AS s
JOIN tmp_contract_map AS cm USING (row_no);

-- ============================================================
-- 8. Payment schedule
-- Uses a declining-balance schedule:
-- equal principal + interest on outstanding principal.
-- ============================================================

CREATE TEMP TABLE tmp_schedule_map (
    row_no INTEGER NOT NULL,
    payment_schedule_id BIGINT PRIMARY KEY,
    installment_number SMALLINT NOT NULL,
    due_date DATE NOT NULL,
    principal_due NUMERIC(15, 2) NOT NULL,
    interest_due NUMERIC(15, 2) NOT NULL,
    fee_due NUMERIC(15, 2) NOT NULL
);

WITH inserted AS (
    INSERT INTO payment_schedule (
        loan_contract_id,
        installment_number,
        due_date,
        principal_due,
        interest_due,
        fee_due
    )
    SELECT
        cm.loan_contract_id,
        gs.installment_number::SMALLINT,
        (
            s.start_date
            + make_interval(months => gs.installment_number)
        )::DATE AS due_date,

        CASE
            WHEN gs.installment_number = s.term_months THEN
                ROUND(
                    s.requested_amount
                    - ROUND(
                        s.requested_amount / s.term_months,
                        2
                    ) * (s.term_months - 1),
                    2
                )
            ELSE
                ROUND(
                    s.requested_amount / s.term_months,
                    2
                )
        END AS principal_due,

        ROUND(
            (
                s.requested_amount
                - ROUND(
                    s.requested_amount / s.term_months,
                    2
                ) * (gs.installment_number - 1)
            )
            * (
                CASE
                    WHEN s.decision_type = 'approved_with_conditions'
                        THEN s.interest_rate + 1.5000
                    ELSE s.interest_rate
                END
            )
            / 100
            / 12,
            2
        ) AS interest_due,

        0::NUMERIC AS fee_due
    FROM tmp_contract_seed AS s
    JOIN tmp_contract_map AS cm USING (row_no)
    CROSS JOIN LATERAL generate_series(
        1,
        s.term_months::INT
    ) AS gs(installment_number)
    ORDER BY s.row_no, gs.installment_number
    RETURNING
        payment_schedule_id,
        loan_contract_id,
        installment_number,
        due_date,
        principal_due,
        interest_due,
        fee_due
)
INSERT INTO tmp_schedule_map (
    row_no,
    payment_schedule_id,
    installment_number,
    due_date,
    principal_due,
    interest_due,
    fee_due
)
SELECT
    cm.row_no,
    i.payment_schedule_id,
    i.installment_number,
    i.due_date,
    i.principal_due,
    i.interest_due,
    i.fee_due
FROM inserted AS i
JOIN tmp_contract_map AS cm
    ON cm.loan_contract_id = i.loan_contract_id;

CREATE INDEX ON tmp_schedule_map(row_no, installment_number);
CREATE INDEX ON tmp_schedule_map(due_date);

-- ============================================================
-- 9. Actual payments
-- Severe delinquency profiles leave recent instalments unpaid.
-- ============================================================

WITH payment_candidates AS MATERIALIZED (
    SELECT
        sm.row_no,
        sm.payment_schedule_id,
        sm.installment_number,
        sm.due_date,
        sm.principal_due,
        sm.interest_due,
        sm.fee_due,

        s.as_of_date,
        s.behaviour,
        s.contract_status,
        s.closed_date,
        s.delinquency_start_installment,

        random() AS r_delay,
        random() AS r_method,

        CASE
            WHEN sm.due_date > s.as_of_date THEN FALSE
            WHEN s.behaviour IN ('dpd_30', 'dpd_60', 'dpd_90', 'default')
                 AND sm.installment_number >= s.delinquency_start_installment
                THEN FALSE
            ELSE TRUE
        END AS should_pay
    FROM tmp_schedule_map AS sm
    JOIN tmp_contract_seed AS s USING (row_no)
),
base_planned_payments AS (
    SELECT
        pc.*,

        CASE
            WHEN NOT pc.should_pay THEN NULL::DATE

            WHEN pc.behaviour = 'good' THEN
                (
                    pc.due_date
                    + CASE
                        WHEN pc.r_delay < 0.08 THEN -2
                        WHEN pc.r_delay < 0.18 THEN -1
                        WHEN pc.r_delay < 0.94 THEN 0
                        WHEN pc.r_delay < 0.98 THEN 1
                        ELSE 2
                    END
                )::DATE

            WHEN pc.behaviour = 'mild_late' THEN
                (
                    pc.due_date
                    + CASE
                        WHEN pc.r_delay < 0.55 THEN 0
                        WHEN pc.r_delay < 0.70 THEN 1
                        WHEN pc.r_delay < 0.82 THEN 2
                        WHEN pc.r_delay < 0.91 THEN 3
                        WHEN pc.r_delay < 0.97 THEN 5
                        ELSE 10
                    END
                )::DATE

            ELSE pc.due_date
        END AS base_payment_date
    FROM payment_candidates AS pc
),
planned_payments AS (
    SELECT
        bpp.*,
        CASE
            WHEN bpp.contract_status = 'closed'
                 AND bpp.base_payment_date IS NOT NULL
                THEN LEAST(bpp.base_payment_date, bpp.closed_date)
            ELSE bpp.base_payment_date
        END AS planned_payment_date
    FROM base_planned_payments AS bpp
)
INSERT INTO payments (
    payment_schedule_id,
    payment_date,
    principal_paid,
    interest_paid,
    fee_paid,
    payment_method,
    payment_status
)
SELECT
    pp.payment_schedule_id,
    pp.planned_payment_date,
    pp.principal_due,
    pp.interest_due,
    pp.fee_due,
    CASE
        WHEN pp.r_method < 0.55 THEN 'bank_transfer'
        WHEN pp.r_method < 0.82 THEN 'autopay'
        WHEN pp.r_method < 0.95 THEN 'card'
        ELSE 'cash'
    END,
    'posted'
FROM planned_payments AS pp
WHERE pp.should_pay
  AND pp.planned_payment_date <= pp.as_of_date;

-- ============================================================
-- 10. Delinquency events
-- One event for every late or currently unpaid scheduled payment.
-- ============================================================

WITH payment_summary AS (
    SELECT
        payment_schedule_id,
        MAX(payment_date) AS final_payment_date,
        SUM(principal_paid) AS principal_paid,
        SUM(interest_paid) AS interest_paid,
        SUM(fee_paid) AS fee_paid
    FROM payments
    GROUP BY payment_schedule_id
),
delinquency_source AS (
    SELECT
        sm.payment_schedule_id,
        sm.due_date,
        sm.principal_due,
        sm.interest_due,
        sm.fee_due,
        s.as_of_date,

        ps.final_payment_date,
        COALESCE(ps.principal_paid, 0) AS principal_paid,
        COALESCE(ps.interest_paid, 0) AS interest_paid,
        COALESCE(ps.fee_paid, 0) AS fee_paid,

        CASE
            WHEN ps.final_payment_date IS NULL
                THEN s.as_of_date
            ELSE ps.final_payment_date
        END AS dpd_end_date
    FROM tmp_schedule_map AS sm
    JOIN tmp_contract_seed AS s USING (row_no)
    LEFT JOIN payment_summary AS ps
        ON ps.payment_schedule_id = sm.payment_schedule_id
    WHERE sm.due_date < s.as_of_date
)
INSERT INTO delinquency_events (
    payment_schedule_id,
    delinquency_start_date,
    delinquency_end_date,
    overdue_principal,
    overdue_interest,
    overdue_fee,
    max_dpd,
    penalty_rate,
    delinquency_status
)
SELECT
    ds.payment_schedule_id,
    ds.due_date + 1,

    CASE
        WHEN ds.final_payment_date IS NULL THEN NULL
        ELSE ds.final_payment_date
    END,

    ds.principal_due,
    ds.interest_due,
    ds.fee_due,

    (ds.dpd_end_date - ds.due_date)::INT,
    20.0000,

    CASE
        WHEN ds.final_payment_date IS NULL THEN 'open'
        ELSE 'closed'
    END
FROM delinquency_source AS ds
WHERE ds.dpd_end_date > ds.due_date;

-- Update statistics for analytical queries.
ANALYZE customers;
ANALYZE customer_income;
ANALYZE income_verifications;
ANALYZE loan_applications;
ANALYZE application_scores;
ANALYZE application_decisions;
ANALYZE loan_contracts;
ANALYZE loan_collateral;
ANALYZE loan_disbursements;
ANALYZE payment_schedule;
ANALYZE payments;
ANALYZE delinquency_events;

COMMIT;

-- ============================================================
-- Validation report for the generated batch
-- ============================================================

SELECT
    gr.run_key,
    COUNT(DISTINCT cm.loan_contract_id) AS generated_contracts,
    COUNT(DISTINCT sm.payment_schedule_id) AS generated_schedule_rows,
    COUNT(DISTINCT p.payment_id) AS generated_payments,
    COUNT(DISTINCT de.delinquency_event_id) AS generated_delinquency_events
FROM tmp_generation_run AS gr
JOIN tmp_contract_map AS cm ON TRUE
LEFT JOIN tmp_schedule_map AS sm
    ON sm.row_no = cm.row_no
LEFT JOIN payments AS p
    ON p.payment_schedule_id = sm.payment_schedule_id
LEFT JOIN delinquency_events AS de
    ON de.payment_schedule_id = sm.payment_schedule_id
GROUP BY gr.run_key;

SELECT
    s.contract_status,
    COUNT(*) AS contracts
FROM tmp_contract_seed AS s
GROUP BY s.contract_status
ORDER BY contracts DESC;

WITH contract_current_dpd AS (
    SELECT
        cm.loan_contract_id,
        MAX(de.max_dpd) AS current_dpd
    FROM tmp_contract_map AS cm
    LEFT JOIN tmp_schedule_map AS sm
        ON sm.row_no = cm.row_no
    LEFT JOIN delinquency_events AS de
        ON de.payment_schedule_id = sm.payment_schedule_id
       AND de.delinquency_status = 'open'
    GROUP BY cm.loan_contract_id
),
bucketed AS (
    SELECT
        loan_contract_id,
        CASE
            WHEN current_dpd IS NULL THEN 'Current'
            WHEN current_dpd BETWEEN 1 AND 30 THEN '1-30'
            WHEN current_dpd BETWEEN 31 AND 60 THEN '31-60'
            WHEN current_dpd BETWEEN 61 AND 90 THEN '61-90'
            ELSE '90+'
        END AS dpd_bucket,
        CASE
            WHEN current_dpd IS NULL THEN 1
            WHEN current_dpd BETWEEN 1 AND 30 THEN 2
            WHEN current_dpd BETWEEN 31 AND 60 THEN 3
            WHEN current_dpd BETWEEN 61 AND 90 THEN 4
            ELSE 5
        END AS bucket_order
    FROM contract_current_dpd
)
SELECT
    dpd_bucket,
    COUNT(*) AS contracts
FROM bucketed
GROUP BY dpd_bucket, bucket_order
ORDER BY bucket_order;
