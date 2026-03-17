-- One DuckDB process can attach to multiple databases at one time
--
-- Run this in a new DuckDB process, started from the shell via "duckdb"
-- (no arguments)
--
-- Show all connected databases (will only show the
-- transient in-memory DB aptly named "memory")
SHOW DATABASES;

-- DB memory currently is the default (and only) DB, all tables
-- will be created in that DB.

-- Humanity's hardest questions...
CREATE OR REPLACE TABLE big_Qs(
  Q       text,
  answer  boolean -- ... and their answers!
);

INSERT INTO big_Qs(Q, answer) VALUES
  ('Do aliens exist?',           true),
  ('Do we have a free will?',    false),
  ('Is there life after death?', NULL);


-- Same (since memory is the default DB)
FROM big_Qs;         -- ─┐
                     --  =
FROM memory.big_Qs;  -- ─┘

-- Now quit this DuckDB process.  ⚠️ All table state and associated
-- definitions (and answers to humanity's hard questions) in transient
-- DB memory will be lost.
.quit

-- Restart DuckDB via "duckdb" and continue below:
SHOW DATABASES;
FROM big_Qs;    --🙈 Oh no!

------------------------------------------------------------------------

-- Now attach to persistent on-disk DB in file 'persistent.db'
-- (will be created if non-existent)
ATTACH 'persistent.db';

-- Check whether the on-disk file has been created
.shell ls -lh

-- Now we're attached to two DBs: memory AND persistent,
-- DB memory remains the default
SHOW DATABASES;

CREATE OR REPLACE TABLE t(in_DRAM boolean);
CREATE OR REPLACE TABLE persistent.t(on_disk boolean);

SHOW ALL TABLES;

-- Access tables named t
FROM t;                -- ─┐
                       --  =
FROM memory.t;         -- ─┘

FROM persistent.t;

-- Now switch default DB to persistent
USE persistent;

-- Again: access tables named t
FROM t;               -- ─┐
                      --  │
FROM memory.t;        --  =
                      --  │
FROM persistent.t;    -- ─┘

------------------------------------------------------------------------

-- Try again in the persistent DB:

-- Humanity's hardest questions...
CREATE OR REPLACE TABLE big_Qs(
  Q       text,
  answer  boolean -- ... and their answers!
);

INSERT INTO big_Qs(Q, answer) VALUES
  ('Do aliens exist?',           true),
  ('Do we have a free will?',    false),
  ('Is there life after death?', NULL);

FROM big_Qs;             -- ─┐
                         --  =
FROM persistent.big_Qs;  -- ─┘

.quit

-- Restart DuckDB via "duckdb persistent.db" and continue below:

SHOW DATABASES;
SHOW ALL TABLES;

-- The big answers did persist!
FROM big_Qs;  -- 🎉

-- Also attach to in-memory DB (if that's needed)
ATTACH ':memory:';   -- ⚠️ NB. special name :memory: tell this apart
                     --    from on-disk file with name "memory"

SHOW DATABASES;

-- Now entirely switch over to in-memory DB again

-- Copy all table states and definitions
COPY FROM DATABASE persistent TO memory;

-- DB memory is the default, detach from persistent
USE memory;
DETACH persistent;

SHOW DATABASES;
SHOW ALL TABLES;
