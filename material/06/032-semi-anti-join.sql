-- SQL: Semi/Anti Joins

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

-- Which vehicles have (any) driver? (This is a subset of table vehicles.)
SELECT v.*
FROM   vehicles AS v SEMI JOIN peeps AS p ON (v.pid = p.pid);

-- Which peeps can drive at all? (This is a subset of table peeps.)
SELECT p.*
FROM   peeps AS p SEMI JOIN vehicles AS v ON (v.pid = p.pid);

-- Which peeps cannot drive at all?
SELECT p.pic, p.name AS walker
FROM   peeps AS p ANTI JOIN vehicles AS v ON (v.pid = p.pid);


-- NB.
-- - Semi join expresses an EXISTENTIALLY QUANTIFIED (∃) condition:
--   "Does there EXIST any suitable peep p to drive this vehicle v?"
--
-- - Anti join expresses a UNIVERSALLY QUANTIFIED (∀) condition:
--   "Does there NOT EXIST any suitable driver p for this vehicles v?"
--   ≡
--   "Are ALL peeps p not a suitable driver for this vehicle v?"


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

-- Two bindings returned by SEMI JOIN (result thus has two rows).
-- "Which rows in L find a join partner in R?"
--
--   (A)  L ↦ (a,4), R ↦ _
--   (B)  L ↦ (b,2), R ↦ _
--
SELECT L.l, L.k  /* R.k, R.r inaccessible: Referenced table "R" not found! */
FROM   L SEMI JOIN R ON (L.k = R.k);

-- Equivalent:
SELECT L.l, L.k
FROM   L SEMI JOIN R USING (k);

SELECT L.l, L.k
FROM   L NATURAL SEMI JOIN R;


-- One binding returned by ANTI JOIN (result thus has one row).
-- "Which rows in L do not find any join partner in R?"
--
--   (C)  L ↦ (c,3), R ↦ _

SELECT L.l, L.k
FROM   L ANTI JOIN R ON (L.k = R.k);
