-- DuckDB can push projections (access to particular columns only) and
-- filters (access to particular rows satisying a predicate) down into
-- the PARQUET_SCAN reader

-- Download NYC Yellow Cab rides in April 2019 (if required)
.shell curl -O https://blobs.duckdb.org/data/taxi_2019_04.parquet

-- Report query times to assess the impact of pushdown
.timer on

-- Query Q:
-- How many taxi pickups happened between April 15 and April 20?
-- (‹e› BETWEEN ‹lo› AND ‹hi› is syntactic sugar for ‹e› >= ‹lo› AND ‹e› <= ‹hi›)
SELECT count(pickup_at)
FROM   'taxi_2019_04.parquet'
WHERE  pickup_at BETWEEN '2019-04-15' AND '2019-04-20';


-- DuckDB only reads column tpep_pickup_datetime (projection pushdown)
-- and evaluates the range predicate already (filter pushdown)
-- during PARQUET_SCAN => the downstream plan processes less data.
EXPLAIN ANALYZE
SELECT count(pickup_at)
FROM   'taxi_2019_04.parquet'
WHERE  pickup_at BETWEEN '2019-04-15' AND '2019-04-20';


-- CSV can support projection pushdown (skip parsing for non-relevant fields)
-- but cannot support filter pushdown (since the data is untyped, no zone map
-- meta data present) => a downstream FILTER operator is placed in the plan
-- which is hit by the full cardinality of the CSV file:
EXPLAIN ANALYZE
SELECT count(pickup_at)
FROM   'taxi_2019_04.csv'
WHERE  pickup_at :: timestamp BETWEEN '2019-04-15' AND '2019-04-20';


-- Show metadata per row group (= column chunk).  The
-- (stats_min, stats_max) pairs form zone maps for the columns.
SELECT row_group_id, path_in_schema AS "column", row_group_num_rows,
       stats_min, stats_max
FROM   parquet_metadata('taxi_2019_04.parquet')
WHERE  path_in_schema = 'pickup_at'
ORDER BY row_group_id;


-- Which row groups are relevant for query Q (all others may be skipped)?
SELECT row_group_id,
       row_group_num_rows,
          '2019-04-15' BETWEEN stats_min AND stats_max
       OR '2019-04-20' BETWEEN stats_min AND stats_max AS "relevant?"
FROM   parquet_metadata('taxi_2019_04.parquet')
WHERE  path_in_schema = 'pickup_at'
ORDER BY "relevant?", row_group_id;


-- QUIZ: Formulate a SQL query that shows the % of rows that can be skipped.

-- CSV file on disk obsolete now
.shell rm taxi_2019_04.csv
