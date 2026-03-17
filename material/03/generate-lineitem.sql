-- Generate a CSV file for TPC-H table lineitem (scale factor 1,
-- about 6 million rows, about 720 MB). Use DuckDB's tpch extension to
-- generate the base lineitem data.

.bail on

ATTACH IF NOT EXISTS ':memory:';
USE memory;

INSTALL tpch;
LOAD tpch;
CALL dbgen(sf = 1);

.shell rm -f lineitem.csv

COPY (SELECT * REPLACE (l_quantity :: bigint AS l_quantity)
      FROM lineitem)
TO 'lineitem.csv' (delimiter '|', header false);
