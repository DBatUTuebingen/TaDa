-- SQL's GROUP BY reduces the granularity from row-by-row
-- to group-by-group processing.


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


-- ⚠️ Will fail: DuckDB cannot deduce that v.seats >= 5 is constant within
--    each group (cannot even deduce this for NOT(v.seats < 5) ¯\_(ツ)_/¯).
SELECT v.seats >= 5 AS "large vehicle?",  -- should be OK (but fails)
       count(*) AS cardinality
FROM   vehicles AS  v
GROUP BY v.seats < 5;


-- Grouping criteria can refer to column names introduced
-- in the SELECT clause (makes sure that SELECT clause and
-- grouping criteria are identical):
SELECT v.seats >= 5 AS "large vehicle?",   -- OK: grouping criterion
       count(*) AS cardinality
FROM   vehicles AS  v
GROUP BY "large vehicle?";

-----------------------------------------------------------------------

-- Adding more criteria generally leads to more groups (finer granularity).
--
-- Original query (four groups):
SELECT v.pid AS driver,
       count(*) AS cardinality,
       string_agg(v.vehicle, ' ') AS vehicles
FROM   vehicles AS  v
GROUP BY v.pid;

-- Added grouping criterion v.seats < 5 (now yields five groups,
-- the group for v.pid = 4 is split into two true/false sub-groups):
SELECT v.pid AS driver,
       v.seats < 5 AS "small vehicle?",
       count(*) AS cardinality,
       string_agg(v.vehicle, ' ') AS vehicles
FROM   vehicles AS  v
GROUP BY v.pid, v.seats < 5;

-- The order of grouping criteria is immaterial
-- ("Which rows agree on v.pid and v.seats < 5" ≡ "Which rows agree on v.seats < 5 and v.pid?"):
SELECT v.pid AS driver,
       v.seats < 5 AS "small vehicle?",
       count(*) AS cardinality,
       string_agg(v.vehicle, ' ') AS vehicles
FROM   vehicles AS  v
GROUP BY v.pid, "small vehicle?";  -- ≡ GROUP BY "small vehicle?", v.pid

-----------------------------------------------------------------------
-- See Grouping Quiz (D)
--
-- If a new criterion exprⱼ does not increase group count,
-- then exprⱼ is constant within the existing groups.
--
-- Original query (yields four groups):
SELECT v.pid,
       count(*) AS cardinality,
FROM   vehicles AS v
GROUP BY v.pid;

-- Add new grouping criterion exprⱼ ≡ v."wheels?": query still yields
-- four groups.  Indeed, v."wheels?" is constant within each group
-- (add aggregate list(v."wheels?") to the query above to check).
--
-- Conclusion: the value of v.pid uniquely determines the value
-- of v."wheels?"
SELECT v.pid,
       v."wheels?",
       count(*) AS cardinality
FROM   vehicles AS v
GROUP BY v.pid, v."wheels?";

-- ⚠️ Still, this will fail: DuckDB does not know about this dependency
--     between v.pid and v."wheels?
SELECT v.pid,
       v."wheels?",  -- use aggregate arbitrary(v."wheels?") to let DuckDB know
       count(*) AS cardinality
FROM   vehicles AS v
GROUP BY v.pid;

-----------------------------------------------------------------------
-- See Grouping Quiz (A), (B)

-- (A) g = 1:
-- If grouping criteria yield only a single group overall,
-- apparently all rows agree on all these criteria:
SELECT  v.kind <> '' AS "non-empty kind?",
        count(*) AS cardinality
FROM    vehicles AS v
GROUP BY "non-empty kind?";

-- This GROUP BY clause is redundant (cf. non-grouped aggreation from Chapter 03)
SELECT  count(*) AS cardinality,
        sum(v.seats) AS "overall seats",
        string_agg(v.vehicle, ' ') AS vehicles
FROM    vehicles AS v
GROUP BY false;        -- OK, but constant (and thus not interesting)

-- (B) g = m:
-- If granularity is not reduced (i.e., each row forms its own group),
-- then the grouping criteria include a key for the rows:
SELECT  v.vehicle,
        count(*) AS cardinality
FROM    vehicles AS v
GROUP BY v.vehicle;
