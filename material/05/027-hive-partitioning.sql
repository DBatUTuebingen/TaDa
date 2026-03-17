-- Demonstrate how DuckDB writes/reads partitioned data files
--
-- Hive Partitioning split data files based on the values
-- found in n ⩾ 1 columns c₁, c₂, ..., cₙ: rows that
-- agree on the values in all columns cᵢ form one partition.

-- Download NYC Yellow Cab rides in April 2019 (if required)
.shell curl -O https://blobs.duckdb.org/data/taxi_2019_04.parquet

-- Partition Yellow Cab rides in April 2019 based on
-- - vendor_id (active domain: {1,2,4})
-- - payment_type (active domain: {1,2,3,4})
--
-- Resulting data file hierarchy has depth 2 and a maximum width of 3 × 4 = 12
-- (not all vendor_id/payment_type combinations will occur in the data).
.shell mkdir taxi
COPY (FROM 'taxi_2019_04.parquet')
TO   'taxi/nyc-yellow-cabs'  -- root of file hierarchy
(FORMAT parquet, PARTITION_BY (vendor_id, payment_type), RETURN_FILES);
--      └──────┘               └──────────────────────┘
--      OK: csv                  partition criteria

-- File hierarchy created in the OS file system (actual width is 10 ⩽ 12)
.shell tree taxi/nyc-yellow-cabs

------------------------------------------------------------------------

-- Now perform queries over the partitioned files.

.timer on

-- In table function read_parquet() use
-- - a shell glob pattern to include all (relevant) files in the hierarchy
-- - flag hive_partitioning = true such that DuckDB knows how to
--   interpret directory names like "vendor_id=2" or "payment_type=4"
SELECT count(*)
FROM   read_parquet('taxi/nyc-yellow-cabs/*/*/*.parquet', hive_partitioning = true)
WHERE  vendor_id = '2';
--     └─────────────┘
--  only one subtree of the hierachy is relevant

EXPLAIN ANALYZE
SELECT count(*)
FROM   read_parquet('taxi/nyc-yellow-cabs/*/*/*.parquet', hive_partitioning = true)
WHERE  vendor_id = '2';

-- Indeed, only 4 (of 10) data files are being touched:
--
-- ┌──────────────────────────────┴──────────────────────────────┐
-- │                     UNGROUPED_AGGREGATE                     │
-- │    ──────────────────────────────────────────────────────   │
-- │                   Aggregates: count_star()                  │
-- │                                                             │
-- │                            1 Rows                           │
-- │                           (0.00s)                           │
-- └──────────────────────────────┬──────────────────────────────┘
-- ┌──────────────────────────────┴──────────────────────────────┐
-- │                          TABLE_SCAN                         │
-- │    ──────────────────────────────────────────────────────   │
-- │                    Function: READ_PARQUET                   │
-- │                File Filters: (vendor_id = 2)                │
-- │                     Scanning Files: 4/10 ⚠                 │
-- │                                                             │
-- │                         4633794 Rows                        │
-- │                           (0.02s)                           │
-- └─────────────────────────────────────────────────────────────┘

EXPLAIN ANALYZE
SELECT count(*)
FROM   read_parquet('taxi/nyc-yellow-cabs/*/*/*.parquet', hive_partitioning = true)
WHERE  payment_type = '3';
--     └────────────────┘
--  only two files at the leaf level are relevant

-- Indeed:
--
-- ┌──────────────────────────────┴──────────────────────────────┐
-- │                     UNGROUPED_AGGREGATE                     │
-- │    ──────────────────────────────────────────────────────   │
-- │                   Aggregates: count_star()                  │
-- │                                                             │
-- │                            1 Rows                           │
-- │                           (0.00s)                           │
-- └──────────────────────────────┬──────────────────────────────┘
-- ┌──────────────────────────────┴──────────────────────────────┐
-- │                          TABLE_SCAN                         │
-- │    ──────────────────────────────────────────────────────   │
-- │                    Function: READ_PARQUET                   │
-- │               File Filters: (payment_type = 3)              │
-- │                     Scanning Files: 2/10 ⚠                 │
-- │                                                             │
-- │                          38284 Rows                         │
-- │                           (0.00s)                           │
-- └─────────────────────────────────────────────────────────────┘

-- Compare query run times:
--
-- Perform the same query on the non-partitioned NYC taxi data
-- Parquet file:
EXPLAIN ANALYZE
SELECT count(*)
FROM   'taxi_2019_04.parquet'
WHERE  payment_type = '3';

-- No filter pushdown:
--
-- ┌──────────────────────────────┴──────────────────────────────┐
-- │                     UNGROUPED_AGGREGATE                     │
-- │    ──────────────────────────────────────────────────────   │
-- │                   Aggregates: count_star()                  │
-- │                                                             │
-- │                            1 Rows                           │
-- │                           (0.00s)                           │
-- └──────────────────────────────┬──────────────────────────────┘
-- ┌──────────────────────────────┴──────────────────────────────┐
-- │                          TABLE_SCAN                         │
-- │    ──────────────────────────────────────────────────────   │
-- │                    Function: PARQUET_SCAN                   │
-- │                  Filters: payment_type='3'                  │
-- │                                                             │
-- │                          38284 Rows                         │
-- │                           (0.06s)                           │
-- └─────────────────────────────────────────────────────────────┘

-- Hive-partitions (file hierarchy) not needed anymore
.shell rm -rf taxi/nyc-yellow-cabs
