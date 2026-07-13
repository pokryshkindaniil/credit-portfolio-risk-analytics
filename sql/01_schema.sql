BEGIN;

CREATE SCHEMA IF NOT EXISTS credit_portfolio;

SET search_path TO credit_portfolio, public;


-- =========================================================
-- 1. CUSTOMERS
-- Одна строка = один клиент
-- =========================================================

CREATE TABLE customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),

    birth_date DATE NOT NULL,
    sex VARCHAR(20) NOT NULL,
    occupation TEXT,

    city VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,

    customer_status VARCHAR(20) NOT NULL DEFAULT 'applicant',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_customers_status
        CHECK (
            customer_status IN (
                'applicant',
                'active',
                'inactive',
                'blocked'
            )
        ),

    CONSTRAINT chk_customers_sex
        CHECK (
            sex IN (
                'male',
                'female',
                'other',
                'not_specified'
            )
        )
);


-- =========================================================
-- 2. CUSTOMER_INCOME
-- Одна строка = один источник дохода клиента за определённый период
-- =========================================================

CREATE TABLE customer_income (
    customer_income_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_id BIGINT NOT NULL,

    income_source VARCHAR(50) NOT NULL,
    monthly_income NUMERIC(15, 2) NOT NULL,

    currency CHAR(3) NOT NULL DEFAULT 'RUB',
    employer_name TEXT,

    valid_from DATE NOT NULL,
    valid_to DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_customer_income_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),

    CONSTRAINT chk_customer_income_amount
        CHECK (monthly_income > 0),

    CONSTRAINT chk_customer_income_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_customer_income_period
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        )
);


-- =========================================================
-- 3. INCOME_VERIFICATIONS
-- Одна строка = одна проверка конкретной записи о доходе
-- =========================================================

CREATE TABLE income_verifications (
    income_verification_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_income_id BIGINT NOT NULL,

    verification_date TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    verification_method VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL,

    verified_amount NUMERIC(15, 2),
    notes TEXT,

    CONSTRAINT fk_income_verification_income
        FOREIGN KEY (customer_income_id)
        REFERENCES customer_income(customer_income_id),

    CONSTRAINT chk_income_verification_status
        CHECK (
            verification_status IN (
                'pending',
                'verified',
                'rejected'
            )
        ),

    CONSTRAINT chk_income_verification_amount
        CHECK (
            verified_amount IS NULL
            OR verified_amount >= 0
        )
);


-- =========================================================
-- 4. LOAN_APPLICATIONS
-- Одна строка = одна кредитная заявка
-- =========================================================

CREATE TABLE loan_applications (
    loan_application_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_id BIGINT NOT NULL,

    application_date TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    loan_type VARCHAR(30) NOT NULL,

    requested_amount NUMERIC(15, 2) NOT NULL,
    requested_term_months SMALLINT NOT NULL,
    expected_interest_rate NUMERIC(7, 4),

    down_payment NUMERIC(15, 2) NOT NULL DEFAULT 0,
    asset_value NUMERIC(15, 2),

    application_status VARCHAR(30)
        NOT NULL DEFAULT 'submitted',

    CONSTRAINT fk_loan_application_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),

    CONSTRAINT chk_loan_application_amount
        CHECK (requested_amount > 0),

    CONSTRAINT chk_loan_application_term
        CHECK (requested_term_months > 0),

    CONSTRAINT chk_loan_application_rate
        CHECK (
            expected_interest_rate IS NULL
            OR expected_interest_rate >= 0
        ),

    CONSTRAINT chk_loan_application_down_payment
        CHECK (down_payment >= 0),

    CONSTRAINT chk_loan_application_asset_value
        CHECK (
            asset_value IS NULL
            OR asset_value > 0
        ),

    CONSTRAINT chk_loan_application_status
        CHECK (
            application_status IN (
                'submitted',
                'under_review',
                'approved',
                'rejected',
                'cancelled'
            )
        )
);


-- =========================================================
-- 5. APPLICATION_SCORES
-- Одна строка = один результат скоринга конкретной заявки
-- =========================================================

