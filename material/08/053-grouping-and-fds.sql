-- In a GROUP BY query, it is OK to add non-aggregated expressions
-- to the SELECT and GROUP BY clauses, if those expressions do not
-- affect the forming of groups.


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

-- What's the maximum number of peeps each driver can give a lift?
SELECT p.pid AS driver,
       max(v.seats) - 1 AS "can lift"
FROM vehicles AS v NATURAL JOIN peeps AS p
GROUP BY p.pid;


-- INCLUDE MORE COLUMNS (from table peeps) to render the result
-- comprehensible:
-- 1. Add those columns to the GROUP by clause.
--    (⚠️ Q*: Will this affect the forming of groups?)
-- 2. Add columns to the SELECT clause.
--                          added
--                      ┌───────────┐
SELECT p.pid AS driver, p.pic, p.name,
       max(v.seats) - 1 AS "can lift"
FROM vehicles AS v NATURAL JOIN peeps AS p
GROUP BY p.pid, p.pic, p.name;
--              └────────────┘
--                  added


-- Answer to Q*: No!
-- In the join result, two rows that agree on column pid also agree on
-- columns pic, name, born.  Let us use symbol -> to indicate this:
--
--   pid -> pic   ┐
--   pid -> name  ├  pid -> pic name born
--   pid -> born  ┘
FROM vehicles NATURAL JOIN peeps
ORDER BY pid;
