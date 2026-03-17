-- SQL supports existential and universal quantification over
-- table-valued subqueries

-----------------------------------------------------------------------
-- Sample database:
-- Train services, stops, and stations in the Netherlands
-- (and neighbouring countries).  Derived from open data
-- provided by the Rijden de Treinen app (see the train archive on
-- https://www.rijdendetreinen.nl/en/open-data).

-- Database schema (three tables):
--
--   trains(ID, SERVICE, date, type, company,
--          completely_cancelled, partly_cancelled, max_delay)
--
--   stations(STATION, name)
--
--   stops((ID, SERVICE) -> trains, STATION -> stations,
--         arrival, arrival_delay, arrival_cancelled,
--         departure, departure_delay, departure_cancelled)
--
-- Notes:
-- - A train service is uniquely identified by key (id, service)
--   (services run repeatedly, trains may be split, ...)
-- - The *_delay columns (int) holds delays in minutes

-- NB. Run generate-041-railway.sql to generate DuckDB database 041-railway.db
ATTACH '041-railway.db' AS railway;
USE railway;

DESCRIBE trains;
DESCRIBE stations;
DESCRIBE stops;

-- Time the query below (we will meet a variant of this query later on)
.timer on

-- Which train(s) stop in Dortmund and Munich?
SELECT DISTINCT t.service, t.type, t.company
FROM   trains AS t
WHERE  EXISTS (FROM stops AS s NATURAL JOIN stations AS st
               WHERE t.id = s.id AND t.service = s.service
               AND st.name = 'Dortmund Hbf')
AND    EXISTS (FROM stops AS s NATURAL JOIN stations AS st
               WHERE t.id = s.id AND t.service = s.service
               AND st.name = 'München Hbf');

.timer off

-- Trains that stop over midnight at some station
-- (arrival on the day before departure)
FROM  trains AS t
WHERE EXISTS (FROM   stops AS s
              WHERE  t.id = s.id AND t.service = s.service
              AND    s.arrival :: date < s.departure :: date);


-- Trains that arrive (at least a day) later than their service date
FROM  trains AS t
WHERE t.date < ANY (SELECT s.arrival :: date
                    FROM   stops AS s
                    WHERE  t.id = s.id AND t.service = s.service);


-- Stations in which all halting trains are operated by DB
-- (these stations will probably be in Germany or close to the border to NL)
SELECT DISTINCT st.name
FROM   stops AS s NATURAL JOIN stations AS st
WHERE  'DB' = ALL (SELECT t.company
                   FROM   trains t, stops AS s1
                   WHERE  t.id = s1.id AND t.service = s1.service AND s1.station = s.station);


-- Data consistency check:
-- Does a train's maximum delay correspond to a arrival/departure delay
-- at at least one stop? (If the data is consistent, result should be empty.)
FROM  trains AS t
WHERE t.max_delay <> ALL (SELECT s.departure_delay
                          FROM   stops AS s
                          WHERE  t.id = s.id AND t.service = s.service
                            UNION
                          SELECT s.arrival_delay
                          FROM   stops AS s
                          WHERE  t.id = s.id AND t.service = s.service);

-- Variant quantifier: t.max_delay NOT IN (...)


-- SQL Syntax:
--
-- The expression (‹expr₁›,‹expr₂›,...,‹exprₙ›) constructs a row value
-- of n columns with anonymous (unnamed) columns.
--
-- Equivalent: row(‹expr₁›,‹expr₂›,...,‹exprₙ›)

SELECT (1,2,3) AS row;              -- row value with anonymous columns
SELECT {'a':1,'b':2,'c':3} AS row;  -- row value with named columns
SELECT 1, 2, 3;                     -- different: three columns

SELECT (1,2,3) = (1,2,3);           -- equality based on column positions
SELECT {'a':1,'b':2,'c':3} = {'c':3,'a':1,'b':2};
                                    -- equality based on column names



-- Trains with final destination Brussel-Zuid
SELECT DISTINCT t.service, t.type, t.company
FROM   trains AS t
--              compares row values
--                     ┌──┐
WHERE  (t.id, t.service) IN (SELECT (s.id, s.service)
                             FROM   stops AS s NATURAL JOIN stations AS st
                             WHERE  st.name = 'Brussel-Zuid' AND s.departure IS NULL)
ORDER BY t.service;



-----------------------------------------------------------------------
-- Quantification playground

USE memory;

-- Quantification over empty results
--
-- Yields true:
-- there is no value in the subquery result that does not equal 1
SELECT 1 = ALL (SELECT 0 WHERE false);

-- Yields false:
-- there is no value in the subquery result that equals 1
SELECT 1 = ANY (SELECT 0 WHERE false);

-- Careful if NULL occurs in the subquery result
-- (VALUES: see below)
SELECT 1 <  ANY (VALUES (1), (2), (NULL));   -- true
SELECT 3 <  ANY (VALUES (1), (2), (NULL));   -- ¯\_(ツ)_/¯ (NULL)
SELECT 3 <> ALL (VALUES (1), (2), (NULL));   -- ¯\_(ツ)_/¯ (NULL)


-- Syntactic sugar for IN only: explicitly enumerate the values to
-- compare to in a comma-separated list (‹expr₁›, ‹expr₂›, ...).
--
--                  list of values
--             ┌─────────────────────┐
--   ‹expr› IN (‹expr₁›, ‹expr₂›, ...) is equivalent to
--   ‹expr› IN (VALUES (‹expr₁›), (‹expr₂›), ...)
--             └────────────────────────────────┘
--            subquery, yields single-column table
SELECT 1    IN (1,2,3);     -- true
SELECT 2    IN (NULL,2,3);  -- true
SELECT 3    IN (1,2,NULL);  -- NULL
SELECT NULL IN (1,2,NULL);  -- NULL

SELECT t.delta, 42 IN (40-t.delta, 40+t.delta) AS "42?"
FROM  (VALUES (0), (1), (2)) AS t(delta);


-- SQL Syntax:
--
-- Expression
--
--   VALUES (expr₁₁, expr₁₂, ..., expr₁ₙ),  ┐
--          (expr₂₁, expr₂₂, ..., expr₂ₙ),  │  m row values of
--          ...                             │  identical width n
--          (exprₘ₁, exprₘ₂, ..., exprₘₙ)   ┘
--
-- constructs an anonymous table of m rows and n unnamed columns.

VALUES (0), (1), (2);
VALUES (1, false), (2, true), (3, true), (4, false);
-- Use row variables and column naming
FROM (VALUES (1, false),
             (2, true ),
             (3, true ),
             (4, false)) AS t(number, "prime?");



-----------------------------------------------------------------------
-- Quantification does NOT add to the expressive power of SQL

-- Recreate the vehicles/driver sample tables
--
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

-- Qex: Peeps who can drive any vehicle (correlated)
FROM  peeps AS p
WHERE EXISTS (FROM vehicles AS v WHERE p.pid = v.pid);

-- Equivalent to Qex (uncorrelated)
FROM  peeps AS p
WHERE p.pid IN (SELECT v.pid FROM vehicles AS v);


-- Qall: Peeps who canot drive any vehicle (correlated)
FROM  peeps AS p
WHERE NOT EXISTS (FROM vehicles AS v WHERE p.pid = v.pid);

-- Equivalent to Qall (uncorrelated)
FROM  peeps AS p
WHERE p.pid <> ALL (SELECT v.pid FROM vehicles AS v WHERE v.pid IS NOT NULL);



-- Qex (Qall) can be rewritten into a SEMI (ANTI) JOIN:
--
-- Equivalent to Qex
FROM peeps AS p NATURAL SEMI JOIN vehicles AS v;

-- Equivalent to Qall
FROM peeps AS p NATURAL ANTI JOIN vehicles AS v;


-- Indeed, DuckDB rewrites Qex and Qall into JOINs behind the scenes:
PRAGMA explain_output = 'all';

EXPLAIN
FROM  peeps AS p
WHERE EXISTS (FROM vehicles AS v WHERE p.pid = v.pid);

EXPLAIN
FROM  peeps AS p
WHERE NOT EXISTS (FROM vehicles AS v WHERE p.pid = v.pid);

/*

┌─────────────┴─────────────┐
│      COMPARISON_JOIN      │
│    ────────────────────   │
│      Join Type: ANTI      │
│                           │
│        Conditions:        ├──────────────┐
│        (pid = pid)        │              │
└─────────────┬─────────────┘              │
┌─────────────┴─────────────┐┌─────────────┴─────────────┐
│          SEQ_SCAN         ││         PROJECTION        │
│    ────────────────────   ││    ────────────────────   │
│        Table: peeps       ││      Expressions: pid     │
│   Type: Sequential Scan   ││                           │
└───────────────────────────┘└─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │           FILTER          │
                             │    ────────────────────   │
                             │        Expressions:       │
                             │     (pid IS NOT NULL)     │
                             └─────────────┬─────────────┘
                             ┌─────────────┴─────────────┐
                             │          SEQ_SCAN         │
                             │    ────────────────────   │
                             │      Table: vehicles      │
                             └───────────────────────────┘
*/
