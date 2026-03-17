-- SQL's GROUP BY collects all rows that agree in all grouping criteria
-- in one group (or: subtable).
--
-- The SELECT clause  is evaluated once for each group and yields
-- one row per group.

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

-- The SELECT clause is evaluated once per group:
-- - use expressions that are constant within each group (e.g.,
--   the grouping criterion), or
-- - use aggregate functions to compute one aggregate value for the group

SELECT v.seats < 5 AS "small vehicle?",  -- grouping criterion
       count(*) AS cardinality,          -- aggregate
       max(v.seats) AS capacity,         -- aggregate
       list(v.pid) AS drivers            -- aggregate
FROM   vehicles AS v
GROUP BY v.seats < 5;                    -- grouping criterion


-- After aggregation, each group (three overall) is represented by one row:
SELECT count(*) AS groups
FROM   (SELECT v.seats < 5 AS "small vehicle?",
               count(*) AS cardinality,
               max(v.seats) AS capacity,
               list(v.pid) AS drivers
        FROM   vehicles AS v
        GROUP BY v.seats < 5);

-- ⚠️ This will fail (in SQL, aggregation after grouping is mandatory):
FROM   vehicles AS v
GROUP BY v.seats < 5;


-- If you must preserve the individual rows in a group (YOU PROBABLY WON'T)
-- collect rows in a list:
SELECT v.seats < 5 AS criterion,
       count(*) AS cardinalty,
       list(v) AS group -- list-representation of the group's row (⚠️ may be HUGE)
FROM   vehicles AS  v
GROUP BY v.seats < 5;
