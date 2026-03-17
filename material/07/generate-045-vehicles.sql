-- Recreate the well-known vehicles + peeps (drivers) tables.

DETACH DATABASE IF EXISTS vehices;

.shell rm -f 045-vehicles.db

ATTACH '045-vehicles.db' AS vehicles;
USE vehicles;

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
