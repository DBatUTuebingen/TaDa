-- 006-finite-state-machine.sql

-- Table states and transitions jointly define a finite state machine (FSM)
-- that accepts metric lengths (e.g., '2mm', '135km', '3cm', '42m').

-- FSM states
CREATE OR REPLACE TABLE states (
  state    int PRIMARY KEY,                 -- state ID
  "start?" boolean NOT NULL DEFAULT false,  -- is this the start state?
  "final?" boolean NOT NULL DEFAULT false   -- is this a final state?
);

DESCRIBE states;

INSERT INTO states(state, "start?", "final?") VALUES
  (1,  true, false),  -- state s₁ is the starting state
  (2, false, false),
  (3, false, true ),
  (4, false, false),
  (5, false, true );
--      🡑
  -- NB. A row-based constraint CANNOT express that exactly one state
  -- is marked as the starting state.  Such a constraint would need
  -- to expressed at the table level

FROM states;

-- FSM transitions between states, initiated when one
-- of the characters in list labels is encountered
CREATE OR REPLACE TABLE transitions (
  "from" int    NOT NULL REFERENCES states(state),  -- origin state
  "to"   int    NOT NULL REFERENCES states(state),  -- target state
  labels text[] NOT NULL,                           -- list of input characters
  PRIMARY KEY ("from", "to")
);

DESCRIBE transitions;


-- SQL Syntax:
--
-- For any type ‹t›, ...
-- - ‹t›[]    denotes the type of list of ‹t› elements (arbitrary length)
-- - ‹t›[‹n›] denotes the type of array of ‹t› elements (fixed length ‹n›)
--
-- List/array literals: [‹expr₁›, ‹expr₂›, ...]
--
-- See https://duckdb.org/docs/stable/sql/data_types/list.html


INSERT INTO transitions("from", "to", labels) VALUES
  (1, 2, ['0','1','2','3','4','5','6','7','8','9']),
  (2, 2, ['0','1','2','3','4','5','6','7','8','9']),
  (2, 3, ['m']),
  (2, 4, ['c','k']),
  (3, 5, ['m']),
  (4, 5, ['m']);

FROM transitions;

-- DuckDB specifics:
--
-- DuckDB comes with a rich library of built-in text functions
-- (many of which we will pick up during the course).
--
-- Example: string_split('0123456789', '') ≡ ['0','1','2','3','4','5','6','7','8','9']
--
-- See https://duckdb.org/docs/stable/sql/functions/char.html

SELECT string_split('0123456789', '');

------------------------------------------------------------------------

-- There is an alternative design for table transitions that does not
-- rely on lists.  Instead, each transition from state ‹s₁› to state ‹s₂›
-- on input character ‹c› is encoded as a row (‹s₁›, ‹s₂›, ‹c›):

CREATE OR REPLACE TABLE transitions (
  "from" int  NOT NULL REFERENCES states(state),  -- origin state
  "to"   int  NOT NULL REFERENCES states(state),  -- target state
  label  text NOT NULL,                           -- input character
  PRIMARY KEY ("from", label)  -- ⚠️ (from,to) is not a key anymore but
                               --     (from,label) is unique: this is a
                               --     DETERMINISTIC finite state machine
);

INSERT INTO transitions("from", "to", label) VALUES
  (1, 2, '0'),  -- ┐
  (1, 2, '1'),  -- │
  (1, 2, '2'),  -- │
  (1, 2, '3'),  -- │
  (1, 2, '4'),  -- │ these ten rows jointly define the
  (1, 2, '5'),  -- │ FSM transition s₁ --[0...9]--> s₂
  (1, 2, '6'),  -- │
  (1, 2, '7'),  -- │
  (1, 2, '8'),  -- │
  (1, 2, '9'),  -- ┘
  (2, 2, '0'),
  (2, 2, '1'),
  (2, 2, '2'),
  (2, 2, '3'),
  (2, 2, '4'),
  (2, 2, '5'),
  (2, 2, '6'),
  (2, 2, '7'),
  (2, 2, '8'),
  (2, 2, '9'),
  (2, 3, 'm'),
  (2, 4, 'c'),
  (2, 4, 'k'),
  (3, 5, 'm'),
  (4, 5, 'm');

-- Is this a worse table design since it requires 25 rows (instead of 6)?
-- Not necessarily:
-- - DBMSs are built to process multi-million row tables efficiently.
-- - The simpler the column types, the more efficient can we expect
--   queries to run.
