-- Read NYC taxi ("Yellow Cab") Data Parquet files for year 2024,
-- clean up column names, add Central Park weather data and
-- taxi zone lookup tables.
--
-- NYC taxi source: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
-- Central Park weather source: https://www.ncdc.noaa.gov/cdo-web/datasets/GHCND/stations/GHCND:USW00094728/detail

.bail on

DETACH DATABASE IF EXISTS taxi;

.shell rm -f 051-nyc-taxi.db

ATTACH '051-nyc-taxi.db' AS taxi;
USE taxi;

INSTALL spatial;
LOAD spatial;

-- Daily weather summary for Central Park weather station USW00094728
-- (in metric units)
CREATE OR REPLACE TABLE central_park_weather (
  date          date PRIMARY KEY,
  station       text,               -- USW00094728
  name          text,               -- weather station name (Central Park)
  lat           double,             -- 40.77898
  lon           double,             -- -73.96925
  elevation     double,             -- 42.7 meters
  wind          double,             -- in m/s
  precipitation double,             -- in liter/m²
  snow          double,             -- in liter/m²
  snow_depth    double,             -- cm
  temp_max      double,             -- in ℃
  temp_min      double              -- in ℃
);

CREATE OR REPLACE TABLE zones (
  loc         int PRIMARY KEY,
  borough     text,                 -- Bronx ... Unknown
  zone        text,                 -- Allerton .. Yorkville West
  geometry    geometry,             -- zone geometry (feed in to ST_*() functions)
  lon         double,               -- longitude of centroid of zone's geometry
  lat         double                -- latitude
);

-- For a detailed data dictionary for the taxi rides, see
-- https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf
CREATE OR REPLACE TABLE rides (
  vendor                int,          -- taxi provider code
  pickup_at             timestamp,
  dropoff_at            timestamp,
  passengers            int,
  distance              double,       -- in miles
  rate_code             int,          -- 1 = standard, 2 = JFK, 6 = group, ...
  "store_and_fwd?"      boolean,      -- trip record held in vehicle memory due to server disconnect?
  pickup_loc            int,
  dropoff_loc           int,
  payment               int,          -- 1 = credit card, 2 = cash, 3 = no charge, 4 = dispute, ...
  fare                  double,       -- as shown by taxi meter
  extra                 double,
  mta_tax               double,
  tip                   double,
  tolls                 double,
  improvement_surcharge double,
  total                 double,       -- total amount charged to passenger(s)
  congestion_surcharge  double,
  airport_fee           double,       -- for pickup at LaGuardia and JFK
  FOREIGN KEY (pickup_loc)  REFERENCES zones(loc),
  FOREIGN KEY (dropoff_loc) REFERENCES zones(loc)
);

-- Load Central Park weather data
INSERT INTO central_park_weather
  SELECT DATE, STATION, NAME, LATITUDE, LONGITUDE, ELEVATION, AWND, PRCP, SNOW, SNWD, TMAX, TMIN
  FROM   'nyc-taxi/central-park-weather-2024.csv';

-- Load taxi zone data from shapefile, convert coordinate system
SET geometry_always_xy = false;
INSERT INTO zones
  SELECT z.LocationID, z.Borough, z.Zone,
         ST_Transform(shp.geom, 'ESRI:102718', 'EPSG:4326') AS geometry,
         ST_X(ST_Centroid(geometry)),
         ST_Y(ST_Centroid(geometry))
  FROM   'nyc-taxi/taxi_zone_lookup.csv' AS z LEFT JOIN 'nyc-taxi/taxi_zones.shp' AS shp
         ON (z.LocationID = shp.OBJECTID);

-- Load raw NYC taxi data for 2024
-- (sleep between downloads in order to not overwhelm cloudfront.net)
PREPARE nyc AS
  COPY rides
  FROM ('https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-' || $1 || '.parquet');

EXECUTE nyc('01');
.shell sleep 30
EXECUTE nyc('02');
.shell sleep 30
EXECUTE nyc('03');
.shell sleep 30
EXECUTE nyc('04');
.shell sleep 30
EXECUTE nyc('05');
.shell sleep 30
EXECUTE nyc('06');
.shell sleep 30
EXECUTE nyc('07');
.shell sleep 30
EXECUTE nyc('08');
.shell sleep 30
EXECUTE nyc('09');
.shell sleep 30
EXECUTE nyc('10');
.shell sleep 30
EXECUTE nyc('11');
.shell sleep 30
EXECUTE nyc('12');

-- Remove rows with bogus pickup/dropoff times
DELETE FROM rides AS r
WHERE  r.pickup_at  NOT BETWEEN '2023-12-31 00:00:00' AND '2025-01-01 23:59:59'
OR     r.dropoff_at NOT BETWEEN '2023-12-31 00:00:00' AND '2025-01-01 23:59:59';

SUMMARIZE central_park_weather;
SUMMARIZE zones;
SUMMARIZE rides;

-- Hello Taxi!
