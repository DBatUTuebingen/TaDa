-- SQL: (Inner) Join
--
-- The full details of SQL's join syntax are found in the DuckDB
-- documentation:
--
--   https://duckdb.org/docs/stable/sql/query_syntax/from


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

-- The following inner join between vehicles and peeps "dereferences"
-- the foreign key and associates vehicles with their drivers:

SELECT v.vehicle, p.name AS driver, p.pic
FROM   vehicles AS v INNER JOIN peeps AS p ON (v.pid = p.pid);
--                                            └─────────────┘
--                                            follow foreign key
--                                      pointing from vehicles to peeps

-- NB:
-- - Some vehicles have no driver (missing in join result).
-- - Some peeps drive no vehicles (missing in join result).
-- - Some peeps drive more than one vehicle (occur more than once in join result).


-- SQL Syntax:
--
-- Equality conditions on like-named columns are VERY common in
-- SQL queries (e.g., when following a foreign key between tables).
-- SQL provides syntactic sugar USING(...) to abbreviate this common case:
--
--   FROM t₁ AS v₁ [INNER] JOIN t₂ AS v₂ ON (v₁.c₁ = v₂.c₁ AND ... AND v₁.cₙ = v₂.cₙ)
--  ≡
--   FROM t₁ AS v₁ [INNER] JOIN t₂ AS v₂ USING (c₁,...,cₙ)
--
-- If c₁,...,cₙ are EXACTLY the like-named columns in the schemata of
-- tables t₁, t₂, abbreviate further using a NATURAL JOIN:
--
--   FROM t₁ AS v₁ [INNER] JOIN t₂ AS v₂ ON (v₁.c₁ = v₂.c₁ AND ... AND v₁.cₙ = v₂.cₙ)
--  ≡
--   FROM t₁ AS v₁ NATURAL JOIN t₂ AS v₂


-- Since schema(vehicles) ∩ schema(peeps) = { pid int }, we can use a
-- NATURAL JOIN to follow the foreign key.
--
-- Given the intersection of schemata of tables vehicles and peeps, the
-- implicit join condition indeed is: v.pid = p.pid.

SELECT v.vehicle, p.name AS driver, p.pic
FROM   vehicles AS v NATURAL JOIN peeps AS p;


-- QUIZ 1: Can you formulate the query above WITHOUT using any variant
--         of SQL's JOIN keyword?


-- QUIZ 2: Can you formulate the cross product between vehicles and peeps
--         using INNER JOIN?


-- QUIZ 3: Formulate the "possible vehicle replacement query" in file
--         029-cross-products.sql using INNER JOIN.


------------------------------------------------------------------------
-- Playground: Sample tables L, R used in the join semantics diagrams:

CREATE OR REPLACE TABLE L (
  l text,
  k int
);

CREATE OR REPLACE TABLE R (
  k int,
  r text
);

INSERT INTO L(l,k) VALUES
  ('a',4),
  ('b',2),
  ('c',3);

INSERT INTO R(k,r) VALUES
  (1,'x'),
  (2,'y'),
  (4,'z');

FROM L;
FROM R;

-- Two bindings returned by INNER JOIN (result thus has two rows):
--
--   (A)  L ↦ (a,4), R ↦ (4,z)
--   (B)  L ↦ (b,2), R ↦ (2,y)
--
SELECT L.l, L.k /* = R.k */, R.r
FROM   L INNER JOIN R ON (L.k = R.k);

-- Equivalent:
SELECT L.l, L.k, R.r
FROM   L JOIN R USING (k);

SELECT L.l, L.k, R.r
FROM   L NATURAL JOIN R;
