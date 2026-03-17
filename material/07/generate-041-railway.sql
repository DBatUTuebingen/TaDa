-- Read Rijden de Treinen (RDT) CSV file, normalize schemata, generate a
-- native DuckDB 041-railway.db database file.
--
-- Data source: Rijden de Treinen (train archive)
--              https://www.rijdendetreinen.nl/en/open-data

DETACH DATABASE IF EXISTS railway;

.shell rm -f 041-railway.db

ATTACH '041-railway.db' AS railway;
USE railway;

-- Grap the RDT Train Archive of April 2025 (about 1.9 millions rows)
CREATE OR REPLACE TEMP TABLE services AS
  FROM 'https://opendata.rijdendetreinen.nl/public/services/services-2025-04.csv.gz';

-- Resulting DB schema:
--
-- trains(ID, SERVICE, date, type, company, completely_cancelled, partly_cancelled, max_delay)
-- stops((ID, SERVICE) -> trains,STATION -> stations, arrival, arrival_delay, arrival_cancelled, departure, departure_delay, departure_cancelled)
-- stations(STATION, name)

  -- train services
CREATE OR REPLACE TABLE trains (
 id                   int,      -- train ID
 service              int,      -- service # (e.g., as listed in timetables)
 date                 date,     -- day of service
 type                 text,     -- Sprinter, EuroCity, Sneltrein, ...
 company              text,     -- railway company (NS, DB, ...)
 completely_cancelled boolean,
 partly_cancelled     boolean,
 max_delay            int,      -- across all stops (in minutes)
 PRIMARY KEY (id, service)      -- a service may be split into two train IDs
);

INSERT INTO trains
  SELECT s."Service:RDT-ID"               AS id,
         s."Service:Train number"         AS service,
         s."Service:Date"                 AS date,
         s."Service:Type"                 AS type,
         s."Service:Company"              AS company,
         s."Service:Completely cancelled" AS completely_cancelled,
         s."Service:Partly cancelled"     AS partly_cancelled,
         max(s."Service:Maximum delay")   AS max_delay
  FROM services AS s
  GROUP BY id, service, date, type, company, completely_cancelled, partly_cancelled;

SUMMARIZE trains;

-- stations
CREATE OR REPLACE TABLE stations (
  station text PRIMARY KEY,   -- abbreviated station code (AMS, HGLO, BASELB, ...)
  name    text                -- full station name
);

INSERT INTO stations
  SELECT DISTINCT s."Stop:Station code" AS station,
                  s."Stop:Station name" AS name
  FROM services AS s;

SUMMARIZE stations;

-- stops
CREATE OR REPLACE TABLE stops (
  id                  int,         -- train ID
  service             int,         -- service #
  station             text,        -- station code
  arrival             timestamp,   -- NULL if no arrival scheduled
  arrival_delay       int,         -- in minutes
  arrival_cancelled   boolean,
  departure           timestamp,   -- NULL if no departure scheduled
  departure_delay     int,
  departure_cancelled boolean,
  PRIMARY KEY (id, service, station),
  FOREIGN KEY (id, service) REFERENCES trains,  -- ⚠️ leads to spurious bogus
  FOREIGN KEY (station) REFERENCES stations     --     constraint errors (DuckDB bug?)
);

INSERT INTO stops
  SELECT s."Service:RDT-ID"           AS id,
         s."Service:Train number"     AS service,
         s."Stop:Station code"        AS station,
         s."Stop:Arrival time"        AS arrival,
         s."Stop:Arrival delay"       AS arrival_delay,
         s."Stop:Arrival cancelled"   AS arrival_cancelled,
         s."Stop:Departure time"      AS departure,
         s."Stop:Departure delay"     AS departure_delay,
         s."Stop:Departure cancelled" AS departure_cancelled
  FROM   services AS s;

SUMMARIZE stops;

-- Enjoy the ride.
