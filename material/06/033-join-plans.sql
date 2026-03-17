-- Join Plans

-- Recreate the well-known vehicles + peeps (drivers) tables.
-- Both are linked by a foreign key:
--
--   vehicles(vehicle, kind, seats, wheels?, pid -> peeps(pid))

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
  pid       int REFERENCES peeps(pid)  -- FOREIGN KEY referencing
                                       -- the primary key of table peeps
);

INSERT INTO vehicles(vehicle, kind, seats, "wheels?", pid) VALUES
  ('󰞫', 'car',      5, true,  4),    -- peep with ID 4 drives the car
  ('󱔭', 'SUV',      3, true,  4),
  ('󰞞', 'bus',     42, true,  NULL), -- no bus driver known
  ('󰟺', 'bus',      7, true,  NULL),
  ('󰍼', 'bike',     1, true,  2),
  ('󰴺', 'tank',  NULL, false, 3),
  ('󰞧', 'cabrio',   2, true,  4);

FROM vehicles;
FROM peeps;

------------------------------------------------------------------------
-- Join playground: use EXPLAIN to see which join plan (for an
-- inner join) is chosen by DuckDB's query optimizer

-- Query Q: vehicles with drivers
-- (inner join with left-hand side input vehicles, right-hand side: peeps)

FROM vehicles AS v NATURAL JOIN peeps AS p;

-- Plan for Q:
EXPLAIN
FROM vehicles AS v NATURAL JOIN peeps AS p;

-- ┌───────────────────────────┐
-- │         PROJECTION        │
-- │    ────────────────────   │
-- │                           │
-- │          ~7 Rows          │
-- └─────────────┬─────────────┘
-- ┌─────────────┴─────────────┐
-- │         HASH_JOIN ⚠      │  DuckDB chooses hash-based join algorithm
-- │    ────────────────────   │
-- │      Join Type: INNER     │
-- │   Conditions: pid = pid   ├──────────────┐
-- │                           │              │
-- │          ~7 Rows          │              │
-- └─────────────┬─────────────┘              │
-- ┌─────────────┴─────────────┐┌─────────────┴─────────────┐
-- │         SEQ_SCAN          ││         SEQ_SCAN          │
-- │    ────────────────────   ││    ────────────────────   │
-- │      Table: vehicles      ││        Table: peeps       │
-- │   Type: Sequential Scan   ││   Type: Sequential Scan   │
-- │                           ││                           │
-- │                           ││      Filters: pid>=2 ⚠   │ VERY clever, DuckDB!
-- │                           ││                           │ (join filter pushdown)
-- │          ~7 Rows          ││          ~4 Rows          │
-- └───────────────────────────┘└───────────────────────────┘
--               🡑                            🡑
--      lhs input: vehicles           rhs input: peeps

-- (Join filter pushdown use a range condition on column pid to
--  restrict the rhs input to the subset of values present in the
--  active domain [of column pid] in the lhs. Only that subset will
--  ever find a join partner.)

-- Query Q*: vehicles with drivers
-- (lhs/rhs inputs of join switched: inner join is commutative)

FROM peeps AS p NATURAL JOIN vehicles AS v;

-- Plan for Q*:

EXPLAIN
FROM peeps AS p NATURAL JOIN vehicles AS v;

-- ┌───────────────────────────┐
-- │         PROJECTION        │
-- │    ────────────────────   │
-- │                           │
-- │          ~7 Rows          │
-- └─────────────┬─────────────┘
-- ┌─────────────┴─────────────┐
-- │         HASH_JOIN         │
-- │    ────────────────────   │
-- │      Join Type: INNER     │
-- │   Conditions: pid = pid   ├──────────────┐
-- │                           │              │
-- │          ~7 Rows          │              │
-- └─────────────┬─────────────┘              │
-- ┌─────────────┴─────────────┐┌─────────────┴─────────────┐
-- │         SEQ_SCAN          ││         SEQ_SCAN          │
-- │    ────────────────────   ││    ────────────────────   │
-- │      Table: vehicles      ││        Table: peeps       │
-- │   Type: Sequential Scan   ││   Type: Sequential Scan   │
-- │                           ││                           │
-- │                           ││      Filters: pid>=2      │
-- │                           ││                           │
-- │          ~7 Rows          ││          ~4 Rows          │
-- └───────────────────────────┘└───────────────────────────┘
--               🡑                            🡑              ⚠ input order
--      lhs input: vehicles           rhs input: peeps          in Q and Q* identical

-- DuckDB always aim to place the smaller input table on the
-- rhs side of a hash-based join algorithm.  The rhs side is
-- used to build a temporary hash table.  The smaller this table,
-- the better.  Since inner join is commutative, DuckDB's
-- query optimizer is free to rearrange inputs at will.
--
-- The followup course DiDi ("Design and implementation of DBMS internals",
-- "Diving into DBMS implementation", "Dissecting the Duck's innards"?)
-- will explore this more thoroughly.
