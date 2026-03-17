-- Table-valued subqueries in SQL

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

-- Drivers along with all vehicles they can drive
-- (use of LATERAL is optional in DuckDB)
--
-- Quiz: What about peeps who cannot drive (like Cleo)?
SELECT  p.pid, p.pic, v1.vehicle AS can_drive
FROM    peeps AS p,
        (FROM   vehicles AS v           -- ┐ correlated table-valued subquery,
         WHERE  v.pid = p.pid) AS v1    -- ┘ acts like a int -> table(of vehicles)
ORDER BY p.pid;                         --   function


-- Equivalent variant: uses JOIN, no subquery
SELECT  p.pid, p.pic, v1.vehicle AS can_drive
FROM    peeps AS p NATURAL JOIN vehicles AS v1
ORDER BY p.pid;


/*

If you use EXPLAIN on both queries, you will find that
decorrelation turns the subquery variant into the JOIN variant:

┌─────────────┴─────────────┐
│         HASH_JOIN         │
│    ────────────────────   │
│      Join Type: INNER     │
│                           │
│        Conditions:        ├──────────────┐
│  pid IS NOT DISTINCT FROM │              │
│             pid           │              │
│                           │              │
│          ~1 Rows          │              │
└─────────────┬─────────────┘              │
┌─────────────┴─────────────┐┌─────────────┴─────────────┐
│         SEQ_SCAN          ││         PROJECTION        │
│    ────────────────────   ││    ────────────────────   │
│        Table: peeps       ││          vehicle          │
│   Type: Sequential Scan   ││            pid            │
│                           ││                           │
│        Projections:       ││                           │
│            pid            ││                           │
│            pic            ││                           │
│                           ││                           │
│          ~4 Rows          ││          ~1 Rows          │
└───────────────────────────┘└─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │           FILTER          │
                             │    ────────────────────   │
                             │     (pid IS NOT NULL)     │
                             │                           │
                             │          ~1 Rows          │
                             └─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │         SEQ_SCAN          │
                             │    ────────────────────   │
                             │      Table: vehicles      │
                             │   Type: Sequential Scan   │
                             │                           │
                             │        Projections:       │
                             │            pid            │
                             │          vehicle          │
                             │                           │
                             │          ~7 Rows          │
                             └───────────────────────────┘
*/


-----------------------------------------------------------------------
-- Recall from 038-decorrelation.sql:
--
-- Manually decorrelated variant of query Q
-- (pair vehicles with their driver).
--
-- 1. Below: Use a CTE to compute the intermediate result tables
--    arguments(pid) and lookup_table(name, pid):
WITH
-- DISTINCT arguments for function q(pid)
arguments(pid) AS (
  SELECT DISTINCT v.pid
  FROM   vehicles AS v
),
-- Compute q(pid) for all DISTINCT arguments, create lookup table pid -> name
lookup_table(name, pid) AS (
  SELECT p.name, p.pid
  FROM   peeps AS p
           NATURAL SEMI JOIN
         arguments AS a
)
-- Perform lookups for all vehicle.pid values
-- (retain vehicles without join partner with a NULL driver)
SELECT v.*, q.name AS driver
FROM   vehicles AS v
         NATURAL LEFT OUTER JOIN
       lookup_table AS q;


-- 2. Now: Place the bodies of the CTE in uncorrelated table-valued
--    subqueries to compute the intermediate result tables
--    arguments(pid) and lookup_table(name, pid) "in place".
--
-- NB. Subqueries can nest.
SELECT v.*, q.name AS driver
FROM   vehicles AS v
         NATURAL LEFT OUTER JOIN
       (SELECT p.name, p.pid                 -- ────────────┐
        FROM   peeps AS p                    --             │ lookup_table
                 NATURAL SEMI JOIN           --             │
               (SELECT DISTINCT v.pid        -- ┐ arguments │
                FROM   vehicles AS v) AS a   -- ┘           │
       ) AS q;                               -- ────────────┘


-----------------------------------------------------------------------
-- Subquery playground

-- SQL's interpretation of a subquery depends on the usage context.
--
-- 1. Table-valued context (FROM clause):
                          FROM (SELECT v.vehicle
                                FROM   vehicles AS v
                                WHERE  v.kind = 'bike') AS v(bicycle);
--                             └──────────┬──────────┘
--                                        │ identical
-- 2. Scalar context:          ┌──────────┴──────────┐
SELECT 'I want to ride my ' || (SELECT v.vehicle
                                FROM   vehicles AS v
                                WHERE  v.kind = 'bike') AS lyrics;
