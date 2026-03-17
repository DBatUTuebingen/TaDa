-- 005-foreign-keys.sql

-- QUIZ: Before we create table peeps below, define a (wide) table
--       vehicles_and_drivers which represents both vehicles and
--       their drivers.
--
--       When you insert rows into the instance of vehicles_and_drivers
--       what do you observe?


CREATE OR REPLACE TABLE peeps (
  pid    int PRIMARY KEY,        -- person (or peep) ID
  pic    text           ,        -- "portrait"
  name   text           ,
  born   int CHECK (born > 1900) -- year of birth
);

INSERT INTO peeps(pid, pic, name, born) VALUES
  (1, '󱁷', 'Cleo', 2013),
  (2, '󰮖', 'Bert', 1968),
  (3, '󱁘', 'Drew', NULL), -- nobody knows when Drew was born
  (4, '󱁶', 'Alex', 2002);
-- 🡑
-- these (currently) are the valid peep IDs (e.g., ID 5 refers to no one)

FROM peeps;

-- SQL syntax:
--
-- Row order in a table is undefined.  For table output, can bring rows
-- into a defined order using SQL's ORDER BY clause.  The expressions
-- ‹expr₁›, ‹expr₂›, ... provide ordering criteria (primary first):
--
--  FROM ‹t›
--  ORDER BY ‹expr₁› [ASC|DESC], ‹expr₂› [ASC|DESC]
--
-- - Ascending (modifier ASC) order is the default.
-- - NULLs are sorted last unless modifier NULLS FIRST is specified.

FROM peeps
ORDER BY born DESC;  -- youngest first

FROM peeps
ORDER BY born DESC NULLS FIRST;

FROM peeps
ORDER BY name;  -- alphabetical order

FROM peeps
ORDER BY year(today()) - born < 18, born DESC;
--       └───────────────────────┘
--                  🡑
-- drivers first (false < true), youngest to oldest

-----------------------------------------------------------------------

-- Foreign Keys

-- The current contents of column pid in table peeps (short: peeps(pid))
-- defines the currently valid peep IDs.  If we want to refer to peeps
-- as drivers, we may pick IDs ONLY from these contents.

-- SQL Syntax:
--
-- Constraint REFERENCES ‹t›(‹c›) restricts the values of its column
-- to be from the contents of column ‹c› in foreign table ‹t›.  Since
-- we want  to uniquely identify drivers, ‹c› must be the PRIMARY KEY
-- or UNIQUE in foregin table ‹t›.

CREATE OR REPLACE TABLE vehicles (
  vehicle   text    PRIMARY KEY,
  kind      text    NOT NULL   ,
  seats     int                ,
  "wheels?" boolean            ,
  driver    int REFERENCES peeps(pid)  -- driver is a FOREIGN KEY referencing
                                       -- the primary key of table peeps
);

-- We now have established the schema
--   vehicles(vehicle, kind, seats, wheels?, driver -> peeps(pid)).

INSERT INTO vehicles(vehicle, kind, seats, "wheels?", driver) VALUES
  ('󰞫', 'car',      5, true,  4),    -- peep with ID 4 drives the car
  ('󱔭', 'SUV',      3, true,  4),
  ('󰞞', 'bus',     42, true,  NULL), -- no bus driver known
  ('󰟺', 'bus',      7, true,  NULL),
  ('󰍼', 'bike',     1, true,  2),
  ('󰴺', 'tank',  NULL, false, 3),
  ('󰞧', 'cabrio',   2, true,  4);
--                             🡑
--               ⊆ of foreign column peeps(pid) ✓

FROM vehicles
ORDER BY driver;

FROM peeps
WHERE pid = 4; -- who is the prolific driver with ID 4?


-- ⚠️ This will fail since it violates the foreign key constraint
--     (no peep with ID 5)
INSERT INTO vehicles(vehicle, kind, seats, "wheels?", driver) VALUES
  ('󱂆', 'scooter', 1, true, 5);
--                           🡑
--                      5 ∊̷ peeps(pid)

-- ⚠️ Cannot refer to peeps(name) to uniquely identify drivers: column
--    name is not guaranteed to remain unique in table peeps:
CREATE OR REPLACE TABLE vehicles (
  vehicle   text    PRIMARY KEY,
  kind      text    NOT NULL   ,
  seats     int                ,
  "wheels?" boolean            ,
  driver    int REFERENCES peeps(name)  -- not a valid foreign key
);

-- See also https://duckdb.org/docs/stable/sql/constraints.html#foreign-keys

-- DuckDB specifics:
--
-- DuckDB v1.2.1 does not support ON DELETE CASCADE / SET NULL yet.
ˇ
------------------------------------------------------------------------

-- Foreign Keys vs Keys
--
-- In general, foreign keys are NOT keys in their own table.  See column
-- driver in table vehicles: carries NULL values and duplicates.
--
-- But: a foreign key CAN BE candidate for a key in its own table.
--
-- QUIZ: In the vehicles/peeps application, what are the consequences for
--       the domain if foreign key driver also is a key candidate?
