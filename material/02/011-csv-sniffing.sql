-- Demonstrate the operation of DuckDB's sophisticated CSV sniffer.
--
-- This is based on CSV two sample input files: flight.csv, band.csv.

-- Read CSV file, do not provide configuration parameters:
-- the CSV sniffer will use its auto-detection capabilities
-- (in particular for delimiter detection):
FROM 'flights.csv';               -- OK
FROM read_csv('flights.csv');     -- OK

-- Override delimiter detection, try delimiters ',' and ';'

-- ',' splits row 2-4 into three columns, this does not fit
-- the first row (single column) which thus is skipped. The
-- first fitting row (row 2) thus is assumed to be the header:
FROM read_csv('flights.csv', delim =',');                   -- uh oh
FROM read_csv('flights.csv', delim =',', header = false);   -- uh oh

-- ';' leads to rows 1-4 to have a single column only, this
-- fits the first row which is assumed to be the header:
FROM read_csv('flights.csv', delim =';');                   -- uh oh
FROM read_csv('flights.csv', delim =';', header = false);   -- uh oh

------------------------------------------------------------------------

-- Read CSV file, use sniffing to detect dialect and types
FROM 'band.csv';               -- OK
FROM read_csv('band.csv');     -- OK

-- Note that the comment line in the first line is correctly skipped
-- by the CSV sniffer.  ⚠️ Add a ',' in that line to see the sniffer
-- trip. (Possible repair: use configuration parameter skip = 1)

-- Provide explicit type hints for columns, values found in the CSV file
-- will be casted if possible:
FROM read_csv('band.csv', types = ['text', 'int']);     -- OK
FROM read_csv('band.csv', types = ['text', 'boolean']); -- uh oh


------------------------------------------------------------------------

-- Analysis of CSV read operations

-- A summary of the CSV sniffer's view of the file can be obtained
-- using the built-in function sniff_csv(‹CSV file name›):

.columns

FROM sniff_csv('flights.csv');    -- Delimiter '|', HasHeader true, SkipRows 0
FROM sniff_csv('band.csv');       -- Delimiter ',', Columns (types), SkipRows 1

.rows

-- DuckDB specifics:
--
-- - Use DuckDB shell command .columns to vertically display the
--   columns in a (very wide) table.
-- - Use command .rows to return to the default row-wise table display.


-- Obtain a detailed analysis of where and why rows led to error during
-- CSV reading:
--
-- 1. set configuration parameter store_rejects = true
-- 2. Query DuckDB's built-in tables reject_scans and reject_errors

-- This will fail (see above) since the second column cannot be cast
-- to boolean. Ask the sniffer to log the rejected rows in table reject_errors:
FROM read_csv('band.csv', types = ['text', 'boolean'], store_rejects = true);

-- Consult the log of rejected rows:
FROM reject_scans;   -- log of failed CSV reading operations
FROM reject_errors;  -- detailed log of rejected rows
