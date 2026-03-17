-- SQL: Left/Right/Full Outer Joins

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

-- Vehicles and their drivers (keep vehicles if nobody can drive them):
SELECT v.vehicle, p.name AS driver, p.pic
FROM   vehicles AS v LEFT OUTER JOIN peeps AS p ON (v.pid = p.pid);

-- Drivers and their vehicles (keep peeps if they cannot drive):
SELECT v.vehicle, p.name AS driver, p.pic
FROM   vehicles AS v RIGHT OUTER JOIN peeps AS p ON (v.pid = p.pid);


-- SQL Syntax:
--
-- Built-in function coalesce(e₁,e₂,...,eₙ) returns the first eᵢ
-- that is not NULL.

SELECT coalesce(NULL,NULL,3,NULL);   -- 3
SELECT coalesce(NULL,NULL,NULL);     -- NULL

-- Use replacement vehicle '(walks)' if p is not a driver
-- (RIGHT OUTER JOIN returns an all-NULL binding for v):
SELECT coalesce(v.vehicle, '(walks)') AS vehicle, p.name AS driver, p.pic
FROM   vehicles AS v RIGHT OUTER JOIN peeps AS p ON (v.pid = p.pid);


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

-- Three bindings returned by LEFT OUTER JOIN (result thus has three rows):
--
--   (A)  L ↦ (a,4), R ↦ (4,z)        ┐ as returned by
--   (B)  L ↦ (b,2), R ↦ (2,y)        ┘ INNER JOIN
--   (C)  L ↦ (c,3), R ↦ (NULL,NULL)
--
SELECT L.l, L.k, R.k, R.r
FROM   L LEFT OUTER JOIN R ON (L.k = R.k);

-- Equivalent:
SELECT L.l, L.k, R.k, R.r
FROM   L LEFT OUTER JOIN R USING (k);

SELECT L.l, L.k, R.k, R.r
FROM   L NATURAL LEFT OUTER JOIN R;


-- Four bindings returned by FULL OUTER JOIN (result thus has four rows):
--
--   (A)  L ↦ (a,4)      , R ↦ (4,z)
--   (B)  L ↦ (b,2)      , R ↦ (2,y)
--   (C)  L ↦ (c,3)      , R ↦ (NULL,NULL)
--   (D)  L ↦ (NULL,NULL), R ↦ (1,x)

SELECT L.l, L.k, R.k, R.r
FROM   L FULL OUTER JOIN R ON (L.k = R.k);
