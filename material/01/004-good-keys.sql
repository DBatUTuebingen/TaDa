-- 004-good-keys.sql

-- Create table verhicles, define column vehicle to be primary key
CREATE OR REPLACE TABLE vehicles (
  vehicle   text    PRIMARY KEY,  -- column vehicle uniquely identifies its row
  kind      text    NOT NULL   ,
  seats     int                ,
  "wheels?" boolean
);

DESCRIBE vehicles;

INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰞫', 'car',      5, true),
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),
  ('󰞧', 'cabrio',   2, true);

FROM vehicles;


-- A primary key uniquely identifies rows by its value: use equality
-- comparison with key values to deterministically point to rows.

-- SQL syntax:
--
-- Lists all rows in table ‹t› that satisfy predicate ‹p›:
--
-- FROM  ‹t›
-- WHERE ‹p›

FROM  vehicles
WHERE vehicle = '󰍼';  -- a single row will pass

FROM  vehicles
WHERE vehicle = '󰴺';

-- Column "kind" cannot be primary key since it carries duplicates:
FROM  vehicles
WHERE kind = 'bus';  -- more than one row passes

-- Column seats may appear like a suitable primary key in the current
-- table state ...
FROM  vehicles
WHERE seats = 1;  -- one row passes

-- ... but a future update may very likely introduce duplicate values
-- in column seats:
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󱂆', 'scooter', 1, true);
--                  ^

FROM  vehicles
WHERE seats = 1;  -- woops, now two rows pass

-- A primary key uniquely identifies rows in ANY table state.  Thus:
--
-- FROM  ‹t›
-- WHERE ‹key› = ‹value›
--
-- will ALWAYS return at most one row.

------------------------------------------------------------------------

-- If table ‹t› contains a composite key ‹c₁›,...,‹cₖ›, the predicates
-- in the WHERE clause are conjunctions:
--
--         ‹c₁› = ‹value₁› AND ... AND ‹cₖ› = ‹valueₖ›
--
-- The wider the key, the more complex the predicate, the more expensive
-- its evaluation.  Aim for narrow keys.

-- Example 1: kind, seats is a composite key for table vehicles (although
-- it is not the primary key).

FROM  vehicles
WHERE kind = 'bus' AND seats = 7;

-- Example 2: column vehicle already is a key for table vehicles.  Adding
-- more columns to a key preserves the key property but only adds
-- unwarranted complexity:

FROM  vehicles
WHERE vehicle = '󰞞' AND kind = 'bus';
--    └────────────┘└───────────────┘
--    key predicate    not needed to
--                  identify the 󰞞 row

------------------------------------------------------------------------

-- If the application domain yields no natural keys (or only
-- unwieldy/wide/inefficient keys), consider to add an artificial
-- extra key column (often called surrogate key).
--
-- Values in such columns are unique but otherwise have no meaning
-- in the application domain: optionally let the DBMS pick these
-- values automatically from an auto-incrementing sequence of integers.
--
-- SQL syntax:
--
-- CREATE SEQUENCE ‹s›  -- minimal value 1, maximal value ∞ (practice: bigint limits),
--                         start with 1, increment by 1, no cycling
-- CREATE SEQUENCE ‹s› START WITH ‹a›
-- CREATE SEQUENCE ‹s› START WITH ‹a› INCREMENT BY ‹i›
-- CREATE SEQUENCE ‹s› MINVALUE ‹m› MAXVALUE ‹M› START WITH ‹a› INCREMENT BY ‹i›
-- CREATE SEQUENCE ‹s› MINVALUE ‹m› MAXVALUE ‹M› START WITH ‹a› INCREMENT BY ‹i› CYCLE
--
-- Access next / current value in sequence ‹s› via nextval('‹s›') / currval('‹s›').

-- sequence: 10, 20, 30, ...
CREATE OR REPLACE SEQUENCE surrogates START WITH 10 INCREMENT BY 10;

SELECT nextval('surrogates');
SELECT nextval('surrogates');
SELECT currval('surrogates');
SELECT nextval('surrogates');


-- Re-create table verhicles, now add a surrogate key column id,
-- pick its values from sequence surrogates
CREATE OR REPLACE TABLE vehicles (
  id        int     PRIMARY KEY DEFAULT nextval('surrogates'),  -- surrogate key
  vehicle   text    NOT NULL,
  kind      text    NOT NULL,
  seats     int             ,
  "wheels?" boolean
);

DESCRIBE vehicles;

-- ⚠️ Insert rows but do NOT specify a value for column id (auto-generated)
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰞫', 'car',      5, true),
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),
  ('󰞧', 'cabrio',   2, true);

FROM vehicles;

FROM  vehicles
WHERE id = 80;   -- identifies the 󰍼 row


-- DuckDB specifics:
--
-- Access the current state of all sequences known to the DBMS using the
-- built-in function duckdb_sequences():

FROM duckdb_sequences();
