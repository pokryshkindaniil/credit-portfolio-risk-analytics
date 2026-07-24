# Credit Portfolio Risk Analytics

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Analytics-336791)
![Status](https://img.shields.io/badge/status-active_development-yellow)
![Data](https://img.shields.io/badge/data-synthetic-lightgrey)

A PostgreSQL portfolio project for analysing credit portfolio risk, delinquency and payment behaviour using synthetic lending data.

The project follows a realistic analytical workflow: designing a relational data model, generating a synthetic loan portfolio, building a reusable contract-level data mart and creating SQL reports for portfolio monitoring and risk segmentation.

## Project scope

The project includes:

* a relational data model for customers, income, loan applications, scoring, credit decisions, contracts, collateral, payment schedules, payments and delinquency events;
* a reproducible generator for 1,000 synthetic customers and 1,000 loan contracts;
* a reusable portfolio snapshot with one row per loan contract;
* analytical SQL reports for portfolio monitoring, risk segmentation and payment behaviour.

## Analysis

The current analytical reports cover:

* portfolio-level credit risk KPIs;
* distribution of contracts and outstanding exposure across DPD buckets;
* risk segmentation by original loan size;
* risk segmentation by months on book;
* early delinquency timing;
* monthly payment performance.

Key outputs include:

* outstanding and overdue principal;
* current and maximum historical DPD;
* delinquency rate;
* DPD 30+ and DPD 90+ rates;
* Portfolio at Risk metrics: PAR 30 and PAR 90;
* on-time payment rate;
* collection rate;
* average payment delay.

## Portfolio snapshot

`portfolio_snapshot` is the main analytical view used throughout the project.

Its grain is **one row per loan contract**. The view combines contract, payment and delinquency data and calculates:

* paid principal;
* outstanding principal;
* overdue principal;
* current DPD;
* maximum historical DPD;
* current DPD bucket.

Analytical reports use this view instead of repeating the same contract-level calculations.

## Project structure

```text
sql/
├── 01_schema.sql
├── 02_generate_synthetic_portfolio_1000.sql
├── marts/
│   └── portfolio_snapshot.sql
└── analytics/
    ├── portfolio_monitoring/
    ├── risk_segmentation/
    └── payment_behaviour/
```

## Running locally

The project requires PostgreSQL.

Create and populate the database:

```bash
createdb credit_portfolio_risk

psql -d credit_portfolio_risk -v ON_ERROR_STOP=1 \
  -f sql/01_schema.sql \
  -f sql/02_generate_synthetic_portfolio_1000.sql \
  -f sql/marts/portfolio_snapshot.sql
```

Run an analytical report:

```bash
psql -d credit_portfolio_risk \
  -c "SET search_path TO credit_portfolio, public;" \
  -f sql/analytics/portfolio_monitoring/portfolio_kpis.sql
```

The generator does not delete existing records. Each execution adds a new synthetic portfolio batch.
