-- Use DuckDB as a processor for database-external CSV files
--
-- + We get to use expressive/efficientSQL to query/transform CS files.
-- - We pay for the CSV import and export effort (aka serialization effort).

CREATE OR REPLACE TABLE vehicles (
  vehicle   text    NOT NULL,
  kind      text    NOT NULL,
  seats     int             ,
  "wheels?" boolean
);

-- instance: empty
FROM vehicles;

--Import CSV file into existing database-resident table vehicles
COPY vehicles
FROM 'vehicles.csv' (delim ', ', nullstr ' ');
-- Check that the CSV data has been imported as expected
FROM vehicles;

-- Query vehicles
SELECT vehicle, kind, bar(seats,0,50,30) AS capacity
FROM   vehicles
WHERE  "wheels?"
ORDER BY seats DESC;

-- Export query results to file capacity.tsv (TAB-separated values)
COPY (SELECT  vehicle, kind, bar(seats,0,50,30) AS capacity
      FROM    vehicles
      WHERE   "wheels?"
      ORDER BY seats DESC)
TO   'capacity.tsv' (header false, delim '\t');

/* In your shell, print the contents of capacity.tsv to find:

󰞞      bus     █████████████████████████▏
󰟺      bus     ████▏
󰞫      car     ███
󱔭      SUV     █▊
󰞧      cabrio  █▏
󰍼      bike    ▌

*/

------------------------------------------------------------------------

-- DuckDB's gsheets (Google Sheets) extension allows to read AND (over)write
-- spreadsheets via COPY ... TO

-- If required: install/load gsheets + authenticate
INSTALL gsheets FROM community;
LOAD gsheets;

CREATE OR REPLACE SECRET (TYPE gsheet);

-- Read the main sheet of the vehicles spreadsheet,
-- write query result to the capacity sheet.
--
-- (Re-evaluate this query with ordering modifiers DESC/ASC to watch
-- the sheet update on the fly)
COPY (SELECT vehicle, kind, bar(seats,0,50,30) AS capacity
      FROM   'https://docs.google.com/spreadsheets/d/1ouTnZmEwWEg1pm9WMJ0Y0cFYtQ0ujeN3Ia8mFhACEgY/edit'
      WHERE  "wheels?"
      ORDER BY seats DESC)
TO    'https://docs.google.com/spreadsheets/d/1ouTnZmEwWEg1pm9WMJ0Y0cFYtQ0ujeN3Ia8mFhACEgY/edit'
      (format gsheet, sheet 'capacity');