CREATE TABLE application_scores (
    application_score_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    loan_application_id BIGINT NOT NULL,

    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,

    score SMALLINT NOT NULL,
    probability_of_default NUMERIC(8, 6),

    calculated_at TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_application_score_application
        FOREIGN KEY (loan_application_id)
        REFERENCES loan_applications(loan_application_id),

    CONSTRAINT chk_application_score_value
        CHECK (score BETWEEN 0 AND 1000),

    CONSTRAINT chk_application_score_pd
        CHECK (
            probability_of_default IS NULL
            OR probability_of_default BETWEEN 0 AND 1
        )
);


-- =========================================================
-- 6. APPLICATION_DECISIONS
-- Одна строка = одно решение банка по заявке
-- =========================================================

CREATE TABLE application_decisions (
    application_decision_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    loan_application_id BIGINT NOT NULL,

    decision_type VARCHAR(30) NOT NULL,

    approved_amount NUMERIC(15, 2),
    approved_term_months SMALLINT,
    approved_interest_rate NUMERIC(7, 4),

    reason_code VARCHAR(100),

    decision_at TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_application_decision_application
        FOREIGN KEY (loan_application_id)
        REFERENCES loan_applications(loan_application_id),

    CONSTRAINT chk_application_decision_type
        CHECK (
            decision_type IN (
                'approved',
                'approved_with_conditions',
                'rejected',
                'cancelled'
            )
        ),

    CONSTRAINT chk_application_decision_amount
        CHECK (
            approved_amount IS NULL
            OR approved_amount > 0
        ),

    CONSTRAINT chk_application_decision_term
        CHECK (
            approved_term_months IS NULL
            OR approved_term_months > 0
        ),

    CONSTRAINT chk_application_decision_rate
        CHECK (
            approved_interest_rate IS NULL
            OR approved_interest_rate >= 0
        ),

    CONSTRAINT chk_approved_decision_fields
        CHECK (
            decision_type NOT IN (
                'approved',
                'approved_with_conditions'
            )
            OR (
                approved_amount IS NOT NULL
                AND approved_term_months IS NOT NULL
                AND approved_interest_rate IS NOT NULL
            )
        )
);


-- =========================================================
-- Последовательность для бизнес-номеров договоров
-- =========================================================

CREATE SEQUENCE contract_number_seq
    START WITH 1
    INCREMENT BY 1;


-- =========================================================
-- 7. LOAN_CONTRACTS
-- Одна строка = один кредитный договор
-- =========================================================

CREATE TABLE loan_contracts (
    loan_contract_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    loan_application_id BIGINT NOT NULL UNIQUE,

    contract_number VARCHAR(50) NOT NULL UNIQUE
        DEFAULT (
            'AUTO-'
            || TO_CHAR(CURRENT_DATE, 'YYYY')
            || '-'
            || LPAD(
                NEXTVAL(
                    'credit_portfolio.contract_number_seq'
                )::TEXT,
                6,
                '0'
            )
        ),

    signing_date DATE NOT NULL,

    principal_amount NUMERIC(15, 2) NOT NULL,
    interest_rate NUMERIC(7, 4) NOT NULL,
    term_months SMALLINT NOT NULL,

    start_date DATE NOT NULL,
    maturity_date DATE NOT NULL,

    contract_status VARCHAR(30)
        NOT NULL DEFAULT 'active',

    closed_date DATE,

    CONSTRAINT fk_loan_contract_application
        FOREIGN KEY (loan_application_id)
        REFERENCES loan_applications(loan_application_id),

    CONSTRAINT chk_loan_contract_principal
        CHECK (principal_amount > 0),

    CONSTRAINT chk_loan_contract_rate
        CHECK (interest_rate >= 0),

    CONSTRAINT chk_loan_contract_term
        CHECK (term_months > 0),

    CONSTRAINT chk_loan_contract_dates
        CHECK (maturity_date >= start_date),

    CONSTRAINT chk_loan_contract_closed_date
        CHECK (
            closed_date IS NULL
            OR closed_date >= start_date
        ),

    CONSTRAINT chk_loan_contract_status
        CHECK (
            contract_status IN (
                'active',
                'closed',
                'defaulted',
                'restructured',
                'cancelled'
            )
        ),

    CONSTRAINT chk_closed_contract_date
        CHECK (
            contract_status <> 'closed'
            OR closed_date IS NOT NULL
        )
);


-- =========================================================
-- 8. LOAN_COLLATERAL
-- Одна строка = один объект залога
-- =========================================================

