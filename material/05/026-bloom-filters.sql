-- DuckDB can use Bloom filters (if present) embedded in Parquet files to
-- prove that a given row group does NOT contain a particular value.

-- Download NYC Yellow Cab rides in April 2019 (if required)
.shell curl -O https://blobs.duckdb.org/data/taxi_2019_04.parquet

-- There are no Bloom filters in NYC Yello Cab data...
SELECT list(bloom_filter_length)
FROM   parquet_metadata('taxi_2019_04.parquet');

-- ... so we create our own Parquet files with (and without) Bloom filters.
--
-- Create a single-column Parquet file with values 0,100,200,...,900.
-- Few distinct values => use a dictionary encoding, Bloom filter will
-- be applied and will be compact (since the set of values to represent is small).
--
-- Use 100 million rows in 10 row groups, leads to approx 88 MB on disk.
COPY (SELECT 100 * (i % 10) AS i
      FROM  range(100_000_000) AS _(i)
      ORDER BY random()
)
TO 'bloom.parquet'
(FORMAT parquet, ROW_GROUP_SIZE 10_000_000);

FROM 'bloom.parquet'
LIMIT 10;

SUMMARIZE 'bloom.parquet';

-- size 88 MB (dictionary encoding)
.shell ls -lh bloom.parquet

-- For comparison:
-- Create a copy of the Parquet file (no dictionary encoding, thus no Bloom filter)
COPY 'bloom.parquet'
TO   'no-bloom.parquet'
(FORMAT parquet, DICTIONARY_SIZE_LIMIT 1, ROW_GROUP_SIZE 10_000_000);
--                                     ^
--                       too small to encode a dictionary


FROM 'no-bloom.parquet'
LIMIT 10;

SUMMARIZE 'no-bloom.parquet';

-- size 181 MB (no dictionary encoding)
.shell ls -lh bloom.parquet no-bloom.parquet

------------------------------------------------------------------------
-- Filter pushdown based on Bloom filters

-- Problem: the zone map for column i indicates ranges [0,900] for
-- all row groups.  That's correct, but coarse:
-- only 10 values in that range actually occur. :-/  These zone maps
-- will not allow us to skip any row group if we search for any i-value
-- in the [0,900] range.
SELECT row_group_id, path_in_schema AS "column", row_group_num_rows,
       stats_min, stats_max
FROM   parquet_metadata('bloom.parquet')
ORDER BY row_group_id;


-- But: DuckDB has created Bloom filters per row group,
-- size overhead: 47(!) bytes only.
SELECT row_group_id, bloom_filter_length
FROM   parquet_metadata('bloom.parquet');

-- No Bloom filter in the no-bloom.parquet file:
SELECT row_group_id, bloom_filter_length
FROM   parquet_metadata('no-bloom.parquet');


.timer on

-- Search for an i-value NOT present in the Parquet file.  The Bloom
-- filters will guide DuckDB to skip ALL row groups: no data will be
-- read at all.
SELECT sum(i)  -- = NULL (no rows qualify, Bloom filter excludes ALL row groups)
FROM   'bloom.parquet'
WHERE  i = 501;

-- Check: indeed, all Bloom filters correctly exclude value 501:
FROM parquet_bloom_probe('bloom.parquet', 'i', 501);

-- The Bloom filters do not exclude existing value 500, however.
-- All row groups need to be read, query run time degrades:
SELECT sum(i)
FROM   'bloom.parquet'
WHERE  i = 500;  -- value exists: Bloom filter excludes NO row group

-- Check: indeed, no exclusion:
FROM parquet_bloom_probe('bloom.parquet', 'i', 500);


-- A search for values 501/500 in the absence of Bloom filters requires
-- DuckDB to read all row groups in both cases since the zone maps exclude nothing.
-- No (significant) performance difference:
SELECT sum(i)  -- = NULL (no rows qualify, Bloom filter excludes ALL row groups)
FROM   'no-bloom.parquet'
WHERE  i = 501;

SELECT sum(i)
FROM   'no-bloom.parquet'
WHERE  i = 500;

-- These Parquet files were used for this experiment only
.shell rm bloom.parquet no-bloom.parquet
