-- SQL's bag algebra

-- Recreate the well-known vehicles + peeps (drivers) tables.

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

------------------------------------------------------------------------

-- All unique icons (pictograms) used in the vehicles/peeps example.
-- (Note the arbitrary order in which rows are returned.  UNION or
-- UNION ALL do *not* implement "concatenation".)
--
SELECT v.vehicle AS icon    -- the lhs query determines the column name
FROM   vehicles AS v
  UNION
SELECT p.pic /* AS icon */
FROM   peeps AS p;

-- All vehicles with wheels that carry at least a dozen.
-- (QUIZ: Can you formulate this query without a bag operation?)
SELECT v.vehicle, v.kind
FROM   vehicles AS v
WHERE  v."wheels?"
  INTERSECT ALL
SELECT v.vehicle, v.kind
FROM   vehicles AS v
WHERE  v.seats >= 12;


-- This returns table peeps again. (Why?)
FROM  peeps AS p
WHERE p.name > 'Fred'
  UNION ALL
FROM  peeps AS p
WHERE p.name <= 'Fred'; -- ≡ NOT p.name > 'Fred'


-- This DOES NOT return table peeps again. (Why?)
FROM  peeps AS p
WHERE p.born > 2000
  UNION ALL
FROM  peeps AS p
WHERE NOT p.born > 2000;


-- The different vehicle kinds among our vehicles.
SELECT DISTINCT v.kind   -- can use SELECT ALL to explicity state
FROM   vehicles AS v;    -- that duplicate rows are OK/expected

------------------------------------------------------------------------
-- Playground: SQL's bag algebra does respect row multiplicities

CREATE OR REPLACE TABLE bag1 (row text);
CREATE OR REPLACE TABLE bag2 (row text);

INSERT INTO bag1(row) VALUES
  ('A'), ('A'), ('A'), ('B'), ('C');

INSERT INTO bag2(row) VALUES
  ('A'), ('B'), ('B'), ('D');

FROM bag1;
FROM bag2;

-- bag union
FROM bag1 UNION ALL FROM bag2;
FROM bag1 UNION     FROM bag2;      -- discard duplicates

-- Simulate UNION using UNION ALL/DISTINCT:
SELECT DISTINCT row
FROM   (FROM bag1 UNION ALL FROM bag2);



-- bag intersection
FROM bag1 INTERSECT ALL FROM bag2;
FROM bag1 INTERSECT     FROM bag2;  -- discard duplicates

-- Simulate INTERSECT using INTERSECT ALL/DISTINCT:
SELECT DISTINCT row
FROM   (FROM bag1 INTERSECT ALL FROM bag2);



-- bag difference
FROM bag1 EXCEPT ALL FROM bag2;
FROM bag1 EXCEPT     FROM bag2;     -- discard duplicates

-- Simulate EXCEPT using EXCEPT ALL AND DISTINCT × 2(!):
SELECT DISTINCT row FROM bag1
  EXCEPT ALL
SELECT DISTINCT row FROM bag2;