CREATE TABLE loan_collateral (
    loan_collateral_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    loan_contract_id BIGINT NOT NULL,

    collateral_type VARCHAR(50) NOT NULL,
    collateral_description TEXT NOT NULL,
    identification_number VARCHAR(100),

    market_value NUMERIC(15, 2) NOT NULL,
    valuation_date DATE NOT NULL,

    collateral_status VARCHAR(20)
        NOT NULL DEFAULT 'pledged',

    pledged_at DATE NOT NULL,
    released_at DATE,

    CONSTRAINT fk_loan_collateral_contract
        FOREIGN KEY (loan_contract_id)
        REFERENCES loan_contracts(loan_contract_id),

    CONSTRAINT chk_loan_collateral_value
        CHECK (market_value > 0),

    CONSTRAINT chk_loan_collateral_dates
        CHECK (
            released_at IS NULL
            OR released_at >= pledged_at
        ),

    CONSTRAINT chk_loan_collateral_status
        CHECK (
            collateral_status IN (
                'pledged',
                'released',
                'foreclosed'
            )
        ),

    CONSTRAINT chk_released_collateral_date
        CHECK (
            collateral_status <> 'released'
            OR released_at IS NOT NULL
        )
);


-- =========================================================
-- 9. LOAN_DISBURSEMENTS
-- Одна строка = один факт выдачи денежных средств
-- =========================================================

CREATE TABLE loan_disbursements (
    loan_disbursement_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    loan_contract_id BIGINT NOT NULL,

    disbursement_date DATE NOT NULL,
    disbursement_amount NUMERIC(15, 2) NOT NULL,

    disbursement_method VARCHAR(50),
    transaction_reference VARCHAR(100) UNIQUE,

    CONSTRAINT fk_loan_disbursement_contract
        FOREIGN KEY (loan_contract_id)
        REFERENCES loan_contracts(loan_contract_id),

    CONSTRAINT chk_loan_disbursement_amount
        CHECK (disbursement_amount > 0)
);


-- =========================================================
-- 10. PAYMENT_SCHEDULE
-- Одна строка = один плановый платёж
-- =========================================================

CREATE TABLE payment_schedule (
    payment_schedule_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    loan_contract_id BIGINT NOT NULL,

    installment_number SMALLINT NOT NULL,
    due_date DATE NOT NULL,

    principal_due NUMERIC(15, 2) NOT NULL,
    interest_due NUMERIC(15, 2) NOT NULL,
    fee_due NUMERIC(15, 2) NOT NULL DEFAULT 0,

    total_due NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            principal_due
            + interest_due
            + fee_due
        ) STORED,

    CONSTRAINT fk_payment_schedule_contract
        FOREIGN KEY (loan_contract_id)
        REFERENCES loan_contracts(loan_contract_id),

    CONSTRAINT uq_payment_schedule_installment
        UNIQUE (
            loan_contract_id,
            installment_number
        ),

    CONSTRAINT chk_payment_schedule_installment
        CHECK (installment_number > 0),

    CONSTRAINT chk_payment_schedule_principal
        CHECK (principal_due >= 0),

    CONSTRAINT chk_payment_schedule_interest
        CHECK (interest_due >= 0),

    CONSTRAINT chk_payment_schedule_fee
        CHECK (fee_due >= 0),

    CONSTRAINT chk_payment_schedule_total
        CHECK (
            principal_due
            + interest_due
            + fee_due > 0
        )
);


-- =========================================================
-- 11. PAYMENTS
-- Одна строка = один фактически полученный платёж
-- =========================================================

CREATE TABLE payments (
    payment_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    payment_schedule_id BIGINT NOT NULL,

    payment_date DATE NOT NULL,

    principal_paid NUMERIC(15, 2) NOT NULL DEFAULT 0,
    interest_paid NUMERIC(15, 2) NOT NULL DEFAULT 0,
    fee_paid NUMERIC(15, 2) NOT NULL DEFAULT 0,

    payment_amount NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            principal_paid
            + interest_paid
            + fee_paid
        ) STORED,

    payment_method VARCHAR(50),

    payment_status VARCHAR(20)
        NOT NULL DEFAULT 'posted',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payment_schedule
        FOREIGN KEY (payment_schedule_id)
        REFERENCES payment_schedule(payment_schedule_id),

    CONSTRAINT chk_payment_principal
        CHECK (principal_paid >= 0),

    CONSTRAINT chk_payment_interest
        CHECK (interest_paid >= 0),

    CONSTRAINT chk_payment_fee
        CHECK (fee_paid >= 0),

    CONSTRAINT chk_payment_amount
        CHECK (
            principal_paid
            + interest_paid
            + fee_paid > 0
        ),

    CONSTRAINT chk_payment_status
        CHECK (
            payment_status IN (
                'pending',
                'posted',
                'reversed'
            )
        )
);


