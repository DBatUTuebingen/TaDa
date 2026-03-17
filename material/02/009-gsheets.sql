-- Use DuckDB's Google Sheets community extension gsheets to directly
-- access Google Sheets spreadsheets, avoiding explicit CSV download/import
-- steps.
--
-- See https://duckdb.org/community_extensions/extensions/gsheets.html

-- Install and load the gsheets extension
INSTALL gsheets FROM community;
LOAD gsheets;

-- Authenticate at Google (will open a browser window at duckdb-gsheets.com),
-- copy the authorization token and paste it at the DuckDB CLI prompt:
--
--   Visit the below URL to authorize DuckDB GSheets
--   ...
--   After granting permission, enter the token: ‹paste token {{here}}›
--
-- Should return singleton table with boolean column "Success".
CREATE SECRET (TYPE gsheet);

-- Read the vehicles spreadsheet
FROM 'https://docs.google.com/spreadsheets/d/1ouTnZmEwWEg1pm9WMJ0Y0cFYtQ0ujeN3Ia8mFhACEgY/edit';

SELECT vehicle, kind
FROM   'https://docs.google.com/spreadsheets/d/1ouTnZmEwWEg1pm9WMJ0Y0cFYtQ0ujeN3Ia8mFhACEgY/edit'
WHERE  "wheels?";

-- Edit spreadsheet "bike" → "bicycle", then re-excute the SQL query to
-- see the updated data immediately
FROM 'https://docs.google.com/spreadsheets/d/1ouTnZmEwWEg1pm9WMJ0Y0cFYtQ0ujeN3Ia8mFhACEgY/edit';
