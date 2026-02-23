---
title: 'Modules'
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

This module implements a FastAPI application for visualizing and analyzing financial data 
stored in a PostgreSQL database. It provides endpoints for rendering HTML pages, fetching 
and filtering data, and generating visualizations using Plotly.
Modules and Libraries:
- fastapi: Framework for building APIs.
- psycopg2: PostgreSQL database adapter for Python.
- pandas: Data manipulation and analysis library.
- dotenv: For loading environment variables from a .env file.
- numpy: Library for numerical computations.
- plotly: Library for creating interactive visualizations.
- uvicorn: ASGI server for running FastAPI applications.
Environment Variables:
- POSTGRES_USER: PostgreSQL username.
- POSTGRES_PASSWORD: PostgreSQL password.
- POSTGRES_DB: PostgreSQL database name.
- POSTGRES_HOST: PostgreSQL host address.
- POSTGRES_PORT: PostgreSQL port.
Functions:
- fetch_data(query): Executes a SQL query on the PostgreSQL database and returns the result as a pandas DataFrame.
- categorize_company(data): Categorizes companies based on the average change in their financial data.
- get_item_color(data): Determines the color for each value in a dataset based on percentage change.
- generate_plot(data, title): Generates a Plotly bar chart for the given data and returns it as an HTML string.
Endpoints:
- GET “/”: Renders the main HTML page using Jinja2 templates.
- GET “/data”: Fetches and filters financial data based on market capitalization and ROIC thresholds.
- GET “/plot/{symbol}”: Generates a Plotly visualization for a specific company’s financial metric.
Usage:
Run the application using the command uvicorn fastapp:app –host 0.0.0.0 –port 8001.

### ana_report.fastapp.categorize_company(data)

### ana_report.fastapp.fetch_data(query: str, params: Tuple | None = None) → DataFrame

### ana_report.fastapp.generate_plot(data, title)

### ana_report.fastapp.get_data()

### ana_report.fastapp.get_item_color(data)

### ana_report.fastapp.get_plot(symbol: str, metric: str)

### *async* ana_report.fastapp.get_symbol_data(symbol: str)

### *async* ana_report.fastapp.get_symbol_market_cap_normalized(symbol: str)

### *async* ana_report.fastapp.get_symbol_revenue(symbol: str)

### *async* ana_report.fastapp.get_symbol_revenue_normalized(symbol: str)

### *async* ana_report.fastapp.get_symbol_roic(symbol: str)

### *async* ana_report.fastapp.get_symbol_roic_normalized(symbol: str)

### ana_report.fastapp.normalize_array(data)

Normalize a list of numbers to the range [0, 1] using min-max normalization.

### ana_report.fastapp.read_root(request: Request)

## report.py

This script generates a PDF report with financial metrics for companies stored in a PostgreSQL database.
It includes functionalities for fetching data, categorizing companies, generating plots, and creating a PDF report.
Modules and Libraries:
- psycopg2: For connecting to and querying the PostgreSQL database.
- pandas: For data manipulation and analysis.
- dotenv: For loading environment variables from a .env file.
- os: For accessing environment variables.

### ana_report.report.categorize_company(data)

### ana_report.report.fetch_data(query)

### ana_report.report.generate_pdf(df, output_file)

### ana_report.report.generate_plot(data, title, filename)

### ana_report.report.generate_report(output_file='financial_report.pdf')

### ana_report.report.get_item_color(data)

### ana_report.report.main()

<!-- update_postgress -->
<!-- ------------------ -->
<!-- .. automodule:: nosql.update_postgres -->
<!-- :members: -->
<!-- :undoc-members: -->
<!-- :show-inheritance: -->
<!-- app.py -->
<!-- ------ -->
<!-- .. automodule:: app -->
<!-- :members: -->
<!-- :undoc-members: -->
<!-- :show-inheritance: -->
