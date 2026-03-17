-- Correlated subqueries in SQL
--
-- Correlated subqueries contain free row variables that are
-- bound (only) in the outer/enclosing/main query.
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

-- Query Q: Pair vehicles with their driver (if any)
--
-- Quiz: What is the result for vehicles without a driver (like the busses)?
--
SELECT v.*,
       (SELECT p.name                      -- ┐ subquery in (...),
        FROM   peeps AS p                  -- │ refers to v: correlated
        WHERE  p.pid = v.pid) AS driver    -- ┘
FROM   vehicles AS v;


-- Subqueries can often lead to readable/intuitive query formulation.
-- *** Query equivalent to Q without subquery:
-- ⚠️ Need a LEFT OUTER JOIN to keep vehicles without a driver:
SELECT v.*, p.name AS driver
FROM   vehicles AS v NATURAL LEFT OUTER JOIN peeps AS p;


-- Correlated subqueries CANNOT be evaluated in isolation due to
-- free row variables.  This is bound to fail:
--
--                compute in isolation
--                    ┌──────────┐
WITH drivers(name) AS MATERIALIZED (
  SELECT p.name
  FROM   peeps AS p
  WHERE  p.pid = v.pid   -- uh oh, free row variable v
)
SELECT v.*, (FROM drivers)
FROM   vehicles AS v;


-----------------------------------------------------------------------
-- All peeps along with the list of vehicles they can drive
-- (the subquery implements a function int -> text[])
--
-- Quiz: What is the result for peeps who cannot drive (like Cleo)?
SELECT p.pid, p.pic,
       (SELECT list(v.vehicle)
        FROM   vehicles AS v
        WHERE  v.pid = p.pid) AS can_drive
FROM   peeps AS p;


-----------------------------------------------------------------------
-- Bikers are those peeps who only can drive one-seated vehicles
-- (correlated subquery in the WHERE clause)
--
-- Quiz: What is the result for peeps who cannot drive (like Cleo)?
SELECT p.pic, p.name AS biker
FROM   peeps AS p
WHERE  (SELECT max(v.seats)          --  ┐ subquery in (...),
        FROM   vehicles AS v         --  │ refers to p: correlated
        WHERE  v.pid = p.pid)        --  ┘
        = 1;

-- (Re Quiz: Recall the behavior of operations over NULL)
SELECT NULL = 1;

SELECT 'Peek-a-boo!' AS "do you see me?"
WHERE  NULL = 1;
