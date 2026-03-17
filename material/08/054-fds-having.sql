-- FDs define functions in terms of embedded (materialized)
-- lookup tables.
--
-- (1) FD Quiz
--
-- FDs may be found in
--
-- (2) base tables or
-- (3) interemediate query results (e.g., joined tables).

-----------------------------------------------------------------------
-- (1) FD Quiz

--                 t
-- ┌───────┬───────┬───────┬───────┐
-- │   a   │   b   │   c   │   d   │
-- ├───────┼───────┼───────┼───────┤
-- │   1   │  10   │   a   │  0.0  │
-- │   2   │  20   │   b   │  1.0  │
-- │   3   │  20   │   b   │  2.0  │
-- │   4   │  40   │   c   │  2.0  │
-- │   4   │  40   │   c   │  2.0  │
-- │   5   │  50   │   b   │  0.0  │
-- └───────┴───────┴───────┴───────┘

-- Do the following FDs hold in table t?
--
-- • a -> b
-- • b -> c
-- • a -> c
--
-- • b -> a
-- • c -> b
--
-- • a b -> c
-- • b c -> a
-- • c d -> a b
--
-- • d -> d

CREATE OR REPLACE TABLE t (
  a int,
  b int,
  c text,
  d float
);

INSERT INTO t(a,b,c,d) VALUES
  (1, 10, 'a', 0.0),
  (2, 20, 'b', 1.0),
  (3, 20, 'b', 2.0),
  (4, 40, 'c', 2.0),
  (4, 40, 'c', 2.0),
  (5, 50, 'b', 0.0);

-----------------------------------------------------------------------

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
-- (2) FDs in base tables

-- Does FD kind -> seats hold in table vehicles?
SELECT DISTINCT 'FD kind -> seats violated' AS "FD violated?"
FROM   vehicles AS v
GROUP BY v.kind
HAVING count(DISTINCT v.seats) > 1;

-- Use NOT EXISTS to "invert" the test
SELECT 'FD c d -> a b holds in t' AS "FD holds?"
WHERE NOT EXISTS (
  SELECT 1
  FROM   t
  GROUP BY c, d
  HAVING count(DISTINCT a) > 1 OR count(DISTINCT b) > 1
);

-- A key defines a special, powerful FD that determines ALL columns
-- of the underlying table
SELECT DISTINCT 'pid is not a candidate key in peeps' AS "key violated?"
FROM   peeps AS p
GROUP BY p.pid
HAVING count(*) > 1;

SELECT DISTINCT 'kind is not a candidate key in vehicles' AS "key violated?"
FROM   vehicles AS v
GROUP BY v.kind
HAVING count(*) > 1;


-----------------------------------------------------------------------
-- (3) FDs in a join result

-- The result of this natural join embeds three lookup tables that
-- define three functions:
--   pid -> pic
--   pid -> name
--   pid -> born
FROM vehicles NATURAL JOIN peeps
ORDER BY pid;

-- FD pid -> name indeed behaves like a function f(pid) = name:
-- there is a *unique* name value for each pid
SELECT p.pid, count(DISTINCT p.name) AS "# names"
FROM   vehicles AS v NATURAL JOIN peeps AS p
GROUP BY p.pid;


-- Test 1: Does FD pid -> name hold in the join result?
SELECT DISTINCT 'FD pid -> name holds' AS "FD holds?"
WHERE NOT EXISTS (
  SELECT 1
  FROM   vehicles AS v NATURAL JOIN peeps AS p
  GROUP BY p.pid
  HAVING count(DISTINCT p.name) > 1
);

-- Here is the embedded lookup table defining function f(pid) = name:
SELECT DISTINCT p.pid, p.name
FROM   vehicles AS v NATURAL JOIN peeps AS p;


-- Test 2: Does FD pid -> kind hold? (No.)
SELECT DISTINCT 'FD pid -> kind violated' AS "FD violated?"
FROM   vehicles AS v NATURAL JOIN peeps AS p
GROUP BY p.pid
HAVING count(DISTINCT v.kind) > 1;

-- Indeed, this embedded table does NOT define a function f(pid) = kind:
SELECT DISTINCT p.pid, v.kind
FROM   vehicles AS v NATURAL JOIN peeps AS p;
