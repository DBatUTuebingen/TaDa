-- Read the vehicles CVS file (using default confguration parameters)
--
-- Issues:
-- - All columns returned as type varchar (≡ text), had expected
--   that column seats is detected to contain integers, column "wheels?"
--   to contain boolean values.
-- - All columns (except vehicle) appears to contain spurious leading space ' '.
-- - In the 'tank' row, ' ' not detected as NULL value
FROM read_csv('vehicles.csv');

-- Read vehicles CSV file, specify delimiter ', ' (space comma) explicitly
--
-- Issues:
-- - Type of column "wheels?" detected to be boolean. ✓
-- - Spurious leading spaces gone. ✓
-- - Type of column seats still text (not integer):
--   ' ' not detected as NULL, ' ' not convertible to integer.
FROM read_csv('vehicles.csv',
              delim = ', ');

-- Read vehicles CSV file, specify delimiter ', ' and representation of NULL
FROM read_csv('vehicles.csv',
              delim = ', ',
              nullstr = ' ');

-- Read the drivers CSV file (default configuration parameters are OK):
FROM 'drivers.csv';

------------------------------------------------------------------------

-- Read the movie script of Star Wars Episode IV (A New Hope)
--
-- Issues:
-- - First line mistakingly interpreted as table header
-- - Single-column table (delimiter ' ' not detected)
FROM read_csv('StarWars-EpisodeIV.txt');

-- Read the movie script of Star Wars Episode IV (A New Hope),
-- no header row, explicitly set column names, specifiy delimiter ' ' (space)
FROM read_csv('StarWars-EpisodeIV.txt',
              header = false,
              names = ['id', 'character', 'dialogue'],
              delim = ' ');

------------------------------------------------------------------------

-- CSV files can be huge: read the 6+ million rows/16 columns of the
-- lineitem table of the TPC-H database benchmark (https://www.tpc.org/tpch/).
-- TPC-H models a warehouse, with suppliers/customers and order fulfillment.

-- NB. Run generate-lineitem.sql to generate CSV file lineitem.csv
FROM 'lineitem.csv';  -- ⚠️ this will read and dump 6+ million rows

FROM read_csv('lineitem.csv',
              header = false,
              names = ['l_orderkey', 'l_partkey', 'l_suppkey', 'l_linenumber', 'l_quantity',
                       'l_extendedprice', 'l_discount', 'l_tax', 'l_returnflag',
                       'l_linestatus', 'l_shipdate', 'l_commitdate', 'l_receiptdate',
                       'l_shipinstruct', 'l_shipmode', 'l_comment'])
LIMIT 20;
------------------------------------------------------------------------

-- SQL syntax:
--
-- Limit the number of rows returned by a query: return ‹n› arbitrary rows
-- of table ‹t› (recall: tables are unordered):
--
-- FROM ‹t›
-- LIMIT ‹n›;

-- List *any* 10 ordered lineitems (rows are unordered):
FROM 'lineitem.csv'
LIMIT 10;

-- Combine LIMIT with ORDER BY to return the first ‹n› rows in a
-- well-defined order:
--
-- FROM ‹t›
-- ORDER BY ‹col›
-- LIMIT ‹n›;

-- List the 50 lineitems that we need to ship the soonest:
FROM read_csv('lineitem.csv',
              header = false,
              names = ['l_orderkey', 'l_partkey', 'l_suppkey', 'l_linenumber', 'l_quantity',
                       'l_extendedprice', 'l_discount', 'l_tax', 'l_returnflag',
                       'l_linestatus', 'l_shipdate', 'l_commitdate', 'l_receiptdate',
                       'l_shipinstruct', 'l_shipmode', 'l_comment'])
ORDER BY l_shipdate, l_orderkey
LIMIT 50;

------------------------------------------------------------------------

-- SQL Syntax:
--
-- Control the columns returned by a query: for each row returned,
-- evaluate the expressions ‹expr₁›,...,‹exprₙ› defined in the SELECT clause:
--
-- SELECT ‹expr₁› [AS ‹c₁›],...,‹exprₙ› [AS ‹cₙ›]
-- FROM ‹t›
--
-- If the optional column names ‹cᵢ› are not provided, SQL tries to
-- derive reasonable names on its own (this may fail or lead to ambiguous names).
-- Good SQL practice is to provide column names explicitly.

SELECT l_orderkey, l_shipdate, l_comment
FROM read_csv('lineitem.csv',
              header = false,
              names = ['l_orderkey', 'l_partkey', 'l_suppkey', 'l_linenumber', 'l_quantity',
                       'l_extendedprice', 'l_discount', 'l_tax', 'l_returnflag',
                       'l_linestatus', 'l_shipdate', 'l_commitdate', 'l_receiptdate',
                       'l_shipinstruct', 'l_shipmode', 'l_comment'])
ORDER BY l_shipdate, l_orderkey
LIMIT 50;

-- list and visualize vehicle seating capacity
SELECT vehicle, seats, bar(seats,0,50,30)
FROM   read_csv('vehicles.csv',
                delim = ', ',
                nullstr = ' ');

--                               specify descriptive column name
--                                        ┌─────────┐
SELECT vehicle, seats, bar(seats,0,50,30) AS capacity
FROM   read_csv('vehicles.csv',
                delim = ', ',
                nullstr = ' ');
