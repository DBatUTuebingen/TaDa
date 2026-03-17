#! /usr/bin/env python3
#
# DuckDB implements highly efficient grouping/aggregation algorithms
# and associated data structure.  We can implement grouping outside
# the DBMS (e.g., using DuckDB's Python API) but we are well advised
# to perform the computation using SQL and thus inside DuckDB, close
# to the data.
#
# The performance difference is substantial.  See below.

import duckdb
import os
import timeit

# Attach to the NYC Taxi database
# NB. Run generate-051-nyc-taxi.sql to generate DuckDB database 051-nyc-taxi.db
DATABASE = "051-nyc-taxi.db"
database = os.path.join(os.getcwd(), DATABASE)

# Implement Query 1 found in 050-nyc-taxi.sql:
#
# -- Popularity of ride payment types (credit card, cash, ...)
# SELECT ['credit card', 'cash', 'no charge'][r.payment] AS "paid via",
#        count(*) AS rides
# FROM   rides AS r
# WHERE  r.payment IN (1,2,3)
# GROUP BY r.payment
# ORDER BY rides DESC;

# (1) Implement grouping/aggregation in SQL :-)
def payment_types_grouping_aggregation(con):
  # Submits a single query and extracts three rows
  rel = con.sql("""
    SELECT ['credit card', 'cash', 'no charge'][r.payment] AS "paid via",
           count(*) AS rides
    FROM   rides AS r
    WHERE  r.payment IN (1,2,3)
    GROUP BY r.payment
    """)
  # Dump resulting payment/count pairs
  while t := rel.fetchone():
    print(f"{t[0]}: {t[1]}")


# (2) Only implement (non-grouped) aggregation in SQL :-/
def payment_types_aggregation(con):
  paid_via = {1: 'credit card', 2: 'cash', 3: 'no charge'}
  rides    = {1: 0, 2: 0, 3: 0}
  # Submits one aggregation query per group,
  # each returning a single row
  for payment in rides.keys():
    rel = con.sql("""
      SELECT count(*) AS rides
      FROM   rides AS r
      WHERE  r.payment = $payment
      """, params = { "payment": payment })
    count = rel.fetchone()
    if count is not None:
      rides[payment] = count[0]   # save aggregate for group
    rel.fetchone()
  # Dump resulting payment/count pairs
  for payment in rides.keys():
    print(f"{paid_via[payment]}: {rides[payment]}")


# (3) Extract all relevant rows,
#     perform grouping and aggegration outside the DBMS :-(
def payment_types(con):
  paid_via = {1: 'credit card', 2: 'cash', 3: 'no charge'}
  rides    = {1: 0, 2: 0, 3: 0}
  # Submits a single query but extracts lots of rows
  rel = con.sql("""
    SELECT r.payment
    FROM   rides AS r
    WHERE  r.payment IN (1,2,3)
    """)
  while t := rel.fetchone():
    rides[t[0]] += 1              # group + maintain aggregate
  # Dump resulting payment/count pairs
  for payment in rides.keys():
    print(f"{paid_via[payment]}: {rides[payment]}")


with duckdb.connect(database, read_only = True) as con:
  print(f"(1) {timeit.timeit(lambda: payment_types_grouping_aggregation(con), number = 1)} seconds\n")
  print(f"(2) {timeit.timeit(lambda: payment_types_aggregation(con),          number = 1)} seconds\n")
  print(f"(3) {timeit.timeit(lambda: payment_types(con),                      number = 1)} seconds\n")
