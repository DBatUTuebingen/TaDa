-- Demonstrate DuckDB's various lightweight compression schemes


-- Compression is only applied to on-disk data:
-- attach to a persistent DB file, make it the default database
ATTACH 'compressed.db';
USE compressed;

-- Create table t whose columns *should* be ideal target for
-- specfic compression schemes
CREATE OR REPLACE TABLE t(
  const    int,      -- holds single constant value 42 in all cells
  rle      int,      -- holds runs (length 1000) of constant values
  bitpack  int,      -- holds tiny integers (0...9), 4 bits suffice
  "for"    hugeint,  -- holds huge integers 10^24+Δ (Δ is tiny)
  dict     text,     -- holds 1 of 5 constant strings
  fsst     text,     -- holds base 16 (hex, as text): repeated substrings
  alp      float     -- holds IEEE 754 floats in range 0.000001...0.18432
);

DESCRIBE t;

------------------------------------------------------------------------

-- SQL syntax:
--
-- - Built-in table function generate_series(‹start›,‹stop›,‹step›)
--   generates a single-column table with values
--
--     ‹start›
--     ‹start› + 1×‹step›
--     ‹start› + 2×‹step›
--     ‹start› + 3×‹step›
--        ⋮
--     ‹stop›  [generated values will never "step beyond" ‹stop›]
--
-- - Types:
--   - ‹start›, ‹stop›, ‹step› may be of type (big)int
--   - ‹start›, ‹stop› of type timestamp, ‹step› of type interval
--
-- Variants:
-- - generate_series(‹start›,‹stop›)      default ‹step› is 1
-- - generate_series(‹stop›)              default ‹start› is 0
-- - range(‹start›,‹stop›,‹step›)         ‹stop› is exclusive (never generated)
-- - range(‹start›,‹stop›)                (see above)
-- - range(‹stop›)                        (see above)
--
-- Also see https://duckdb.org/docs/stable/sql/functions/list.html#range-functions

-- 1, 4, 7 (,10)
FROM generate_series(1,10,3);
FROM range(1,10,3);


-- 5, 4, ..., 0, ..., -4, -5
SELECT *
FROM generate_series(5,-5,-1);

-- today() of type timestamp date of today @ 00:00
SELECT *
FROM   generate_series(today(), today() + '1 day' :: interval, '30 minutes' :: interval);

-- 0.0, 0.1, ..., 1.0
SELECT generate_series * 0.1
FROM   generate_series(0,10);

------------------------------------------------------------------------

-- The generated column name "generate_series" (or "range") is rather unwieldy.
-- But SQL can rename the columns of any table using row and column aliases
-- in the FROM clause.

-- SQL syntax:
--
-- Iterate over the rows of table ‹t›.  Rename the (first n) columns of ‹t›
-- into ‹c₁›, ‹c₂›, ..., ‹cₙ›.
--
--   FROM ‹t› AS ‹v›(‹c₁›,‹c₂›,...,‹cₙ›)
--
-- (Also: the rows of ‹t› are bound to row variable ‹v›.  The columns of ‹t› may
-- be accessed using dot syntax ‹v›.‹c₁›, ‹v›.‹c₂›, ..., ‹v›.‹cₙ›. This will
-- become important when SQL queries become more complex and access more than
-- one table.)

SELECT *
FROM   range(0,10) AS r(n);

SELECT i * 0.1 AS tenths
FROM   generate_series(0,10) AS _(i);  -- row variable _: don't care about its name


------------------------------------------------------------------------

-- Back to our experiments with lightweight compression.

-- Peek over DuckDB's shoulder while it analyzes column data to
-- select proper compression schemes.  Log entries are collected
-- in table duckdb_logs:
SET logging_level = 'info';
SET enable_logging = true;


-- Generate and insert 1½ row groups (180K) of compressible values
INSERT INTO t(const, rle, bitpack, "for", dict, fsst, alp)
  SELECT 42                AS const,
         (i / 1000) :: int AS rle,        -- or: i // 1000
         i % 10            AS bitpack,
         100000000000000000000000 + (random() * 10) :: int AS "for",
         ['clouds','sun','rain','snow','storm'][1+i%5] AS dict,
         hex(i)           AS fsst,
         i / 1000000      AS alp
  FROM   generate_series(1, 120 * 1024 + 60 * 1024) AS _(i);  -- 1½ row groups

