-- Exercise SQL's grouping capabilities on the NYC Taxi "Yellow Cab" data set
-- provided by the Ney York City government:
-- https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

-- The taxi data contains bits of geographic information.  DuckDB's
-- spatial extension provides data types (e.g., geometry) and built-in
-- functions (e.g., st_distance_sphere()) to work with geographic data
-- (see https://duckdb.org/docs/stable/core_extensions/spatial/overview).
INSTALL spatial;
LOAD spatial;

-- Attach the NYC Taxi database.
--
-- Database schema (three tables: central_park_weather, zones, rides)
--
-- central_park_weather (
--   date          date PRIMARY KEY,
--   station       text,     -- USW00094728                         [const]
--   name          text,     -- weather station name (Central Park) [const]
--   lat           double,   -- 40.77898                            [const]
--   lon           double,   -- -73.96925                           [const]
--   elevation     double,   -- 42.7 meters                         [const]
--   wind          double,   -- in m/s
--   precipitation double,   -- in liter/m²
--   snow          double,   -- in liter/m²
--   snow_depth    double,   -- cm
--   temp_max      double,   -- in ℃
--   temp_min      double    -- in ℃
--  )
--
--  zones (
--   loc         int PRIMARY KEY,
--   borough     text,       -- Bronx ... Unknown
--   zone        text,       -- Allerton .. Yorkville West
--   geometry    geometry,   -- zone geometry (feed in to st_*() functions)
--   lon         double,     -- longitude of centroid of zone's geometry
--   lat         double      -- latitude
--  )
--
-- rides (
--   vendor                int,          -- taxi provider code
--   pickup_at             timestamp,
--   dropoff_at            timestamp,
--   passengers            int,
--   distance              double,       -- as shown by taxi meter (in miles)
--   rate_code             int,          -- 1 = standard, 2 = JFK, 6 = group, ...
--   "store_and_fwd?"      boolean,      -- trip record held in vehicle memory due to server disconnect?
--   pickup_loc            int,
--   dropoff_loc           int,
--   payment               int,          -- 1 = credit card, 2 = cash, 3 = no charge, 4 = dispute, ...
--   fare                  double,       -- as shown by taxi meter
--   extra                 double,
--   mta_tax               double,
--   tip                   double,
--   tolls                 double,
--   improvement_surcharge double,
--   total                 double,       -- total amount charged to passenger(s)
--   congestion_surcharge  double,
--   airport_fee           double,       -- for pickup at LaGuardia and JFK
--   FOREIGN KEY (pickup_loc)  REFERENCES zones(loc),
--   FOREIGN KEY (dropoff_loc) REFERENCES zones(loc)
-- )

-- NB. Run generate-051-nyc-taxi.sql to generate DuckDB database 051-nyc-taxi.db
ATTACH '051-nyc-taxi.db' AS taxi (read_only);
USE taxi;

SHOW TABLES;


-- Query 1:
-- Popularity of ride payment types (credit card, cash, ...)
-- (Note: DuckDB detects that column "paid via" is constant in each group)
SELECT ['credit card', 'cash', 'no charge'][r.payment] AS "paid via",
       count(*) AS rides
FROM   rides AS r
WHERE  r.payment IN (1,2,3)
GROUP BY r.payment
ORDER BY rides DESC;


-- Query 2:
-- Does the number of taxi rides depend on weather conditions, in particular
-- rain or snow fall?  (We use the weather conditions in Central Park as a
-- proxy for NYC weather in general.)
--
-- Uses grading to group rain fall into buckets.
SELECT list_position(list_grade_up([w.precipitation] || [0.0, 1.0, 5.0, 10.0, 20.0, 30.0]), 1) AS rain,
       count(DISTINCT w.date) AS days,
       count(*) AS rides,
       rides // days AS "rides per day",                   -- ≡ count(*) / count(DISTINCT w.date)
       bar("rides per day", 0, 150000, 30) AS visualized
FROM  rides AS r JOIN central_park_weather AS w ON (r.pickup_at :: date = w.date)
GROUP BY rain
ORDER BY rain;

-- Uses divsion to group snow fall into buckets of equal width of 5.0 l/m²
SELECT round(w.snow / 5.0) * 5.0 AS snow_fall,
       count(DISTINCT w.date) AS days,
       count(*) AS rides,
       rides // days AS "rides per day",
       bar("rides per day", 0, 150000, 30) AS visualized
FROM  rides AS r JOIN central_park_weather AS w ON (r.pickup_at :: date = w.date)
GROUP BY snow_fall
ORDER BY snow_fall;

-----------------------------------------------------------------------

-- SQL Syntax:
--
-- The aggregate count(DISTINCT ‹expr›) counts the number of distinct/unique
-- non-NULL values of expression ‹expr›.
--
-- (In DuckDB, the DISTINCT modifier works with any aggregate function.)

SELECT count(a)           AS "# non-NULL a",
       count(DISTINCT a)  AS "# of distinct non-NULL a",
       count(*)           AS "# of rows",
       count(DISTINCT 42) AS "42"
FROM   (VALUES (1), (2), (2), (3), (3), (3), (NULL)) AS _(a);

-----------------------------------------------------------------------


-- Query 3:
-- Could Bruce Willis and Samuel L. Jackson have possibly made it from the
-- Upper West Side to Wall Street (Financial District) in 30 minutes using
-- a Yellow Cab?
--
-- "Die Hard 3: With a Vengeance" (1995)
-- see https://www.youtube.com/watch?v=U2_KKBA9_Xw
SELECT extract(minutes from r.dropoff_at - r.pickup_at) AS "trip duration",
       bar(count(*) :: int, 0, 25, 30) AS count
FROM   zones AS z1 CROSS JOIN zones AS z2 JOIN rides AS r
       ON (r.pickup_loc = z1.loc AND r.dropoff_loc = z2.loc)
WHERE  z1.zone LIKE '%Upper West Side%' AND z2.zone LIKE '%Financial District%'
AND    extract(dayofweek from r.pickup_at) BETWEEN 1 AND 5
AND    r.pickup_at :: time BETWEEN '09:20:00' AND '10:20:00'
GROUP BY "trip duration"
ORDER BY "trip duration";


-- Query 4:
-- How does the distance displayed on taxi meters deviate from the true
-- Haversine geographic distance between pickup and dropoff location?
-- (NB. Locations are only approximate: centroid of the spheres representing
-- the NYC taxi zones, visualized at
-- https://www.nyc.gov/assets/tlc/images/content/pages/about/taxi_zone_map_manhattan.jpg)
--
-- Uses bucketing, bucket borders are held in a separate literal table
-- b(bucket,lo,hi).
WITH
distances(pickup, dropoff, taxi_meter, "as the crow flies", ratio) AS (
  SELECT map.pickup, map.dropoff,
         (r.distance * 1.609)  :: decimal(8,2) AS taxi_meter,
         (map.distance / 1000) :: decimal(8,2) AS "as the crow flies",
         taxi_meter / "as the crow flies" AS ratio
  FROM   rides AS r,
         (SELECT z1.zone AS pickup, z2.zone AS dropoff,                    -- ┐
                 st_distance_sphere(st_point(z1.lat, z1.lon),              -- │ Subquery map(pickup,dropoff,distance)
                                    st_point(z2.lat, z2.lon)) AS distance  -- │ computes the geographic distance
          FROM   zones AS z1 CROSS JOIN zones AS z2                        -- │ between r.pickup_loc and r.dropoff_loc
          WHERE  r.pickup_loc = z1.loc AND r.dropoff_loc = z2.loc) AS map  -- ┘
  WHERE   r.pickup_loc <> r.dropoff_loc
  AND     r.distance IS NOT NULL AND map.distance IS NOT NULL
)
-- (1) Peek into CTE distances
-- FROM distances
-- LIMIT 10;
-- (2) Group distance deviations into five buckets
SELECT b.bucket,
       count(*) AS rides,
       bar(rides, 0, 25_000_000, 30) AS visualized
FROM distances AS d,
     (VALUES (1,   0.0 :: double,   1.0 :: double),
             (2,   1.0          ,   2.0          ),
             (3,   2.0          ,   5.0          ),
             (4,   5.0          , 100.0          ),
             (5, 100.0          , 'inf'          )) AS b(bucket,lo,hi)
WHERE d.ratio BETWEEN b.lo AND b.hi
GROUP BY b.bucket
ORDER BY b.bucket;


-- Result:
--
-- ┌────────┬──────────┬────────────────────────────────┐
-- │ bucket │  rides   │           visualized           │
-- │ int32  │  int64   │            varchar             │
-- ├────────┼──────────┼────────────────────────────────┤
-- │      1 │  4984851 │ █████▉                         │
-- │      2 │ 20511747 │ ████████████████████████▌      │
-- │      3 │ 12030628 │ ██████████████▍                │
-- │      4 │  1383330 │ █▋                             │
-- │      5 │     1108 │                                │
-- └────────┴──────────┴────────────────────────────────┘
--
-- Quiz: How can we include the bucket borders lo/hi to see this
--       wider result schema?  Won't this affect the grouping?
--
--              ￬        ￬
-- ┌────────┬────────┬────────┬──────────┬────────────────────────────────┐
-- │ bucket │   lo   │   hi   │  rides   │           visualized           │
-- │ int32  │ double │ double │  int64   │            varchar             │
-- ├────────┼────────┼────────┼──────────┼────────────────────────────────┤
-- │      1 │    0.0 │    1.0 │  4984851 │ █████▉                         │
-- │      2 │    1.0 │    2.0 │ 20511747 │ ████████████████████████▌      │
-- │      3 │    2.0 │    5.0 │ 12030628 │ ██████████████▍                │
-- │      4 │    5.0 │  100.0 │  1383330 │ █▋                             │
-- │      5 │  100.0 │    inf │     1108 │                                │
-- └────────┴────────┴────────┴──────────┴────────────────────────────────┘
