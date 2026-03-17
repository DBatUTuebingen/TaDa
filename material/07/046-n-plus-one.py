#! /usr/bin/env python3
#
# Move your computation close to the data:
#
# 1. Do NOT reimplement query logic (e.g., filtering, aggregating,
#    joins) in the Python realm, effectively demoting the DBMS to
#    a dumb table storage.
# 2. Do NOT fall for the infamous n+1 query problem (iteratively
#    evaluate parameterized queries).  Instead, use a (correlated)
#    subquery and let the query optimizer apply its decorrelation
#    techniques.

import duckdb
import os
import timeit

# Reuse the Rijden de Treinen railways database:
#
#   trains(ID, SERVICE, date, type, company,
#          completely_cancelled, partly_cancelled, max_delay)
#
#   stations(STATION, name)
#
#   stops((ID, SERVICE) -> trains, STATION -> stations,
#         arrival, arrival_delay, arrival_cancelled,
#         departure, departure_delay, departure_cancelled)
#
# NB. Run generate-041-railway.sql to generate DuckDB database 041-railway.db
DATABASE = "041-railway.db"
database = os.path.join(os.getcwd(), DATABASE)


# 1. In the database connected as con, find the maximum delay
#    across all trains.

# Perform the aggregation close to the data,
# return a single cell to Python only. :-)
def aggregate(con):
  rel = con.sql("""
    SELECT max(t.max_delay)
    FROM   trains AS t
    """)
  # The query will return a single cell result
  max_delay = rel.fetchone()
  if max_delay is not None:
    print(max_delay[0])
  # (This will always fetch None)
  rel.fetchone()

# Access all train data on the DBMS side, then perform the
# aggregation on the Python side :-(.  With row_by_row = False,
# we will fetch all result rows in one go.
def dumb_table_storage(con, row_by_row = True):
  # Access all train data, we'll do the rest...
  rel = con.sql("FROM trains")

  # Iterate over all trains t, maintain max aggregate
  # (max_delay is in the 8th column)
  if row_by_row:
    max_delay = 0
    while t := rel.fetchone():
      max_delay = max(max_delay, t[7])
  else:
    trains = rel.fetchall()
    max_delay = max([ t[7] for t in trains ])

  print(max_delay)

# ---------------------------------------------------------------------

# 2. In the database connected as con, find those train services
#    that connect Munich and Dortmund main stations.

# Implement the query using a correlated subquery just like we did
# in 040-quantification.sql.  This will issue a single SQL query. :-)
def single(con):
  rel = con.sql("""
    SELECT DISTINCT t.service, t.type, t.company
    FROM   trains AS t
    WHERE  EXISTS (FROM stops AS s NATURAL JOIN stations AS st
                  WHERE t.id = s.id AND t.service = s.service
                  AND st.name = 'Dortmund Hbf')
    AND    EXISTS (FROM stops AS s NATURAL JOIN stations AS st
                  WHERE t.id = s.id AND t.service = s.service
                  AND st.name = 'München Hbf')
    """)
  result = rel.fetchall()
  print(result)


# ⚠️ The procedure below suffers from the n+1 query problem and its
#     execution will take about 4 minutes on my Apple MacBook Pro M2.
#     :-(
def n_plus_one(con):
  result = []

  # Access all trains (1 query)
  outer = con.sql("FROM trains")
  trains = outer.fetchall()
  # Iterate over all trains t (n = |trains| queries)
  for t in trains:
    # The inner/iterated query is parameterized by t
    inner = con.sql("""
      SELECT EXISTS (FROM stops AS s NATURAL JOIN stations AS st
                     WHERE $id = s.id AND $service = s.service
                     AND st.name = 'Dortmund Hbf')
             AND
             EXISTS (FROM stops AS s NATURAL JOIN stations AS st
                     WHERE $id = s.id AND $service = s.service
                     AND st.name = 'München Hbf')
    """, params = { "id": t[0], "service": t[1] })
    # The inner query returns a single cell only
    dortmund_munich = inner.fetchone()
    if dortmund_munich is not None:
      # If the inner query returned true, add to the result
      if dortmund_munich[0]:
        result += (t[1], t[3], t[4])
        print(t)  # debugging only
      # (This will always fetch None)
      inner.fetchone()

  # Remove duplicate train services
  print(set(result))


with duckdb.connect(database, read_only = True) as con:
  print(f"{timeit.timeit(lambda: aggregate(con), number = 1)} seconds")
  print(f"{timeit.timeit(lambda: dumb_table_storage(con), number = 1)} seconds")
  print(f"{timeit.timeit(lambda: dumb_table_storage(con, False), number = 1)} seconds")

  print(f"{timeit.timeit(lambda: single(con), number = 1)} seconds")
  # ⚠️ The following takes several minutes...
  print(f"{timeit.timeit(lambda: n_plus_one(con), number = 1)} seconds")
