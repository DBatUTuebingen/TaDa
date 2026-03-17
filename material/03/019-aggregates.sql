-- Demonstrate the use of SQL aggregate functions.
--
-- For an overview of the aggregate functions built into DuckDB, see:
-- https://duckdb.org/docs/stable/sql/functions/aggregates

-- Re-create table verhicles
CREATE OR REPLACE TABLE vehicles (
  vehicle   text    PRIMARY KEY,
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

------------------------------------------------------------------------

-- Aggregate examples taken from the slide
SELECT count(vehicle),         -- # of non-NULL values in column vehicle
       arg_max(kind, seats),   -- vehicle kind with the most seats
       max(seats),             -- maximum number of seats
       bool_and("wheels?")     -- do all vehicles have wheels?
FROM   vehicles;

-- Aggregate function count() (and many others) ignore/skip NULL values
SELECT count(kind),             -- # of non-NULL values in column kind
       count(seats),            -- there is a NULL value in seats
       count(*) AS cardinality  -- count rows, no matter their content
FROM   vehicles;

-- If sum() and the like would not ignore NULLs
SELECT sum(seats),              -- ignores NULL values
       sum(seats) + NULL        -- "simulate" that NULL is added in
FROM   vehicles;

-- If we charter all busses and 80% of the seats are occupied...
SELECT sum(0.8 * seats) AS travel_group_size
FROM   vehicles
WHERE  kind = 'bus';

-- Appreciate the difference between max() and arg_max()
SELECT max(seats),
       arg_max('maximum capacity: ' || vehicle, seats),
       min(seats),
       arg_min('minimum capacity: ' || vehicle, seats),
FROM   vehicles;

-- Generalization: find the top/bottom N = 3 seats capacities
-- (and associated vehicles)
SELECT max(seats, 3),
       min(seats, 3),
       arg_max(kind, seats, 3) AS "top 3 largest vehicles",
       arg_min(kind, seats, 3) AS "top 3 smallest vehicles"
FROM   vehicles;

-- Form lists of vehicles
SELECT list(vehicle)                     AS "all vehicles",
       list(vehicle) FILTER ("wheels?")  AS "vehicle with wheels",
       list(vehicle ORDER BY seats DESC) AS "all vehicles, largest first"
                                              -- NB. sort order of the tank
FROM   vehicles;

-- Filter counts by different criteria
SELECT count(vehicle) FILTER ("wheels?")  AS "# vehicles with wheels",
       count(vehicle) FILTER (seats >= 5) AS "# of large vehicles"
FROM   vehicles;

-- More aggregate functions
SELECT arbitrary(vehicle),   -- any value in the column
       avg(seats),           -- average vehicle capacity
       median(seats),        -- median (1 2 3 | 5 7 42)
       mode(kind),           -- most frequent vehicle kind
       product(seats),       -- product() ignores NULL (like sum)
       bool_and("wheels?"),  -- all vehicles have wheels? (∀)
       bool_or("wheels?"),   -- does any vehicle have wheels? (∃),
       repeat(string_agg(vehicle, ' '), 2) AS "traffic jam"
FROM   vehicles;

------------------------------------------------------------------------

-- ⚠️ The following query mixes scalar expressions and
--     aggregate functions and thus will fail.

SELECT vehicle,             -- |vehicle| rows
       max(seats)           -- 1 row
FROM   vehicles;

-- Questionable "fix" (any vehicle will be chosen)
SELECT arbitrary(vehicle),  -- 1 row
       max(seats)           -- 1 row
FROM   vehicles;

------------------------------------------------------------------------

-- DuckDB's "friendly SQL" allows to reorder SQL clauses to match their
-- processing order.  ⚠️ This will be rejected by most other DBMSs.
--
-- 1. FROM:   read rows from table, then...
-- 2. SELECT: ...select which expressions to evaluate

FROM   vehicles                                    -- 1.
SELECT vehicle, kind, seats >= 5 AS "is large?";   -- 2.
