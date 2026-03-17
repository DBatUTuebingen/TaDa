-- 001-create-table.sql

-- A note on fonts:
--
-- In some of our sample tables we are using Unicode character
-- symbols (e.g., 󱔭󰞞󰟺󰍼󰴺󰞧) to depict vehicles and other objects.
-- These symbols are NOT essential and you could easily replace the
-- symbol for a car by the text string 'car' in these tables, for example.
-- If you do want to see these symbols on your system, however, simply
-- install and use a font containing the required characters.  You can
-- find a variety of such free fonts on the Web at
--
--              https://www.nerdfonts.com/font-downloads


-- SQL syntax:

-- In SQL, text after a double dash is a comment.

/* Multi-line comments
   are enclosed in slash-star and star-slash.
*/

-- SQL keywords and identifiers are case-insensitive: CREATE ≡ create ≡ Create.
-- (But DuckDB preserves the case of identifiers, e.g., in table/column names.)
-- Idiomatic SQL uses UPPERCASE keywords and lowercase identifiers.

-- SQL statements may contain arbitrary whitespace (e.g., tabs, newlines)
-- and are terminated by a semicolon (;).

------------------------------------------------------------------------

-- Create table verhicles with provided schema and an empty instance
-- (no rows yet).
-- - Column order is relevant: column "vehicle" will be the first
-- - Columns may carry NULL values unless explicitly forbidden via NOT NULL
CREATE OR REPLACE TABLE vehicles (
  vehicle   text    NOT NULL,  -- no NULL values allowed in column vehicle
  kind      text    NOT NULL,
  seats     int             ,  -- NULL values OK in column seats
  "wheels?" boolean NOT NULL   -- enclose column names in "..." if it contains
);                             -- non-alphanumeric characters or SQL tokens

/* CREATE OR REPLACE t (...) will create table t if non-existent,
   otherwise t will be deleted and re-created.  (There may be only
   one table named t in a database at a time.)

   An alternative, frequently used SQL idiom:

   DROP TABLE IF EXISTS t;  -- delete table t if it exists
   CREATE TABLE t (...);    -- create table t

   Also see https://duckdb.org/docs/stable/sql/statements/create_table.html
*/

-- Show table vehicles with its schema information
-- (Many SQL type names are aliased, e.g, text ≡ varchar [varying characater],
--  see https://duckdb.org/docs/sql/data_types/overview.html)
DESCRIBE vehicles;

-- List the current table state (0 rows)
FROM vehicles;

-- Populate table t (place rows in its instance, change state of table t).
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰞫', 'car', 5, true);  -- row to be inserted, respects table schema
--   |     |    |    |
-- vehicle |  seats  |
--       kind      wheels?
--└─────────┘
-- text values (strings) are enclosed
-- in '...' (single quotes)

-- List the current table state (1 row)
FROM vehicles;

-- Add more row values to t's instance
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),   -- column seats admits NULL values
  ('󰞧', 'cabrio',   2, true);

-- List the current table state (7 rows)
FROM vehicles;


-- ⚠️ This violates a constraint and will be rejected
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰫂', NULL, 8, false);   -- a strange kind of vehicle...
--         |
--   forbidden by the NOT NULL constraint on column kind

-- Priortable state is preserved
FROM vehicles;

-- Other SQL constraints on columns
-- (see https://duckdb.org/docs/sql/constraints.html):
--
-- - PRIMARY KEY                    values in column must be unique and NOT NULL
-- - UNIQUE                         values in column must be unique
-- - CHECK (‹predicate›)            values must satisfy predicate
-- - REFERENCES ‹table›(‹column›)   values must reference a row in a
--                                    different table
--
-- We discuss some of these constraints in detail later.

------------------------------------------------------------------------

-- Constraint playground
DROP TABLE IF EXISTS vehicles;
CREATE TABLE vehicles (
  vehicle   text    NOT NULL UNIQUE,
  kind      text    NOT NULL DEFAULT 'unknown',
  seats     int     CHECK (seats BETWEEN 1 AND 60), -- seats >= 1 AND seats <= 60
  "wheels?" boolean DEFAULT true
);

INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰞫', 'car',      5, true),
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),
  ('󰞧', 'cabrio',   2, true);

DESCRIBE vehicles;  -- short: SHOW vehicles;
FROM vehicles;


-- ⚠️ Attempt to add rows that violate the above constraints
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󱔭', 'truck', 3, true);

INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰿧', 'train', 200, true);

-- Omitting columns is OK if default values are defined
-- (missing: kind, wheels?)
INSERT INTO vehicles(vehicle, seats) VALUES
  ('󰔽', 3);

FROM vehicles;  -- NB. default kind/wheels? values in row for 󰔽
