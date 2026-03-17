#! /usr/bin/env python3
#
# SQL queries can be constructed dynamically, at program run time:
# embedded SQL queries are regular Python strings.
#
# 1. Interpolation:
#    Use query templates in which query parameters indicate where
#    Python values may replace SQL values (NOT: SQL names, SQL clauses)
#
# 2. Concatenation (⚠️ Risk of SQL injection—DO NOT USE)
#    Concatenating malicliously crafted strings to SQL query fragments
#    can subtantially alter the intended purpose of a query and may
#    be used to disclose database contents to attackers.

import duckdb
import os
from datetime import date

# Connect to the vanilla vehicles/peeps database
#
#   vehicles(vehicle, kind, seats, wheels?, pid -> peeps(pid))
#   peeps(pid, pic, name, born)
#
# NB. Run generate-045-vehicles.sql to generate DuckDB database 045-vehicles.db
DATABASE = "045-vehicles.db"
database = os.path.join(os.getcwd(), DATABASE)

# 1. Interpolation (Parameterized Queries)

with duckdb.connect(database) as con:
  # Query template (parameters $1, $2 take the place of SQL values)
  query = """
    SELECT $1 || p.name AS driver
    FROM   peeps AS p
    WHERE  p.born < $2
  """
  # Instantiate the query template twice:
  # 1. List older drivers only
  rel = con.sql(query,
                params = [ "Older driver: ", 1980 ])
  rel.show()

  # 2. List all (legal) drivers
  rel = con.sql(query,
                params = [ "Legal driver: ", date.today().year - 18 ])
  rel.show()

  # - Parameter $i (i >= 1) is replace by element i in parameter list.
  # - Alternatively, use named parameters (e.g., $prefix, $year) and
  #   replace these with values in a Python dictonary:
  #
  #       con.sql(..., params = {"prefix": ...,  "year": ...})

# ---------------------------------------------------------------------

# 2. Concatentation (⚠️ Risk of SQL injection)

# In the database connected as con, find the peep named N
# if she/he is of age
def adult_peep(con, N):
  query = """
    FROM  peeps AS p
    WHERE p.name = '""" + N + "' AND year(today()) - p.born >= 18"

  # show query after concatenation (for debugging only)
  print(f"""
    Concatenated query:
    {query}
   """)

  # execute constructed query, dump result table
  try:
    rel = con.sql(query)
    rel.show()
  except Exception as e:
    print(f"Query failed:\n{e}")


# In the database connected as con, find seating capacity
# for all vehicles of kind K
def vehicle_seats(con, K):
  query = """
    SELECT v.vehicle, v.seats
    FROM   vehicles AS v
    WHERE  v.kind = '""" + K + "'"

  # show query after concatenation (for debugging only)
  print(f"""
    Concatenated query:
    {query}
   """)

  # execute constructed query, dump result table
  try:
    rel = con.sql(query)
    rel.show()
  except Exception as e:
    print(f"Query failed:\n{e}")


# Connnect to the vehicles/peeps database in read-only mode
# since SQL injection will turn out harmful...
#
# Exercise the adult_peep() and vehicle_seats() procedures
with duckdb.connect(database, read_only = True) as con:
  adult_peep(con, "Bert")          # OK (one row)
  adult_peep(con, "Cleo")          # OK (no row)
  # ⚠️ (woops, dumps entire peeps table, including non-adults)
  adult_peep(con, "' OR true --")


  vehicle_seats(con, "bus")        # OK (two rows)
  # ⚠️ (reads and accesses the peeps table although that table
  #     was never mentioned in the intended query)
  vehicle_seats(con, "' UNION ALL SELECT p.pic, p.born FROM peeps AS p --")
  # ⚠️⚠️ (would delete the peeps table, this is an instance of
  #        the "Little Bobby Tables" hack, see https://xkcd.com/327/)
  vehicle_seats(con, "'; DROP TABLE peeps; --")
