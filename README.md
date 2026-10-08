# Revenue Reconciliation & Exception Analysis

## 1. Project Overview

This project analyzes e-commerce order, item, payment, customer, product, and seller data to build an order-level revenue reconciliation dataset.

The main business problem is:

> **Does the amount paid for an order match the expected order amount based on product price and freight?**

The project follows an ETL-style workflow:

```text
Raw CSV Data
     ↓
01_data_exploration.ipynb
     ↓
02_data_cleaning.ipynb
     ↓
03_data_transformation.ipynb
     ↓
Cleaned / Transformed Data
     ↓
MySQL
     ↓
SQL Analysis
     ↓
Business Insights
```

---

## 2. Project Objectives

The main objectives of this project are:

* Understand the structure and quality of the raw data.
* Identify missing values, duplicates, and data-quality issues.
* Clean the data without unnecessarily removing valid business information.
* Transform multiple transaction-level tables into an order-level dataset.
* Calculate the expected amount for each order.
* Compare the expected amount with the actual amount paid.
* Identify matched, overpaid, underpaid, and non-analyzable orders.
* Load the cleaned and transformed data into MySQL.
* Perform business-focused SQL analysis.
* Generate useful business insights from the analysis.

---

## 3. Dataset / Source Tables

The project works with the following main tables:

| Table                  | Purpose                                                         |
| ---------------------- | --------------------------------------------------------------- |
| `orders`               | Order status, customer, and order dates                         |
| `order_items`          | Products purchased, seller, price, and freight                  |
| `payments`             | Payment type, payment value, installments, and payment sequence |
| `customers`            | Customer information                                            |
| `products`             | Product and category information                                |
| `sellers`              | Seller information                                              |
| `category_translation` | Product category translation                                    |

The project uses raw CSV files as the source data.

---

# 4. Notebook 1 — Data Exploration

### File:

```text
notebook/01_data_exploration.ipynb
```

### Purpose

The first notebook is used to understand the raw data **before making any changes**.

The main goal is to identify data-quality problems and understand the structure and relationship between the tables.

---

## Problem 1: Understanding the Transaction Tables

The project first examines:

* `orders`
* `order_items`
* `payments`

### What was done?

The following checks were performed:

* Number of rows and columns.
* First few records.
* Column names.
* Data types.
* Basic structure of each table.

### Why?

Because each table has a different level of detail.

For example:

```text
orders
→ generally one row per order

order_items
→ multiple rows can belong to one order

payments
→ multiple payment records can belong to one order
```

Understanding this is important before joining the tables.

---

## Problem 2: Missing Values

The exploration notebook checks missing values in the core tables.

A specific check was made for:

```text
order_delivered_customer_date
```

### Finding

Some orders do not have a customer delivery date.

### Why was this not automatically deleted?

A missing delivery date does not necessarily mean the record is invalid. The order may not have been delivered yet or the information may not be available.

Therefore, valid business records are preserved.

---

## Problem 3: Duplicate Records

The notebook checks:

* Duplicate rows.
* Duplicate `order_id` values in the `orders` table.

### Why?

`order_id` is an important identifier for an order.

Duplicate order IDs can cause:

* Incorrect joins.
* Duplicate records.
* Incorrect revenue calculations.

Therefore, duplicate checks are performed before transformation.

---

## Problem 4: Order Coverage Across Tables

The project compares order IDs between:

* `orders`
* `order_items`
* `payments`

The notebook checks:

* Orders with no items.
* Orders with no payments.
* Item records whose order does not exist in `orders`.
* Payment records whose order does not exist in `orders`.

### Why?

Before joining different tables, we need to understand whether records exist on both sides.

This helps prevent unexpected data loss and incorrect joins.

---

## Problem 5: Multiple Rows Per Order

The project checks how many item and payment rows belong to each order.

An order can contain:

* Multiple products.
* Multiple sellers.
* Multiple payment records.

### Why is this important?

Because directly joining `order_items` and `payments` using `order_id` can create a **fan-out problem**.

For example:

```text
1 order
3 item rows
2 payment rows
```

A direct join can create:

```text
3 × 2 = 6 rows
```

This can repeat item and payment values and produce incorrect totals.

### Solution

Aggregate each table to the order level first:

```text
order_items
     ↓
one row per order

payments
     ↓
one row per order

then join
```

This is one of the most important design decisions in the project.

---

## Problem 6: Financial Amount Validation

The notebook checks:

