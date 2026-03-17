-- In SQL, the FROM clause binds row variables.

-- Create and populate our well-known sample table
CREATE OR REPLACE TABLE vehicles (
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

-- Since |vehicles| = 7, the following FROM clause will iteratively
-- bind row variable v to 7 rows.  The type of v is determined by
-- the schema of table vehicles:
--
--  v :: row(vehicle text, kind text, seats int, "wheels?" boolean)
SELECT v
FROM   vehicles AS v;

-- SQL Syntax:
--
-- To construct a row value (or struct) of type row(c₁ τ₁, ..., cₙ τₙ),
-- use {} braces:
--
--    {c₁:e₁, …, cₙ:eₙ}     (where eᵢ is an expression with type τᵢ).

-- A row value/struct of type row(num int, "even?":boolean, "prime?":boolean).
SELECT {num:42, "even?":true, "prime?":false};

-- Column access uses dot (.) notation:
SELECT {num:42, "even?":true, "prime?":false}."even?";
--      ↓          ↓                         ↑
SELECT v.vehicle, v.kind
FROM   vehicles AS v;

-- SQL Syntax:
--
-- If v is a row variable of type row(c₁ τ₁, ..., cₙ τₙ), then v.*
-- ("v star") abbreviates the n comma-separated column accesses
--
--    v.c₁, ..., v.cₙ
--
-- DuckDB implements a number of non-standard(!) SQL convenience
-- features that manipulate such "star lists" of column accesses
-- (to allow column renaming, column exclusion, etc.).
-- See https://duckdb.org/docs/stable/sql/expressions/star

SELECT v.* EXCLUDE (seats)  --  ≡ v.vehicle, v.kind, v."wheels?"
FROM   vehicles AS v;


-- ⚠️ Note the difference between the following two queries:
--
-- 1. Result has SINGLE COLUMN
--    of type row(vehicle:text, kind:text, seats:int, "wheels"?:boolean):
SELECT v
FROM   vehicles AS v;

-- 2. Result has FOUR COLUMNS vehicle, kind, seats, "wheels?"
--    of scalar types text, text, int, boolean:
SELECT v.*
FROM   vehicles AS v;


-- SQL Syntax:
--
-- 1. The AS keyword is optional (FROM vehicles v).
-- 2. The row variable name is optional. The row variable then
--    equals the table name:
--
--    FROM vehicles  ≡  FROM vehicles AS vehicles
--
-- 3. DuckDB permits the alternative syntax (most useful/readble in
--    multi-table queries):
--
--    FROM v: vehicles
