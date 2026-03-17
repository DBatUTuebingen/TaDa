-- 003-primary-keys.sql


-- Create table verhicles, define column vehicle to be primary key
CREATE OR REPLACE TABLE vehicles (
  vehicle   text    PRIMARY KEY,  -- column vehicle uniquely identifies its row
  kind      text    NOT NULL   ,
  seats     int                ,
  "wheels?" boolean
);

-- PRIMARY KEY implies NOT NULL ...
DESCRIBE vehicles;

-- ... and that's reasonable: NULL cannot conclusively be compared
-- to any value, including itself (NULL is SQL's equivalent of ¯\_(ツ)_/¯):

SELECT NULL = 42;
SELECT NULL = NULL;
SELECT NULL <> NULL;   -- <> is inequality (non-idiomatic but OK: !=)


INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰞫', 'car',      5, true),
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),
  ('󰞧', 'cabrio',   2, true);

FROM vehicles;


-- ⚠️ This violates the PRIMARY KEY constraint (double 󱔭):
--     column vehicle would not be identifying rows anymore
INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󱔭', 'truck', 4, true);

------------------------------------------------------------------------

-- KEY QUIZ

-- For the following tables t1, t2, t3 provide alternative
-- CREATE TABLE statements that declare suitable primary keys.
-- Try to make the keys as narrow as possible.

-- (1)
CREATE OR REPLACE TABLE t1 (
  a int,
  b boolean,
  c text
);

INSERT INTO t1(a,b,c) VALUES
  (1,  true, 'three'),
  (2, false, 'one'  ),
  (3,  true, 'two'  );


-- (2)
CREATE OR REPLACE TABLE t2 (
  a int,
  b boolean,
  c text
);

INSERT INTO t2(a,b,c) VALUES
  (1,  true, 'two'),
  (1,  true, 'one'),
  (2, false, 'one');


-- (3)
CREATE OR REPLACE TABLE t3 (
  a int,
  b boolean,
  c text
);

INSERT INTO t3(a,b,c) VALUES
  (1,  true, 'three'),
  (2, false, 'one'  ),
  (1,  true, 'three');

------------------------------------------------------------------------

-- SQL syntax:
--
-- To declare columns ‹c₁›,...,‹cₖ› as a COMPOSITE primary key for
-- table ‹t›, add an extra PRIMARY KEY (‹c₁›,...,‹cₖ›) constraint to the
-- CREATE TABLE statement:
--
-- CREATE TABLE ‹t› (
--   ‹c₁› ‹type›,
--   ...
--   ‹cₙ› ‹type›,
--   PRIMARY KEY (‹c₁›,...,‹cₖ›)
-- );
--
-- No two rows in the instance of table ‹t› may contain the same value
-- COMBINATION in columns ‹c₁›,...,‹cₖ›: columns ‹c₁›,...,‹cₖ› JOINTLY
-- identify rows in table ‹t›.


CREATE OR REPLACE TABLE t1 (
  a int PRIMARY KEY,   -- if all else is equal, choose type int to identify rows
  b boolean,
  c text
);

INSERT INTO t1(a,b,c) VALUES
  (1,  true, 'three'),
  (2, false, 'one'  ),
  (3,  true, 'two'  );


-- (2)
CREATE OR REPLACE TABLE t2 (
  a int,
  b boolean,
  c text,
  PRIMARY KEY (a,c)  -- no two rows ever contain the same combination in columns a,c
);

INSERT INTO t2(a,b,c) VALUES
  (1,  true, 'two'),
  (1,  true, 'one'),
  (2, false, 'one');

DESCRIBE t2;

-- (3)
-- Table t3 contains two duplicate rows (1, true, 'three'): no key will
-- ever be able to distinguish between those.


------------------------------------------------------------------------

-- Formally:
--
-- If columns c₁,...,cₖ form a key for table t, then
--
--   ∀ row r, row s ∊ t: r.c₁ = s.c₁ ∧ ... ∧ r.cₖ = s.cₖ ⇒ r = s
--
--
-- "Column a is a key for table t1."
-- ≡
-- "If you pick any two rows r and s from table t1 and you find that r.a = s.a,
--  then you know that r and s are indeed the same row (and thus also agree
--  on all other columns)."
