#! /usr/bin/env python3
#
# SQL statements and queries can be embedded into Python code.
# See the DuckDB document for a complete reference of DuckDB's Python API:
# https://duckdb.org/docs/stable/clients/python/reference/index
#
# To obtain Python module duckdb, use
#
#   $ pip install duckdb
#
# in your shell (pip is a Python package manager).

import duckdb

# Connect to an in-memory (non-persistent database),
# con will be a DuckDBPyConnection object that represents our
# connection to DuckDB
with duckdb.connect(":memory:") as con:
  # Evaluate query, return result as DuckDBPyRelation object rel
  # that represents a table
  rel = con.sql("""
      SELECT t.x, bar(t.x,0,10,20) AS bar
      FROM   generate_series(1,10) AS t(x)
    """)
  # Dump result table (just like in the CLI)
  rel.show()

  # ----- 8< ----- 8< ----- 8< ----- 8< ----- 8< ----- 8< -----

  # Evaluate query
  rel = con.sql("""
      SELECT t.x, bar(t.x,0,10,20) AS bar
      FROM   generate_series(1,10) AS t(x)
      ORDER BY t.x DESC
    """)
  # Receive *all* result rows as a single (potentially looong) list
  # of Python tuples
  result = rel.fetchall()
  print(f"Received {len(result)} rows:")
  # Iterate over all rows, print tuples: row[c] access the cth column in the row,
  # DuckDB is not involved in this
  for row in result:
    print(f"{row[0]:2d} | {row[1]}")

# When we exit the scope of the with ... as con:, the connection to DuckDB
# is closed and allocated resources are freed.  This will fail:
#
# con.sql("SELECT 'oops!'")