-- Stop logging DuckDB's internal operations
SET enable_logging = false;

-- Get an impression of generated data:
FROM  t
ORDER BY rle DESC
LIMIT 20;

-- DuckDB analyzes data to choose compression method
-- one FinalAnalyze(): ‹column size in bytes› message per row group
--
-- NB.
-- - t.0 refers to column "const", t.6 refers to column "alp"
-- - column "const" uses a mere of 12 + 6 bytes(!) for 180K values (in chunk 0 + chunk 1)
-- - column "rle" uses 744 + 372 bytes only
-- - columns "bitpack", "for", "dict" use < 1 byte per row
SELECT timestamp, type, message
FROM   duckdb_logs
WHERE  message LIKE 'FinalAnalyze%'
AND    message NOT LIKE '%VALIDITY%';

-- Built-in table function pragma_storage_info('‹t›')  reports details
-- about DuckDB's internal storage for the table named ‹t›.
--
-- NB.
-- - compression: chosen compression scheme
-- - count: # of rows in this row group (and column segment)
-- - stats: basic distribution statistics for column values
SELECT row_group_id, column_name, segment_type,
       count, compression, stats, segment_info
FROM   pragma_storage_info('t')
WHERE  segment_type <> 'VALIDITY';


-- How large is the resulting compressed on-disk database?
FROM pragma_database_size();

-- When DuckDB scans the columns, it decompresses the data and the
-- plan downstream processes decompressed data.
--
-- In the following query, the SEQ_SCAN table scan of table t indicates
-- a result_set_size of 737280 bytes = 4 bytes (int) × 184320 (180K rows),
-- decompressed from the 744 + 372 bytes stored in column "rle".
EXPLAIN (ANALYZE, FORMAT json)
SELECT SUM(rle)
FROM   t;

------------------------------------------------------------------------

-- Attach a second database, but force DuckDB's compression off.
-- How much larger will the database be?

ATTACH 'uncompressed.db';
USE uncompressed;

-- Force no compression in database uncompressed
PRAGMA force_compression = 'Uncompressed';

-- Copy table t from compressed to uncompressed database
COPY FROM DATABASE compressed TO uncompressed;

SHOW ALL TABLES;

-- Report size of all attached databases
-- (in my experiments, the size of database uncompressed was
--  about 6.8 times larger)
FROM pragma_database_size();

-- Check the size of the associated on-disk files
.shell ls -lh *compressed.db

-- Back to DuckDB's default compression schemes
RESET force_compression;

------------------------------------------------------------------------

-- Measure the effect of compression on a sizable table (lineitem of
-- the TPC-H benchmark, scale factor sf = 1).  How compressible are
-- TPC-H data?

-- See 022-row-groups.sql for the tpch extension
INSTALL tpch;
LOAD tpch;

-- Create a compressed on-disk persistent instance
-- of TPC-H at scale factor sf = 1...
ATTACH 'tpch.db';
USE tpch;

CALL dbgen(sf = 1);

-- ... and check the resulting DB size (about 250 MB)
FROM pragma_database_size();

-- Repeat this experiment with an uncompressed instance of TPC-H

-- Get rid of the compressed database tpch, also on disk
USE memory;
DETACH tpch;
.shell rm tpch.db

-- Create a compressed on-disk persistent instance
-- of TPC-H at scale factor sf = 1...
ATTACH 'tpch.db';
USE tpch;

-- Force no compression in default database
PRAGMA force_compression = 'Uncompressed';

-- Generate TPC-H instance at scale factor sf = 1 and check its size
-- (> 1 GB)
CALL dbgen(sf = 1);

FROM pragma_database_size();

RESET force_compression;

-- Get rid of this bloated TPC-H instance
USE memory;
DETACH tpch;
.shell rm tpch.db
