-- A VIEW ‹v› is a virtual (computed) table whose schema and
-- state is defined by a SQL query ‹q›.  Whenever name ‹v›
-- is referenced in a query, query ‹q› is re-evaluated.

-- SQL syntax:
--
-- CREATE [OR REPLACE] VIEW ‹v›(‹columns›) AS
--   ‹q›
--
-- (If ‹columns› are absent, the result of ‹q› determines the column names.)

-----------------------------------------------------------------------

-- Define & populate the sample table t found on the slides
--
-- There is an embedded FD x -> y but DuckDB cannot enforce/protect it
-- (there is no FUNCTIONAL DEPENDENCY constraint in SQL)
CREATE OR REPLACE TABLE t (
  k text PRIMARY KEY,
  x int,
  y int   -- y = f(x) = x * 10, but FD x -> y not enforced by DuckDB :-(
);

INSERT INTO t(k,x,y) VALUES
  ('k₁',1,10),
  ('k₂',2,20),
  ('k₃',1,10),
  ('k₄',1,10),
  ('k₅',2,20);

FROM t;

-----------------------------------------------------------------------
-- To preserve the FD x -> y, split t into tˣ and tᶠ
-- (see file 054-fd-split.sql):

CREATE OR REPLACE TABLE tˣ (
  k text PRIMARY KEY,
  x int
);

INSERT INTO tˣ(k,x)
  SELECT t.k, t.x
  FROM   t;

-- tᶠ: Lookup table for function f
CREATE OR REPLACE TABLE tᶠ (
  x int PRIMARY KEY,   -- FD x -> y is now a key FD
  y int
);

INSERT INTO tᶠ(x,y)
  SELECT DISTINCT t.x, t.y  -- DISTINCT avoids redundancy
  FROM   t;

FROM tˣ;
FROM tᶠ;

-----------------------------------------------------------------------
-- We can faithfully recreate the original table t from tˣ and tᶠ
-- using a natural join.  (Table t thus is not neeeded any longer
-- and could be deleted.)

-- Define a view tᵛ those schema and state are equivalent t:
CREATE OR REPLACE VIEW tᵛ AS
  FROM tˣ NATURAL JOIN tᶠ;

FROM tᵛ;

-- Indeed, t and tᵛ are identical
-- (this will yield no rows):
FROM t EXCEPT FROM tᵛ  -- rows in t that are not in tᵛ
  UNION ALL
FROM tᵛ EXCEPT FROM t; -- rows in tᵛ that are not in t

-- OK then, goodbye t
DROP TABLE t;


-- The state of tᵛ is recomputed on every reference:
EXPLAIN
FROM tᵛ;

-- Updating function f is efficient (touches one row)
-- and leads to consistent changes:
UPDATE tᶠ SET y = -10 WHERE x = 1;

FROM tᵛ;

-- The view itself is not updatable:
UPDATE tᵛ SET y = -10 WHERE x = 1;

-----------------------------------------------------------------------
-- An alternative view definition:
--
-- Since y = f(x) = x*10 is trivially computable, there is no need
-- to materialize the lookup table.  Instead, compute column y in
-- the view definition:

CREATE OR REPLACE VIEW tᵛ(k,x,y) AS
  SELECT tˣ.*,
         tˣ.x * 10 AS y  -- compute y = f(x) on the fly
  FROM tˣ;

FROM tᵛ;

-- Users of tᵛ will not be able to tell the difference between the two
-- view definitions (lookup table vs. computation).  In DB lingo, this
-- desirable property is known as (logical) DATA INDEPENDENCE.

-----------------------------------------------------------------------
-- ⚠️ Not every arbitray vertical table split is lossless.

CREATE OR REPLACE TABLE s (
  x text,
  y text,
  z text
);

INSERT INTO s(x,y,z) VALUES
  ('x₁', 'y₁', 'z₁'),
  ('x₁', 'y₁', 'z₂'),
  ('x₁', 'y₂', 'z₁');

FROM s;

-- Split s vertically into sˣʸ(x,y) and sˣᶻ(x,z):

CREATE OR REPLACE TABLE sˣʸ AS
  SELECT DISTINCT s.x, s.y
  FROM s;

CREATE OR REPLACE TABLE sˣᶻ AS
  SELECT DISTINCT s.x, s.z
  FROM s;

FROM sˣʸ;
FROM sˣᶻ;

-- Reconstructing s from sˣʸ and sˣᶻ generates a bogus row
-- "out of thin air".  We get more (too many) rows.
-- That's loss of information:

CREATE OR REPLACE VIEW sᵛ(k,x,y) AS
  FROM sˣʸ NATURAL JOIN sˣᶻ;

FROM sᵛ;

-- Non-empty... uh oh
FROM s EXCEPT FROM sᵛ
  UNION ALL
FROM sᵛ EXCEPT FROM s;

-- Generally (Decomposition Theorem):
--
-- Given a table t(C) with columns C, a vertical split of t
-- into t₁(C₁) and t₂(C₂) (with C = C₁ ∪ C₂) is lossless if
-- the intersection C₁ ∩ C₂ contains a key of either t₁ or t₂ (or both).
--
-- The precondition holds for a split of t along FD x -> y:
-- x is a column in tˣ as well as tᶠ and x is key in tᶠ.
