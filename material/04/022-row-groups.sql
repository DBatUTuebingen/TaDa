-- On-disk, DuckDB stores tables in a column-by-column as opposed
-- to row-by-row fashion (columnar table storage).
--

CREATE OR REPLACE TABLE vehicles (
  vehicle   text    NOT NULL,  -- no NULL values allowed in column vehicle
  kind      text    NOT NULL,
  seats     int             ,  -- NULL values OK in column seats
  "wheels?" boolean            -- enclose column names in "..." if it contains
);

INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),   -- column seats admits NULL values
  ('󰞧', 'cabrio',   2, true);

FROM vehicles;

-- "Eat your own dog food" principle:
-- Expose the internals of the DBMS using the tabular data model
-- => can use SQL to explore the current state of the DBMS itself.
--
-- Built-in table function pragma_storage_info('‹table›')
-- allows to peek into DuckDB's table storage.
--
-- - row_group_id:           single row group 0 suffices for this tiny table
-- - column_name, column_id: storage is organized by column
-- - segment_type:           all cell values in a column share this type
-- - start, count:           information about the column chunk
-- - compression:            no compression has been applied to cell values
-- - stats:                  basic distribution statistics for cell values in chunk
-- - persistent:             this in an in-memory table, nothing is persisted
SELECT row_group_id,
       column_name, column_id,
       segment_type,
       start, count,
       compression,
       stats,
       persistent
FROM   pragma_storage_info('vehicles')
WHERE  segment_type <> 'VALIDITY';

------------------------------------------------------------------------

-- Now let's explore a large table: lineitem of TPC-H (scale factor sf = 1).

-- DuckDB specifics:
--
-- Install and load a DuckDB' extension to supply new built-in ,
-- functions, types, macros, ...:
--
--   INSTALL ‹extension›;   -- install extension for current default database
--   LOAD    ‹extension›;   -- dynamically load and activate extension
--
-- Also see https://duckdb.org/docs/stable/extensions/overview


-- Load DuckDB's tpch extension which can generate a TPC-H benchmark
-- instance of specified scale factor sf (instead of loading tables
-- from CSV files):
INSTALL tpch;
LOAD tpch;

-- Generate all 9 TPC-H tables at scale factor 1
-- (dbgen() is a function supplied by the tpch extension)
CALL dbgen(sf = 1);

SHOW ALL TABLES;

-- Check schema of table lineitem
DESCRIBE lineitem;

-- The 6+ million rows of table lineitem
-- will need many row groups (of 120K rows each)
SELECT count(*)                         AS rows,
       ceiling(count(*) / (120 * 1024)) AS row_groups
FROM   lineitem;

-- Storage of table lineitem:
-- - row_group_id: we require 49 row groups (⌈|lineitem| / 120K⌉)
-- - segment_id:   column chunks of 120k rows each are split into segments
--                 (not relevant for TaDa)
-- - compression:  nothing appears to be compressed (but see below)
SELECT row_group_id,
       column_name, column_id,
       segment_type, segment_id,
       start, count,
       compression,
       stats,
       persistent
FROM   pragma_storage_info('lineitem')
WHERE  segment_type <> 'VALIDITY'
ORDER BY row_group_id, segment_id;
