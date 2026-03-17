-- Subqueries in SQL
--
-- Here: scalar subqueries, not correlated (we will soon clarify what
-- "correlation" is all about).

-- Recreate the vehicles/peeps sample tables
CREATE OR REPLACE TABLE peeps (
  pid    int PRIMARY KEY,        -- person (or peep) ID
  pic    text           ,        -- "portrait"
  name   text           ,
  born   int CHECK (born > 1900) -- year of birth
);

INSERT INTO peeps(pid, pic, name, born) VALUES
  (1, '󱁷', 'Cleo', 2013),
  (2, '󰮖', 'Bert', 1968),
  (3, '󱁘', 'Drew', NULL),
  (4, '󱁶', 'Alex', 2002);

CREATE OR REPLACE TABLE vehicles (
  vehicle   text    PRIMARY KEY,
  kind      text    NOT NULL   ,
  seats     int                ,
  "wheels?" boolean            ,
  pid       int REFERENCES peeps(pid)
);

INSERT INTO vehicles(vehicle, kind, seats, "wheels?", pid) VALUES
  ('󰞫', 'car',      5, true,  4),
  ('󱔭', 'SUV',      3, true,  4),
  ('󰞞', 'bus',     42, true,  NULL),
  ('󰟺', 'bus',      7, true,  NULL),
  ('󰍼', 'bike',     1, true,  2),
  ('󰴺', 'tank',  NULL, false, 3),
  ('󰞧', 'cabrio',   2, true,  4);

FROM vehicles;
FROM peeps;

-----------------------------------------------------------------------
-- A scalar subquery in parentheses (q) needs to return a
-- single-column table with at most one row.  SQL will
-- interpret the value of subquery q as the scalar: (q) ≡ x
--
-- ┌─────┐
-- ├─────┤
-- │  x  │  ≡  x
-- └─────┘

-- All larger vehicles (whose seating capacity exceeds the median)
FROM   vehicles AS v
WHERE  v.seats > (SELECT median(v1.seats)  -- ┐ subquery
                  FROM   vehicles AS v1);  -- ┘ in (...)

-- The scope of row variable v1 is the subquery, v1 is unknown
-- outside the subquery. (⚠ Will fail.)
SELECT v.*, v1.*                           -- v1 unknown
FROM   vehicles AS v
WHERE  v.seats > (SELECT median(v1.seats)  -- v1 in scope
                  FROM   vehicles AS v1);



-- Who are the bike riders?
FROM  peeps AS p
WHERE p.pid = (SELECT v.pid              -- ┐
               FROM   vehicles AS v      -- │ subquery
               WHERE  v.kind = 'bike');  -- ┘ (returns one row)

-- If a scalar subquery q returns no row: (q) ≡ NULL.
-- If a scalar subquery returns more than one row: error at run time.

-- Who are the bus drivers?  (⚠ Will fail.)
FROM  peeps AS p
WHERE p.pid = (SELECT v.pid              -- ┐
               FROM   vehicles AS v      -- │ subquery
               WHERE  v.kind = 'bus');   -- ┘ (returns two rows :-/)

-- Formulate scalar subqueries such that it is guaranteed that they
-- return no more than one row (e.g., equality selecton on a key,
-- aggregates).  Run time errors are hard to debug and potentially
-- waste computation time.

-- DuckDB augments the query plan to check that scalar subqueries
-- return a single row at query run time:
EXPLAIN
FROM  peeps AS p
WHERE p.pid = (SELECT v.pid
               FROM   vehicles AS v
               WHERE  v.kind = 'bike');

--  ┌─────────────┴─────────────┐
--  │         PROJECTION        │
--  │    ────────────────────   │
--  │ CASE  WHEN ((#1 > 1)) THEN│
--  │  (error('More than one row│
--  │   returned by a subquery  │
--  │   used as an expression - │
--  │    scalar subqueries can  │
--  │  only return a single row.│
--  │          Use "SET         │
--  │ scalar_subquery_error_on_m│
--  │   ultiple_rows=false" to  │
--  │     revert to previous    │
--  │   behavior of returning a │
--  │ random row.')) ELSE #0 END│
--  │                           │
--  │          ~1 Rows          │
--  └─────────────┬─────────────┘


-- Here is variant of the query above that does not trip,
-- regardless of the vehicle kind we look for.
--
-- Who are the bike riders?
FROM peeps AS p SEMI JOIN vehicles AS v
     ON (p.pid = v.pid AND v.kind = 'bike');

-----------------------------------------------------------------------
-- A scalar subquery q is a regular SQL query.  However, its
-- interpretation changes if it is used as (q) in a context
-- where a scalar is expected.

--             compute in isolation
--                 ┌──────────┐
WITH bike(icon) AS MATERIALIZED (
  SELECT v.vehicle
  FROM   vehicles AS v
  WHERE  v.kind = 'bike'
)
FROM bike;           -- a regular single-cell table

WITH bike(icon) AS MATERIALIZED (
  SELECT v.vehicle
  FROM   vehicles AS v
  WHERE  v.kind = 'bike'
)
SELECT ['I', 'like', 'riding', 'my', (FROM bike), '!'] AS you_bet;
--                                   ^^^^^^^^^^^
--                                a scalar (text value)
--                                    is expected
