-- The SQL FROM clause generates the cross product of row variable
-- bindings if multiple tables are listed.

-- Generates 3 × 5 bindings
SELECT v1.i, v2.j
FROM   generate_series(1,3) AS v1(i),
       generate_series(1,5) AS v2(j);

-- Generates 1000³ (1 billion) bindings...
SELECT count(*) AS one_billion
FROM   generate_series(1,1000) AS _1,  -- Grust's style: use unique row variable _ᵢ
       generate_series(1,1000) AS _2,  -- if the names are irrelevant
       generate_series(1,1000) AS _3;

-- The vehicles table
CREATE OR REPLACE TABLE vehicles (
  vehicle   text    NOT NULL UNIQUE,
  kind      text    NOT NULL DEFAULT 'unknown',
  seats     int     CHECK (seats BETWEEN 1 AND 60), -- seats >= 1 AND seats <= 60
  "wheels?" boolean DEFAULT true
);

INSERT INTO vehicles(vehicle, kind, seats, "wheels?") VALUES
  ('󰞫', 'car',      5, true),
  ('󱔭', 'SUV',      3, true),
  ('󰞞', 'bus',     42, true),
  ('󰟺', 'bus',      7, true),
  ('󰍼', 'bike',     1, true),
  ('󰴺', 'tank',  NULL, false),
  ('󰞧', 'cabrio',   2, true);


-- Generates |vehicles| × 2 (= 14) row variable binding combinations
SELECT v.vehicle || '  #' || one_two.i AS vehicle, v.kind, v.seats, v."wheels?"
FROM   vehicles AS v, generate_series(1,2) AS one_two(i);

-- Generates |vehicle| × |vehicle| (= 49) combinations
SELECT v1 AS vehicle1, v2 AS vehicle2
FROM   vehicles AS v1, vehicles AS v2;

-- Pair each vehicle v1 with all possible replacement vehicles v2
-- that have larger capacity.
--
-- - The bike can be replaced by any other vehicle.
-- - Nothing replaces a large bus.
--
-- Quiz: Will a vehicle be paired with itself?
SELECT v1.vehicle, v1.seats,
       v2.vehicle AS "possible replacement",
       v2.seats - v1.seats AS "added capacity"
FROM   vehicles AS v1, vehicles AS v2
WHERE  v1.seats < v2.seats
ORDER BY v1.vehicle;


-----------------------------------------------------------------------
-- Example: recipe optimization (by enumeration, or: "brute force")
--
-- Adapted from a toy query by Julian Hyde (author of the Morel query language)
--
-- A banana cakes sells for 4.00$.
-- Recipe:
--     50g flour
--       2 bananas
--     75g sugar
--    100g butter
--
-- A chocalate cake sells for 4.50$.
-- Recipe:
--     200g flour
--     150g sugar
--     150g butter
--      75g cocoa
--
-- Q: You have the following ingredients available. How many banana
--    and chocolate cakes should you bake to maximize profit?
--
--     40kg flour
--       60 bananas 🍌
--     20kg sugar
--      5kg butter
--      5kg cocoa 🍫

.timer on

SELECT b                   AS "banana cakes",
       c                   AS "chocolate cakes",
       4.00 * b + 4.50 * c AS profit
FROM   generate_series(1,100) AS  _(b),
       generate_series(1,100) AS __(c),
       (VALUES (40, 60, 20, 5, 5)) AS i(flour,bananas,sugar,butter,cocoa)
WHERE   0.050 * b + 0.200 * c  <= i.flour
AND         2 * b              <= i.bananas
AND     0.075 * b + 0.150 * c  <= i.sugar
AND     0.100 * b + 0.150 * c  <= i.butter
AND                 0.075 * c  <= i.cocoa
ORDER BY profit DESC
LIMIT 3;

-- Julian Hyde: "This is an example of the kind of problems that Morel
-- can solve that a regular SQL relational query language can't solve."
--
-- Well, I don't think so, Julian. 😉
--
-- https://youtu.be/xwFsXVyMAN0?si=_RRoCaJZn4_KY_rT&t=2084s