* Payment types.
* Zero-value payments.
* Negative payments.
* Negative item prices.
* Negative freight.
* Zero-price items.
* Payment value distribution.
* Large payment values.

### Why?

These checks help identify unusual financial records before calculating reconciliation differences.

The project investigates unusual values instead of automatically deleting them.

---

## Problem 7: Order-Level Financial Reconciliation

The project calculates:

```text
expected_total = product price + freight

difference = paid_total - expected_total
```

The calculation is performed at the order level.

### Why?

The business problem is about comparing the expected and actual amount **for each order**.

Therefore, the data needs to be transformed into one row per order.

---

## Problem 8: Order Status and Financial Behavior

The project compares expected and paid amounts by:

```text
order_status
```

The exploration identifies that reconciliation differences are concentrated more heavily in `canceled` and `unavailable` orders than in delivered orders.

The notebook investigates:

* Delivered orders.
* Canceled orders.
* Unavailable orders.
* Expected amounts.
* Paid amounts.
* Differences between expected and paid values.

### Important interpretation

Payment differences are **not automatically considered fraud or revenue leakage** because refund information is not visible in the available payment data.

---

## Problem 9: Delivered Order Overpayment

The notebook investigates delivered orders that are:

* Exactly matched.
* Within ±R$1.
* More than R$1 above expected.
* More than R$1 below expected.

It also compares payment characteristics such as:

* Main payment type.
* Maximum installments.
* Number of payment records.

### Why?

This helps investigate whether payment structure is related to reconciliation differences.

---

## Problem 10: Date Data Types

The notebook checks the following date columns:

```text
order_purchase_timestamp
order_approved_at
order_delivered_carrier_date
order_delivered_customer_date
order_estimated_delivery_date
```

These columns are converted from text to datetime.

### Why?

Datetime values are required for:

* Date filtering.
* Monthly analysis.
* Delivery-time analysis.
* Sorting.
* Time-based aggregation.

The notebook also verifies that the conversion does not create additional missing values.

---

## Problem 11: Supporting Table Integrity

The project checks:

* Products.
* Sellers.
* Customers.
* Category translation.

It verifies whether IDs used in transactions exist in their parent tables.

### Findings

* Products: **32,951**
* Sellers: **3,095**
* Customers: **99,441**
* 610 products have missing categories.
* 2 categories have no English translation.
* Transaction IDs have matching parent records.
* 1,278 orders contain items from more than one seller.

### Why?

This validates that future joins can be performed without unexpectedly losing transaction records.

---

# 5. Notebook 2 — Data Cleaning

### File:

```text
notebook/02_data_cleaning.ipynb
```

## Purpose

The second notebook applies the cleaning decisions identified during exploration.

The main principle is:

> **Do not remove valid business information just because it is missing.**

---

## Cleaning Step 1: Load Raw Data

The notebook loads the raw CSV files.

The main datasets include:

```text
orders
order_items
payments
customers
products
sellers
category_translation
```

---

## Cleaning Step 2: Convert Date Columns

The five order date columns are converted from text to datetime.

### Why?

This makes the date columns usable for:

* Date calculations.
* Monthly analysis.
* Filtering.
* Sorting.
* Time-based analysis.

The notebook verifies that existing null counts remain unchanged.

---

## Cleaning Step 3: Handle Missing Product Categories

There are **610 products with missing product categories**.

Instead of deleting these products, missing categories are represented as:

```text
unknown
```

### Why?

Deleting these products could remove valid transactions and affect revenue analysis.

Using `unknown` preserves the records.

---

## Cleaning Step 4: Add English Product Categories

The product table is merged with the category translation table.

Two categories were missing from the translation table:

```text
portateis_cozinha_e_preparadores_de_alimentos
pc_gamer
```

They were manually mapped to English labels.

### Why?

English category names make the dataset easier to:

* Analyze.
* Understand.
* Present in dashboards.
* Explain during interviews.

---

## Cleaning Step 5: Validate Row Counts

The notebook compares raw and cleaned row counts.

The expected result is:

```text
raw rows = clean rows
```

### Why?

The cleaning process should not accidentally delete valid transaction records.

---

## Cleaning Step 6: Validate Unique IDs

The notebook checks uniqueness of:

```text
orders.order_id
products.product_id
sellers.seller_id
customers.customer_id
```

### Why?

These IDs are important keys used during joins and analysis.

---

## Cleaning Step 7: Save Cleaned Tables

The cleaned tables are saved under:

```text
data/processed/
```

The processed files include:

```text
orders_clean.csv
order_items_clean.csv
payments_clean.csv
customers_clean.csv
products_clean.csv
sellers_clean.csv
```

