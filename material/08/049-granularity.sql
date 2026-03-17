-- There is a variety of methods to control granularity of grouping
-- (i.e., the number N of groups formed).
--
-- 1. DIVISION. Group numeric values c into buckets of equal width 1/N:
--    (buckets will be ordered: values in bucket 0 < values in bucket 1)
--    - if c :: integer: c // N
--    - otherwise:       round(c / N)
--
-- 2. MODULUS. Use % (mod) or bit masking (&) on integral values to select
--    one of N buckets (no order among buckets):
--    - c % N
--    - if N = 2ⁿ: c & (1 << n) - 1
--
-- 3. GRADING. Place ordered data (including text) into buckets with given
--    borders bᵢ:
--    (the bᵢ do not need to be sorted for this to work):
--    - list_position(list_grade_up([c] || [b₁,b₂,...,bₙ]), 1)
--    - or simply: list_grade_up([c] || [b₁,b₂,...,bₙ])

CREATE OR REPLACE MACRO N() AS 10;

SELECT val,
       -- 1. DIVISION
       val // N() AS by_division,
       -- 2. MODULUS
       val % N() AS by_modulus,
       val & (1 << 3) - 1 by_masking,
       -- 3. GRADING
       list_position(list_grade_up([val] || [0,20,80,100]), 1) AS by_grading,
       list_grade_up([val] || [0,20,80,100]) AS "grade_up ⍋"
FROM   generate_series(1,111,7) AS _(val);


-- Example: group by grading
--
-- Buckets:
--              0   20             80   100
--          ────┴────┴──────────────┴────┴────
--           #1   #2       #3         #4   #5
SELECT list_position(list_grade_up([val] || [0,20,80,100]), 1) AS "bucket #",
       list(val ORDER BY val) AS group
FROM   generate_series(1,111,7) AS _(val)
GROUP BY "bucket #"
ORDER BY "bucket #";


------------------------------------------------------------------------
-- Grading playground
-- See https://duckdb.org/docs/stable/sql/functions/list

SELECT list_grade_up([30,10,20]) AS rearrange;

SELECT list_grade_up([10,20,30]) AS already_ordered;

SELECT list_grade_up(['Z','X','Y']) AS any_ordered_types;

-- Grading provides a stable rearrangement
-- ((1) precedes (2) in the rearranged list)
SELECT list_grade_up([10,30,10,20]) AS stable;
--                    |     |
--                   (1)   (2)

-- Grading can also be used for sorting.
SELECT ['Z','X','Y']                 AS original,
       list_grade_up(original)       AS graded,
       list_select(original, graded) AS sorted;

-- SQL Syntax:
--
-- In a DuckDB SELECT clause
--
--   SELECT expr₁ AS c₁,...,exprᵢ AS cᵢ,...
--
-- expression exprᵢ may refer to the names c₁,...,cᵢ₋₁.
-- (NB. This is syntactic sugar only and will RE-EVALUATE the
-- referenced expressions at query runtime.)
--
-- ⚠️ This re-evaluation may lead to unintended behavior. DuckDB
-- tries to protect from surprises (e.g., due to side effects).
-- This will fail:
SELECT random() AS x,
       2 * x    AS xx;      -- intention: random value x, but doubled...

SELECT random()     AS x,
       2 * random() AS xx;  -- ... but this is what would have happened

-- Formulating queries with random values
-- (frequency of totals in a two-dice game)
WITH
dice(die1, die2) AS (
  SELECT 1 + floor(random() * 6) :: int AS die1,
         1 + floor(random() * 6) :: int AS die2
  FROM   generate_series(1,1000)
)
SELECT d.die1 + d.die2 AS total,
       bar(count(*), 0, 200, 30) AS frequency
FROM  dice AS d
GROUP BY total
ORDER BY total;
