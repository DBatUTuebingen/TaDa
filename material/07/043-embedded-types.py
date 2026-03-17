#! /usr/bin/env python3
#
# SQL statements and queries can be embedded into Python code.
# See the DuckDB document for a complete reference of DuckDB's Python API:
# https://duckdb.org/docs/stable/clients/python/reference/index
#
# Here:
# - Exception handling
# - Receiving query result row-by-row (con.fetchone())
# - Mapping SQL data types to Python types

import duckdb

# Connect to an in-memory (non-persistent database)
with duckdb.connect(":memory:") as con:
  # This query will fail at compile time (bogus column reference),
  # catch DuckDB's exception
  try:
    con.sql("""
        SELECT log(t.y) AS log
        FROM   generate_series(10,0,-1) AS t(x)
      """)
  except Exception as e:
    print(f"Query failed\n{e}")

  # This query will fail at run time (log of 0 undefined),
  # DuckDB will throw an exception once we try to receive results
  # (only then will the query be executed by DuckDB)
  try:
    rel = con.sql("""
        SELECT log(t.x) AS log
        FROM   generate_series(10,0,-1) AS t(x)
      """)
    # Receive all result rows (only now the query is executed — and will fail)
    result = rel.fetchall()
  except Exception as e:
    print(f"Query failed\n{e}")

  # ----- 8< ----- 8< ----- 8< ----- 8< ----- 8< ----- 8< -----

  # Evaluate query, result table is made available to be fetched later
  rel = con.sql("""
      SELECT t.x, bar(t.x,0,10,20) AS bar
      FROM   generate_series(1,10) AS t(x)
    """)
  # - Do NOT materialize the result table as a list, instead
  #   fetch the result row-by-row.  con.fetchone() returns None (≡ False)
  #   once all rows have been consumed.
  # - DuckDB's API is involved in each iteration of the while loop
  #   (this will work even for HUGE result tables)
  while row := rel.fetchone():
    print(f"{row[0]:2d} | {row[1]}")

  # ----- 8< ----- 8< ----- 8< ----- 8< ----- 8< ----- 8< -----

  # DuckDB's Python API maps SQL data types to Python types

  # Preparation: DDL statement that defines enum type rps
  con.sql("CREATE TYPE rps AS ENUM ('rock', 'paper', 'scissor')")

  # Single-row query that exercises this type mapping
  rel = con.sql("""
      SELECT NULL                                                 AS col1,
             42                                                   AS col2,
             (10^20) :: hugeint                                   AS col3,
             true                                                 AS col4,
             '🍓🍒🍎'                                            AS col5,
             'paper' :: rps                                       AS col6,
             0.1 :: double + 0.2                                  AS col7,
             0.1 :: decimal(3,2) + 0.2                            AS col8,
             '1904-05-30' :: date                                 AS col9,
             '1969-07-21 03:56:00' :: timestamp                   AS col10,
             '90 minutes' :: interval                             AS col11,
             [1138, 2187]                                         AS col12,
             {'zip':72076, 'street':'Sand 13', 'city':'Tübingen'} AS col13,
             ('A New Hope', 4, ['Luke', 'Han', 'Ben', 'Leia'])    AS col14,
             encode('🍓🍒🍎') :: blob                            AS col15
    """)
  # Obtain column names and SQL data types of result table
  columns = rel.columns
  types   = rel.types
  # Fetch the single result row
  row = rel.fetchone()
  # Display column name | SQL data type | Python type | Python val/obj
  for col, typ, cell in zip(columns, types, list(row)):
    print(f"{col:5} | {str(typ):50} | {str(type(cell)):30} | {repr(cell)}")
  # There are no more rows: this will return None
  row = rel.fetchone()
  print(row)

# Connection to DuckDB is closed once we reach this point