A read-back test is also performed to verify that the saved data can be loaded correctly.

---

# 6. Notebook 3 — Data Transformation

### File:

```text
notebook/03_data_transformation.ipynb
```

## Purpose

The third notebook transforms the cleaned transaction-level data into an **order-level reconciliation dataset**.

This is the main transformation stage of the project.

---

## Transformation Step 1: Load Cleaned Data

The notebook loads the cleaned files from:

```text
data/processed/
```

### Why?

Transformation should be performed on cleaned data rather than directly on raw data.

---

## Transformation Step 2: Aggregate Order Items

The `order_items` table can contain multiple rows for one order.

Therefore, it is aggregated using:

```text
groupby("order_id")
```

The following values are calculated:

```text
total_price
total_freight
item_count
seller_count
```

Then:

```text
expected_total = total_price + total_freight
```

### Why?

The reconciliation analysis needs **one expected amount per order**.

Without aggregation, an order containing multiple products would have multiple rows.

---

## Transformation Step 3: Aggregate Payments

The `payments` table can also contain multiple records for one order.

It is aggregated by:

```text
order_id
```

The transformation creates:

```text
paid_total
payment_count
max_installments
main_payment_type
```

### Why?

The project needs the total amount paid for each order.

Therefore:

```text
paid_total = sum of all payment values for the order
```

---

## Transformation Step 4: Create the Reconciliation Dataset

The project combines order-level information from:

```text
orders
+
items_aggregation
+
payments_aggregation
```

The final dataset is:

```text
reconciliation_data
```

It contains important fields such as:

```text
order_id
customer_id
order_status
order_purchase_timestamp
expected_total
paid_total
payment_count
max_installments
main_payment_type
```

### Main design goal

The final dataset contains:

> **One row per order**

This makes order-level reconciliation accurate and avoids the fan-out problem.

---

## Transformation Step 5: Validate the Final Dataset

The notebook checks:

* Total number of rows.
* Unique `order_id`.
* Missing `expected_total`.
* Missing `paid_total`.
* Duplicate `order_id`.
* Data types.

It also identifies orders where either expected or paid revenue is missing.

### Why?

The final dataset needs a reliable and clearly defined order-level structure before SQL analysis.

---

## Transformation Step 6: Save Reconciliation Data

The final transformed dataset is saved as:

```text
data/processed/reconciliation_data.csv
```

This becomes the main dataset for revenue reconciliation analysis.

---

# 7. MySQL Loading

The transformation notebook also contains the MySQL loading process.

## Database

```text
revenue_reconciliation
```

A SQLAlchemy connection is used to connect Python with MySQL.

---

## Tables Loaded Into MySQL

The following seven tables are loaded:

```text
orders
order_items
payments
products
sellers
customers
reconciliation
```

### Why?

The individual tables are retained for relational analysis, while the `reconciliation` table provides the final order-level dataset for reconciliation analysis.

---

## SQL Data Types

Specific SQL data types are defined for important ID and text columns.

For example:

```text
order_id
customer_id
product_id
seller_id
order_status
payment_type
```

### Why?

Explicit data types help control how the data is stored in MySQL and prevent important identifiers from being interpreted incorrectly.

---

## SQL Indexes

Indexes are created on frequently used ID columns such as:

```text
orders.order_id
order_items.order_id
order_items.seller_id
order_items.product_id
payments.order_id
products.product_id
reconciliation.order_id
```

### Why?

Indexes can improve the efficiency of:

* Searching.
* Filtering.
* Joining.
* Querying frequently used ID columns.

---

## SQL Load Validation

After loading the tables, the project compares:

```text
DataFrame row count
        vs
MySQL row count
```

The expected result is:

```text
OK
```

This confirms that the number of rows loaded into MySQL matches the corresponding DataFrame.

---

# 8. Revenue Reconciliation Logic

The main business calculation is:

```text
expected_total = total_price + total_freight

difference = paid_total - expected_total
```

The interpretation is:

```text
difference = 0
    → Matched

difference > 0
    → Overpaid

difference < 0
    → Underpaid
```

If either `paid_total` or `expected_total` is missing:

```text
→ Not Analyzable
```

---

# 9. SQL Analysis

After loading the data into MySQL, SQL is used to answer business questions.

The completed analysis includes:

* Reconciliation status analysis.
* Total overpayment analysis.
* Total underpayment analysis.
* Net revenue discrepancy analysis.
* Largest overpayment orders.
* Largest underpayment orders.
* Payment type analysis.
* Order status analysis.
* Top 10 products by revenue.
* Top 10 sellers by revenue.