-- =========================================================
-- 12. DELINQUENCY_EVENTS
-- Одна строка = один эпизод просрочки по конкретному плановому платежу
-- =========================================================

CREATE TABLE delinquency_events (
    delinquency_event_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    payment_schedule_id BIGINT NOT NULL UNIQUE,

    delinquency_start_date DATE NOT NULL,
    delinquency_end_date DATE,

    overdue_principal NUMERIC(15, 2) NOT NULL DEFAULT 0,
    overdue_interest NUMERIC(15, 2) NOT NULL DEFAULT 0,
    overdue_fee NUMERIC(15, 2) NOT NULL DEFAULT 0,

    max_dpd INTEGER NOT NULL,

    penalty_rate NUMERIC(7, 4)
        NOT NULL DEFAULT 20.0000,

    penalty_amount NUMERIC(15, 2)
        GENERATED ALWAYS AS (
            ROUND(
                overdue_principal
                * penalty_rate / 100
                / 365
                * max_dpd,
                2
            )
        ) STORED,

    delinquency_status VARCHAR(20) NOT NULL,

    CONSTRAINT fk_delinquency_payment_schedule
        FOREIGN KEY (payment_schedule_id)
        REFERENCES payment_schedule(payment_schedule_id),

    CONSTRAINT chk_delinquency_dates
        CHECK (
            delinquency_end_date IS NULL
            OR delinquency_end_date
                >= delinquency_start_date
        ),

    CONSTRAINT chk_delinquency_principal
        CHECK (overdue_principal >= 0),

    CONSTRAINT chk_delinquency_interest
        CHECK (overdue_interest >= 0),

    CONSTRAINT chk_delinquency_fee
        CHECK (overdue_fee >= 0),

    CONSTRAINT chk_delinquency_dpd
        CHECK (max_dpd > 0),

    CONSTRAINT chk_delinquency_penalty_rate
        CHECK (penalty_rate >= 0),

    CONSTRAINT chk_delinquency_status
        CHECK (
            delinquency_status IN (
                'open',
                'closed'
            )
        ),

    CONSTRAINT chk_delinquency_status_dates
        CHECK (
            (
                delinquency_status = 'open'
                AND delinquency_end_date IS NULL
            )
            OR
            (
                delinquency_status = 'closed'
                AND delinquency_end_date IS NOT NULL
            )
        )
);


CREATE INDEX idx_customer_income_customer
    ON customer_income(customer_id);

CREATE INDEX idx_income_verifications_income
    ON income_verifications(customer_income_id);

CREATE INDEX idx_loan_applications_customer
    ON loan_applications(customer_id);

CREATE INDEX idx_loan_applications_status
    ON loan_applications(application_status);

CREATE INDEX idx_loan_applications_date
    ON loan_applications(application_date);

CREATE INDEX idx_application_scores_application
    ON application_scores(loan_application_id);

CREATE INDEX idx_application_decisions_application
    ON application_decisions(loan_application_id);

CREATE INDEX idx_loan_contracts_status
    ON loan_contracts(contract_status);

CREATE INDEX idx_loan_contracts_start_date
    ON loan_contracts(start_date);

CREATE INDEX idx_loan_collateral_contract
    ON loan_collateral(loan_contract_id);

CREATE INDEX idx_loan_disbursements_contract
    ON loan_disbursements(loan_contract_id);

CREATE INDEX idx_payment_schedule_contract
    ON payment_schedule(loan_contract_id);

CREATE INDEX idx_payment_schedule_due_date
    ON payment_schedule(due_date);

CREATE INDEX idx_payments_schedule
    ON payments(payment_schedule_id);

CREATE INDEX idx_payments_date
    ON payments(payment_date);

CREATE INDEX idx_delinquency_status
    ON delinquency_events(delinquency_status);

CREATE INDEX idx_delinquency_start_date
    ON delinquency_events(delinquency_start_date);


COMMIT;
