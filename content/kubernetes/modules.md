---
title: 'Modules'
weight: 1500
draft: false
---

# Module Documentation

## correlation.py

This script calculates financial correlations and stores the results in a PostgreSQL database.

Modules:
: - psycopg2: For connecting to and interacting with a PostgreSQL database.
  - pandas: For handling and processing tabular data.
  - dotenv: For loading environment variables from a .env file.
  - os: For accessing environment variables.
  - numpy: For numerical operations.

Environment Variables:
: - POSTGRES_USER: PostgreSQL username (default: ‘myuser’).
  - POSTGRES_PASSWORD: PostgreSQL password (default: ‘mypassword’).
  - POSTGRES_DB: PostgreSQL database name (default: ‘mydatabase’).
  - POSTGRES_HOST: PostgreSQL host (default: ‘localhost’).
  - POSTGRES_PORT: PostgreSQL port (default: ‘5432’).

Functions:
: - fetch_data(query): Fetches data from the PostgreSQL database based on the provided SQL query.
  - calculate_codes(data): Calculates codes based on percentage changes in the data.
    : - Code 1: Positive change.
      - Code 0: Small negative or no change (-7% to 0%).
      - Code -1: Large negative change (less than -7%).
  - calculate_correlation(revenue, market_cap, roic): Calculates the correlation between revenue, market cap, and ROIC codes.
    : - Correlation is incremented when all three codes are either 1 or -1.
  - calculate_consecutive_ones(data): Calculates the number of periods with more than two consecutive code 1 values.
  - main(): Main function that fetches data, processes it, and stores the results in a PostgreSQL table.

Database Schema:
: - Table: company_correlation
    : - symbol (TEXT): Primary key representing the company symbol.
      - revenue (INTEGER[]): Array of calculated revenue codes.
      - market_cap (INTEGER[]): Array of calculated market cap codes.
      - roic (INTEGER[]): Array of calculated ROIC codes.
      - correlation (FLOAT): Correlation value between revenue, market cap, and ROIC.
      - consecutive_ones (INT): Number of periods with more than two consecutive code 1 values.

Usage:
: - Ensure the required environment variables are set in a .env file.
  - Run the script to calculate financial correlations and store the results in the database.

### advisor.correlation.calculate_codes(data)

### advisor.correlation.calculate_consecutive_ones(data)

### advisor.correlation.calculate_correlation_all(revenue, market_cap, roic)

### advisor.correlation.calculate_correlation_rev_cap(revenue, market_cap)

### advisor.correlation.calculate_correlation_rev_roic(revenue, roic)

### advisor.correlation.calculate_correlation_roic_cap(roic, market_cap)

### advisor.correlation.fetch_data(query)

### advisor.correlation.main()

## fastapp.py

## report.py

## update_postgres.py

<!-- app.py -->
<!-- ------ -->
<!-- .. automodule:: app -->
<!-- :members: -->
<!-- :undoc-members: -->
<!-- :show-inheritance: -->

## show-json.py
