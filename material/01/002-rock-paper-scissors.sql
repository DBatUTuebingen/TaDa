-- 002-rock-paper-scissors.sql

-- Which move beats which in the game of Rock, Paper, Scissors (RPS)?
CREATE OR REPLACE TABLE beats (
  lose text NOT NULL,  -- losing move
  win  text NOT NULL   -- winning move
);

INSERT INTO beats(lose, win) VALUES   -- OK: INSERT INTO beats VALUES ...
  ('', ''),
  ('', ''),
  ('', '');

DESCRIBE beats;
FROM beats;

-- Type text is OK but admits a virtually limitless set of values
-- that do not correspond to a valid move :-/

-- ⚠️ OK regarding types and constraints but questionable in the
--    Rock-Paper-Scissors game domain
INSERT INTO beats(lose, win) VALUES
  ('rock',     'paper'),   -- moves encoded wrong
  ('straight', 'flush');   -- oops, poker (change of domain)

FROM beats;

------------------------------------------------------------------------

-- Create a new variant of table beats, use CHECK constraints
-- to limit valid lose/win values. Need to repeatedly formulate
-- the constraint predicate. :-/
CREATE OR REPLACE TABLE beats (
  lose text NOT NULL CHECK (lose IN ('', '', '')),  -- list valid values
  win  text NOT NULL CHECK (win  IN ('', '', ''))   ---... again
);

-- Columns lose/win are still text (≡ varchar) columns
DESCRIBE beats;

-- ⚠️ Populate table beats, some rows violate the CHECK constraints
INSERT INTO beats(lose, win) VALUES
  (''      , ''),
  (''      , ''),
  (''      , ''),
  ('rock'    , 'paper'),
  ('straight', 'flush');

-- ⚠️ Before you execute: which result do you expect?
FROM beats;


------------------------------------------------------------------------

-- Create a new type named rps with a custom domain that exactly fits
-- our use case: explicitly enumerate the (few) values of type rps.
--
-- We need new rps literals, enclose these in single quotes '...'
-- (these are NOT strings).

DROP TYPE IF EXISTS rps;
CREATE TYPE rps AS ENUM ('', '', '');  -- size of value domain: 3
--                      └────────────────┘
--              enumerate all values of new type rps

CREATE OR REPLACE TABLE beats (
  lose rps NOT NULL,
  win  rps NOT NULL
  --    |
  --  uses new type
);

-- Type rps is unfolded to show its definition
DESCRIBE beats;

INSERT INTO beats(lose, win) VALUES   -- OK: INSERT INTO beats VALUES ...
  ('', ''),
  ('', ''),
  ('', '');

FROM beats;

-- ⚠️ These violate the value domain of type rps
INSERT INTO beats(lose, win) VALUES
  ('rock',     'paper'),
  ('straight', 'flush');

/* DuckDB's error message

   Conversion Error:
   Could not convert string 'rock' to UINT8

   LINE 2:   ('rock',     'paper'),   -- moves encoded wrong
              ^

   reveals that the values of an enumerated type are internally
   represented by small 8-bit integers.  This is a significantly
   more compact representation than Unicode strings.  Enumerated
   values also compare faster than (potentially sizable) strings.
*/

------------------------------------------------------------------------

-- SQL syntax:
--
-- To evaluate an expression ‹e›, use SELECT ‹e›;

SELECT 41+1;
SELECT 1 < 2;
SELECT 'Edward F.' || ' ' || 'Codd';

-- To cast an expression ‹e› to type ‹t›, use CAST(‹e› AS ‹t›) or ‹e› :: ‹t›.

SELECT CAST('42' AS int);
SELECT CAST('f' AS boolean);
SELECT 't' :: boolean;
SELECT 42 :: text;
SELECT true :: int;

-- In the definition of enumerated types, order of literals matters.
-- For rps: '' < '' < ''.

SELECT '' :: rps;
SELECT 'scissors' :: rps;  -- ⚠️ fails

SELECT '' :: rps < '' :: rps;   -- true (see definition of rps)
SELECT '' < '';                 -- false (U+F257 < U+F256)
