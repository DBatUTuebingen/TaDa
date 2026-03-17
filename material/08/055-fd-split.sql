-- Vertical table splits along embedded FDs can improve table design:
--
-- 1. After the split, embedded FDs become key FDs and thus are
--    subject to constraint checking (PRIMARY KEY).
-- 2. Redundancy is removed.
-- 3. Application-level entities (concepts, objects) are represented
--    in their own tables.

-- Define & populate the sample table t found on the slides
--
-- There is an embedded FD x -> y but DuckDB cannot enforce/protect it
-- (there is no FUNCTIONAL DEPENDENCY constraint in SQL)
CREATE OR REPLACE TABLE t (
  k text PRIMARY KEY,
  x int,
  y int   -- y = f(x) = x * 10, but FD x -> y not enforced by DuckDB :-(
);

INSERT INTO t(k,x,y) VALUES
  ('k₁',1,10),
  ('k₂',2,20),
  ('k₃',1,10),
  ('k₄',1,10),
  ('k₅',2,20);

FROM t;

-----------------------------------------------------------------------

-- Violating FD x -> y in t is easy:
INSERT INTO t(k,x,y) VALUES
  ('k₆',2,-20);    -- f(2) = 20 ≠ -20

FROM t;

-- Ugh, I take that back...
DELETE FROM t WHERE k = 'k₆';

-- Updating function f needs to touch many rows
-- (and risks inconsistencies):
UPDATE t SET y = -10 WHERE k IN ('k₁','k₃');   -- oops, missed k₄

FROM t;

-- Roll back...
UPDATE t SET y = 10 WHERE k IN ('k₁','k₃');

-----------------------------------------------------------------------
-- To avoid these problems, split table t along FD x -> y

-- tˣ: Residual table after all columns functionally determined by
--     RHS x are removed from t
CREATE OR REPLACE TABLE tˣ (
  k text PRIMARY KEY,
  x int
);

INSERT INTO tˣ(k,x)
  SELECT t.k, t.x
  FROM   t;

-- tᶠ: Lookup table for function f
CREATE OR REPLACE TABLE tᶠ (
  x int PRIMARY KEY,   -- FD x -> y is now a key FD
  y int
);

INSERT INTO tᶠ(x,y)
  SELECT DISTINCT t.x, t.y  -- DISTINCT avoids redundancy
  FROM   t;

FROM tˣ;
FROM tᶠ;

-- Violating the FD x -> y is not possible anymore
-- ⚠️ This will fail
INSERT INTO tᶠ(x,y) VALUES
  (2,-20);


-----------------------------------------------------------------------
-- Exercise FD splitting on the sample trips table

-- Define & populate table trips as shown on the slides
CREATE OR REPLACE TABLE trips (
  trip    text,
  weekday text,
  driver  int,
  vehicle text,
  "from"  text,
  "to"    text,
  dist    decimal(4,1),
  via     text,
  "hop#"  int,
  PRIMARY KEY (trip, "hop#")
);

INSERT INTO
trips(trip, weekday, driver, vehicle, "from", "to", dist, via, "hop#") VALUES
  ('t₁', 'Mon', 4, '󱔭', 'Alton', 'Corby', 150, 'Alton', 1),
  ('t₁', 'Mon', 4, '󱔭', 'Alton', 'Corby', 150, 'Luton', 2),
  ('t₁', 'Mon', 4, '󱔭', 'Alton', 'Corby', 150, 'Corby', 3),
  ('t₂', 'Tue', 2, '󰍼', 'Derby', 'Eaton',  17, 'Derby', 1),
  ('t₂', 'Tue', 2, '󰍼', 'Derby', 'Eaton',  17, 'Eaton', 2),
  ('t₃', 'Wed', 2, '󰍼', 'Derby', 'Crich',  23, 'Derby', 1),
  ('t₃', 'Wed', 2, '󰍼', 'Derby', 'Crich',  23, 'Crich', 2),
  ('t₄', 'Thu', 4, '󱔭', 'Alton', 'Corby', 150, 'Alton', 1),
  ('t₄', 'Thu', 4, '󱔭', 'Alton', 'Corby', 150, 'Luton', 2),
  ('t₄', 'Thu', 4, '󱔭', 'Alton', 'Corby', 150, 'Corby', 3);

FROM trips
ORDER BY trip, "hop#";

-----------------------------------------------------------------------
-- In our road trip app, the following FDs shall hold:
--
--  from to -> dist         (UK road network)
--  weekday from -> driver  (weekly driver schedule and driver homebase)
--  driver -> vehicle       (drivers are licensed for one vehicle)
--
-- None of these FDs are key FDs => split table trips to avoid redundancy
-- and enable the DBMS to check the FD constraints.
--
-- Below, observe that it is quite straightforward to name the newly created
-- tables.  This is not a happy coincidence: FD splitting isolates/extracts
-- concepts that make sense in our app's real-world context.
--
-- (1) Split table trips along FD from to -> dist:

-- New table (distances in the UK road network)
CREATE OR REPLACE TABLE distances (
  "from"  text,
  "to"    text,
  dist    decimal(4,1),
  PRIMARY KEY ("from", "to"),
);

INSERT INTO distances("from", "to", dist)
  SELECT DISTINCT t."from", t."to", t.dist
  FROM   trips AS t;

-- Residual trips table
CREATE OR REPLACE TABLE trips AS
  SELECT t.trip, t.weekday, t.driver, t.vehicle, t."from", t."to", t.via, t."hop#"
  FROM   trips AS t;

FROM distances;
FROM trips;

-- (2) Split table trips along FD weekday from -> driver
--     (also move column vehicle into the new table since it is
--     transitively determined via FD driver -> vehicle):

-- New table (driver schedule and homebases)
CREATE OR REPLACE TABLE schedule (
  weekday text,
  "from"  text,
  driver  int,
  vehicle text,
  PRIMARY KEY (weekday, "from")
);

INSERT INTO schedule(weekday, "from", driver, vehicle)
  SELECT DISTINCT t.weekday, t."from", t.driver, t.vehicle
  FROM   trips AS t;

-- Residual trips table
CREATE OR REPLACE TABLE trips AS
  SELECT t.trip, t.weekday, t."from", t."to", t.via, t."hop#"
  FROM   trips AS t;

FROM distances;
FROM schedule;
FROM trips;

-- (3) Split new table schedule along FD driver -> vehicle:

-- New table (driver's assigned vehicle)
CREATE OR REPLACE TABLE licenses (
  driver  text PRIMARY KEY,
  vehicle text
);

INSERT INTO licenses(driver, vehicle)
  SELECT DISTINCT s.driver, s. vehicle
  FROM   schedule AS s;

-- Residual schedule table
CREATE OR REPLACE TABLE schedule AS
  SELECT s.weekday, s."from", s.driver
  FROM   schedule AS s;

FROM trips;
FROM distances;
FROM schedule;
FROM licenses;

-- DONE.
--
-- Final schemata:
--   trips(trip,weekday,from,to,via,hop#)
--   distances(from,to,dist)
--   schedule(weekday,from,driver)
--   licenses(driver,vehicle)
--
-- It may be advisable to recreate the database using these schemata
-- in order to properly establish foreign key constraints:
--
--           distances(from,to,dist)
--                         │
--                      ┌──┴──┐
--   trips(trip,weekday,from,to,via,hop#)
--              └─────┬────┘
--                    │
--    schedule(weekday,from,driver)
--                          └─┬──┘
--                            │
--                 licenses(driver,vehicle)
--
-- NB: All embedded FDs are key FDs now.
-- The resulting tables trips, distances, schedule, licenses are
-- said to be in Boyce-Codd Normal Form (BCNF).
--
-- (Recall Ray Boyce, co-inventor of SQL, and Ted Codd, father of the
-- relational data model.)


-----------------------------------------------------------------------
-- Beyond FDs
--
-- Tables in BCNF may exhibit further redundancies that are not explained
-- by the presence of FDs.
--
-- Example: In the residual table trips(trip,weekday,from,to,via,hop#)
-- every pair of start and destination comes with the same set of via
-- values. (The same holds for column hop#.)
-- Columns (from, to) thus determine an entire SET of rows (while FDs
-- determine columns within a single row).  This is a MULTI-VALUED
-- DEPENDENCY (MVD), in symbols: from to ->> via hop#.
--
-- Again, a vertical split can remove the associated redundancy.  A new
-- table routes will hold the sequence of intermediate stops determined
-- by (from, to):


-- New table (routes with sequence of intermediate stops)
CREATE OR REPLACE TABLE routes (
  "from" text,
  "to"   text,
  via    text,
  "hop#" int,
  PRIMARY KEY ("from", "to", "hop#"),
  -- CHECK ("hop#" <> 1 OR via = "from")  -- [can uncomment, see below]
);

INSERT INTO routes("from", "to", via, "hop#")
  SELECT DISTINCT t."from", t."to", t.via, t."hop#"
  FROM   trips AS t;

-- Residual trips table
CREATE OR REPLACE TABLE trips AS
  SELECT DISTINCT t.trip, t.weekday, t."from", t."to"
  FROM   trips AS t;


FROM trips;
FROM distances;
FROM schedule;
FROM licenses;
FROM routes ORDER BY "from", "to", "hop#";


-----------------------------------------------------------------------
-- Reconstructing the original table scheme and state

-- While the original (non-splitted) table trips gathered all
-- information relevant for the road trip app in once place,
-- that information is now spread over five(!) individual tables.
-- We have not lost anything, however.
--
-- The original trips table can be recovered by a four-fold natural
-- join (this is not a coincidence, see file 056-views.sql):

FROM trips     NATURAL JOIN
     distances NATURAL JOIN
     schedule  NATURAL JOIN
     licenses  NATURAL JOIN
     routes
ORDER BY trip, "hop#";



-----------------------------------------------------------------------
-- Constraints beyond FDs and MVDs
--
-- Define app-specific constraints in terms of CHECK constraints.
--
-- SQL syntax:
--
--   CREATE TABLE ‹t› (
--     ...
--     CHECK (‹p›)
--   )
--
-- Any row of table ‹t› must satisfy predicate ‹p› which may refer to
-- the columns of ‹t›.  Invalids rows are rejected on INSERT or UPDATE.
--
-- Example:
--
-- CREATE OR REPLACE TABLE routes (
--   "from" text,
--   "to"   text,
--   via    text,
--   "hop#" int,
--   PRIMARY KEY ("from", "to", "hop#"),
--   CHECK ("hop#" <> 1 OR via = "from")   -- "hop#" = 1 ⇒ via = "from"
-- );
