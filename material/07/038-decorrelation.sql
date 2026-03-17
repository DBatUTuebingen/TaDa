-- DuckDB's query optimizer decorrelates subqueries to avoid
-- a naive "nested loops" evaluation strategy
--
-- Here: scalar subqueries.

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
-- Recall Query Q: Pair vehicles with their driver (if any)

SELECT v.*,
       (SELECT p.name                      -- ┐ subquery q(pid),
        FROM   peeps AS p                  -- │ refers to v: correlated
        WHERE  p.pid = v.pid) AS driver    -- ┘
FROM   vehicles AS v;

-- Column vehicles.pid provides the arguments for the "function" q(pid) -> name.
-- Since the column contains duplicates, naive evaluation of q(pid) will
-- do repetivie work:
SELECT v.pid
FROM   vehicles AS v;

-- Goal: Collect the DISTINCT vehicles.pid argument and evaluate q(pid)
-- for those ONCE:
SELECT DISTINCT v.pid
FROM   vehicles AS v;


-- This is exactly what SUBQUERY DECORRELATION provides.  See the query
-- plan used by DuckDB to process query Q:

-- Show intermediate plans before the final optimized plan is chosen
PRAGMA explain_output = 'all';

-- Show plan(s) for query Q (see Unoptimized Logical Plan)
EXPLAIN
SELECT v.*,
       (SELECT p.name
        FROM   peeps AS p
        WHERE  p.pid = v.pid) AS driver
FROM   vehicles AS v;

/*
┌─────────────────────────────┐
│┌───────────────────────────┐│
││ Unoptimized Logical Plan  ││
│└───────────────────────────┘│
└─────────────────────────────┘
┌───────────────────────────┐
│         PROJECTION        │
│    ────────────────────   │
│        Expressions:       │
│          vehicle          │
│            kind           │
│           seats           │
│          wheels?          │
│            pid            │
│           driver          │
└─────────────┬─────────────┘
┌─────────────┴─────────────┐
│         DELIM_JOIN        │
│    ────────────────────   │
│     Join Type: SINGLE     │
│                           ├──────────────┐
│        Conditions:        │              │
│ (pid IS NOT DISTINCT FROM │              │
│            pid)           │              │
└─────────────┬─────────────┘              │
┌─────────────┴─────────────┐┌─────────────┴─────────────┐
│          SEQ_SCAN         ││         PROJECTION        │
│    ────────────────────   ││    ────────────────────   │
│      Table: vehicles      ││        Expressions:       │
│   Type: Sequential Scan   ││            name           │
│                           ││            pid            │
└───────────────────────────┘└─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │           FILTER          │
                             │    ────────────────────   │
                             │        Expressions:       │
                             │        (pid = pid)        │
                             └─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │       CROSS_PRODUCT       │
                             │    ────────────────────   ├──────────────┐
                             └─────────────┬─────────────┘              │
                             ┌─────────────┴─────────────┐┌─────────────┴─────────────┐
                             │          SEQ_SCAN         ││         DELIM_GET         │
                             │    ────────────────────   ││    ────────────────────   │
                             │        Table: peeps       ││                           │
                             │   Type: Sequential Scan   ││                           │
                             └───────────────────────────┘└───────────────────────────┘
*/


-- For demonstration purposes only: Translate this plan back into SQL.
-- - Query gets considerable longer/more complicated.
-- - Query requires careful treatment of NULL values.
EXPLAIN
WITH
-- DISTINCT arguments for function q(pid)
arguments(pid) AS (
  SELECT DISTINCT v.pid
  FROM   vehicles AS v
),
-- Compute q(pid) for all DISTINCT arguments, create lookup table pid -> name
lookup_table(name, pid) AS (
  SELECT p.name, p.pid
  FROM   peeps AS p NATURAL SEMI JOIN arguments AS a
)
-- Perform lookups for all vehicle.pid values
-- (retain vehicles without join partner with a NULL driver)
SELECT v.*, q.name AS driver
FROM   vehicles AS v NATURAL LEFT OUTER JOIN lookup_table AS q;

-- Can use the following alternative top-level queries
-- to observe the intermediate query results:
--
-- FROM arguments;
-- FROM lookup_table;

-----------------------------------------------------------------------

/*

The final optimized plan looks like this:

┌─────────────────────────────┐
│┌───────────────────────────┐│
││  Optimized Logical Plan   ││
│└───────────────────────────┘│
└─────────────────────────────┘
┌───────────────────────────┐
│         PROJECTION        │
│    ────────────────────   │
│        Expressions:       │
│          vehicle          │
│            kind           │
│           seats           │
│          wheels?          │
│            pid            │
│           driver          │
│                           │
│          ~7 Rows          │
└─────────────┬─────────────┘
┌─────────────┴─────────────┐
│      COMPARISON_JOIN      │
│    ────────────────────   │
│     Join Type: SINGLE     │
│                           │
│        Conditions:        ├──────────────┐
│ (pid IS NOT DISTINCT FROM │              │
│            pid)           │              │
│                           │              │
│          ~7 Rows          │              │
└─────────────┬─────────────┘              │
┌─────────────┴─────────────┐┌─────────────┴─────────────┐
│          SEQ_SCAN         ││         PROJECTION        │
│    ────────────────────   ││    ────────────────────   │
│      Table: vehicles      ││        Expressions:       │
│   Type: Sequential Scan   ││            name           │
│                           ││            pid            │
│                           ││                           │
│          ~7 Rows          ││          ~1 Rows          │
└───────────────────────────┘└─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │          SEQ_SCAN         │
                             │    ────────────────────   │
                             │        Table: peeps       │
                             │   Type: Sequential Scan   │
                             │                           │
                             │          ~4 Rows          │
                             └───────────────────────────┘
*/

-- Translate this plan back into SQL:
WITH
lookup_table(name, pid) AS (
  SELECT p.name, p.pid
  FROM   peeps AS p
)
SELECT v.*, t.name AS driver
FROM   vehicles AS v LEFT OUTER JOIN lookup_table t ON (v.pid = t.pid);

-- This essentially is the SQL query for Q without subquery
-- (see the query marked *** in 037-correlation.sql):
SELECT v.*, p.name AS driver
FROM   vehicles AS v NATURAL LEFT OUTER JOIN peeps AS p;