---

# 10. Business Insights

## 1. Reconciliation Status

The current analysis identified:

```text
Total orders       = 99,441
Matched orders     = 79,051
Overpaid orders    = 9,898
Underpaid orders   = 9,716
Not analyzable     = 776
```

This means most orders are successfully reconciled, while a smaller portion contains payment discrepancies or missing financial information.

---

## 2. Analyzable Orders

The number of analyzable orders is:

```text
99,441 - 776 = 98,665
```

Therefore:

```text
Analyzable orders = 98,665
```

These orders have the required financial values available for comparison.

---

## 3. Overpaid vs Underpaid Orders

The current results show:

```text
Overpaid orders  = 9,898
Underpaid orders = 9,716
```

There are:

```text
9,898 - 9,716 = 182
```

more overpaid orders than underpaid orders.

---

## 4. Not Analyzable Orders

There are:

```text
776
```

orders that cannot currently be reconciled because required financial information is missing.

These records should not be treated as matched, overpaid, or underpaid.

---

## 5. Financial Difference

The project also calculates:

* Total overpayment.
* Total underpayment.
* Net discrepancy.

These values are used to understand the financial magnitude of reconciliation exceptions.

---

## Important Business Limitation

A reconciliation difference should **not automatically be interpreted as fraud, revenue leakage, or profit loss**.

The available payment data does not provide complete refund information. Therefore, payment differences require business validation before making stronger conclusions.

---

# 11. Project Structure

```text
Revenue-Reconciliation-Exception-Analytics-Project/
│
├── data/
│   ├── raw/
│   └── processed/
│       ├── customers_clean.csv
│       ├── order_items_clean.csv
│       ├── orders_clean.csv
│       ├── payments_clean.csv
│       ├── products_clean.csv
│       ├── reconciliation_data.csv
│       └── sellers_clean.csv
│
├── notebook/
│   ├── 01_data_exploration.ipynb
│   ├── 02_data_cleaning.ipynb
│   └── 03_data_transformation.ipynb
│
├── sql/
│   └── revenue_reconciliation_analysis.sql
│
├── README.md
└── .gitignore
```

---

# 12. Tools and Technologies

* **Python** — Data processing and transformation.
* **Pandas** — Data cleaning, aggregation, and analysis.
* **NumPy** — Numerical operations.
* **Matplotlib** — Data visualization during analysis.
* **Seaborn** — Exploratory visualization.
* **Jupyter Notebook** — Development and documentation.
* **MySQL** — Structured data storage and SQL analysis.
* **SQLAlchemy** — Python-to-MySQL database connection.
* **PyMySQL** — MySQL database driver.
* **SQL** — Business analysis and reporting.

---

# 13. Skills Demonstrated

### Python / Pandas

* Data loading.
* Data exploration.
* Missing-value analysis.
* Duplicate checks.
* Data-type conversion.
* GroupBy aggregation.
* Merge and joins.
* Data validation.
* CSV processing.

### SQL / MySQL

* `SELECT`
* `WHERE`
* `GROUP BY`
* `ORDER BY`
* `COUNT`
* `SUM`
* `DISTINCT`
* `CASE`
* Aggregation.
* Indexing.
* Data validation.
* Relational analysis.

### Data Analysis

* Revenue reconciliation.
* Payment exception analysis.
* Payment analysis.
* Order-status analysis.
* Product revenue analysis.
* Seller revenue analysis.
* Business interpretation.

---

# 14. Main Project Outcome

The project converts multiple raw e-commerce transaction tables into a validated, order-level revenue reconciliation dataset.

The final workflow makes it possible to answer:

> **How much was expected for each order, how much was actually paid, and where do payment discrepancies occur?**

The project also demonstrates why transaction tables must be aggregated to the correct grain before joining them.

This prevents incorrect revenue and payment calculations caused by join fan-out.

---

# 15. Conclusion

This project demonstrates a complete data-analysis workflow:

```text
Explore
  ↓
Identify Data Problems
  ↓
Clean
  ↓
Validate
  ↓
Transform
  ↓
Create Order-Level Reconciliation
  ↓
Load Into MySQL
  ↓
Analyze With SQL
  ↓
Generate Business Insights
```

The main analytical focus is:

> **Revenue Reconciliation and Payment Exception Analysis**

The supporting tables also allow analysis of customers, products, sellers, payments, and order status.
