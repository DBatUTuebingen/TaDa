
# **Ta**bular **Da**tabase Systems (*TaDa*)

A DuckDB-based course on the fundamentals of relational database
management systems and SQL.

## Welcome!

This lecture material has been developed by [Torsten Grust](https://db.cs.uni-tuebingen.de/grust/)
to support a 15-week course (coined *TaDa*) for undergraduate students of
the [Database Research Group](https://db.cs.uni-tuebingen.de) at
University of Tübingen (Germany).  You are welcome to use this
material in any way you may see fit: skim it, study it, send suggestions
or corrections, or tear it apart to build your own lecture material
based on it.  I would be delighted to hear from you in any case:

- E-Mail: [torsten.grust@uni-tuebingen.de](mailto:torsten.grust@uni-tuebingen.de)
- Web: https://db.cs.uni-tuebingen.de/grust/
- Bluesky: https://bsky.app/profile/teggy.org

## A DuckDB-Based Introduction to Tabular Data and SQL

As a member of the decades-old family of relational database
management systems, [DuckDB](https://duckdb.org/) is an expert in
processing tabular data (or: tables, relations).   DuckDB is a
capable and very efficient
SQL database system that can
[crunch billions of rows on commodity laptops](https://blobs.duckdb.org/merch/duckdb-2024-big-data-on-your-laptop-poster.pdf).
Its SQL dialect is versatile, complete, and [remarkably *friendly*](https://duckdb.org/docs/current/sql/dialect/friendly_sql).
[DuckDB is a breeze to install](https://duckdb.org/install/) ~~and maintain~~,
open for tinkering and inspection, has developed an open and supportive community
since its inception in 2019,
and thus makes for an ideal vehicle for an introduction
into the world of contemporary tabular database system technology.

15 weeks hardly suffice to exhaustively cover a field that has developed
since the early 1970s, but I still hope that the topics covered in *TaDa*
will pave a path from which you can easily branch off to get lost in the depths
of [Ted Codd's](https://en.wikipedia.org/wiki/Edgar_F._Codd) jungle.
A future *TaDa* may see chapters added, merged, or removed but as of
March 2026, the chapter layout reads as follows:

1. Tabular Data and Database Systems
2. Tabular Data in CSV Files
3. Reading Data at the Speed of ~~Light~~Memory
4. Columnar Table Storage
5. Database-External Data in Parquet Files
6. The Structured Query Language (SQL)
7. More SQL (Subqueries + Embedded SQL)
8. SQL: Grouping + Aggregation and Functional Dependencies

Here at U Tübingen, I walk students through these chapters front to
back.

We do not assume any prior SQL skills.  Chapters 03 and 07 will have you read
and modify short pieces of C, Python, or awk code.  There will be only
fleeting glimpses at the internals of DuckDB.  If the innards of The
Duck catch your interest, you may find the companion course
[*DiDi*](https://github.com/DBatUTuebingen/DiDi) on selected internals
of the DuckDB kernel helpful.

## *TaDa* = Slides + Auxiliary Material

Chapter ‹N› of *TaDa* comes with a slide set in file `slides/TaDa-‹N›.pdf`
(see the hierachy of relevant files below).  Note that these slide sets
literally only tell half of the story.

The other half is found in 50+
auxiliary files—mostly SQL scripts, but also code written in C,
Python, and awk—collected in directory `material/‹N›/` for Chapter ‹N›.
The slides contain tags `📄#‹nnn›` whenever a file
named `‹nnn›-*` contains relevant supporting material. Beyond code, these
files contains plenty of commentary—**you absolutely *need* to study (and ideally run,
modify, play with) these files in `material/` to obtain the intended and complete
*TaDa* picture.**

To run these files, change into the `material/‹N›/` directory and invoke
DuckDB, your Python/awk interpreter, or C compiler there.  For example:

~~~
$ cd material/03
$ duckdb -f generate-lineitem.sql
$ ./013-sum-quantity.py lineitem.csv
$ duckdb -f 020-sum-quantity.sql
$ duckdb
D .read 020-sum-quantity.sql
~~~

I have found that students make best use of the SQL scripts when
they cut & paste individual SQL commands and queries from the `*.sql`
files right into a [DuckDB CLI](https://duckdb.org/docs/current/clients/cli/overview) session.

### Generating Sample Database Instances

Some of the SQL scripts operate over CSV files or persistent DuckDB database
(stored in `*.db` files).  Should such data sources be needed, the
`material/‹N›/` subdirectories contain `generate-*.sql` scripts that will
generate the required CSV or database files in the current directory.  Example:

~~~
$ cd material/07
$ duckdb -f generate-045-vehicles.sql
$ ls -lh 045-vehicles.db
-rw-r--r--  1 grust  staff   1.5M Mar 19 10:07 045-vehicles.db
~~~

## Credits

The *TaDa* material stands on the shoulders of

- a variety of scientific papers (which we mention and link to on the slides),
- the DuckDB documentation at https://duckdb.org/docs/,
- blog posts (mostly found on https://duckdb.org/news/),
- discussions on the friendly DuckDB Discord (https://discord.duckdb.org/),
- personal communication (over Discord and beers) with the awesome
  bunch of DuckDB developers at [DuckDB Labs](https://duckdblabs.com),
- SQL references/standards,
- experience, and best practices.

Chapter 03 (Reading Data at the Speed of ~~Light~~Memory) is an adaptation and
extension of a discussion found in Thomas Neumann's fabulous lecture notes
on [Foundations in Data Engineering](https://db.in.tum.de/teaching/ws2425/foundationsde/?lang=en).

The slides were authored using (a heavily modified version of) Morgan McGuire's
Markdown dialect [Markdeep](https://casual-effects.com/markdeep/).
I used Fabrizio Schiavi's fixed-width [Pragmata Pro](https://fsd.it/shop/fonts/pragmatapro/) fonts
for typesetting.


## *TaDa* File Layout

~~~
.
└── slides
│   ├── TaDa-01.pdf
│   ├── TaDa-02.pdf
│   ├── TaDa-03.pdf
│   ├── TaDa-04.pdf
│   ├── TaDa-05.pdf
│   ├── TaDa-06.pdf
│   ├── TaDa-07.pdf
│   └── TaDa-08.pdf
├── material
│   ├── 01
│   │   ├── 001-create-table.sql
│   │   ├── 002-rock-paper-scissors.sql
│   │   ├── 003-primary-keys.sql
│   │   ├── 004-good-keys.sql
│   │   ├── 005-foreign-keys.sql
│   │   └── 006-finite-state-machine.sql
│   ├── 02
│   │   ├── 007-vehicles.csv -> vehicles.csv
│   │   ├── 008-read_csv.sql
│   │   ├── 009-gsheets.sql
│   │   ├── 010-copy-from-to.sql
│   │   ├── 011-csv-sniffing.sql
│   │   ├── band.csv
│   │   ├── capacity.tsv
│   │   ├── drivers.csv
│   │   ├── flights.csv
│   │   ├── generate-lineitem.sql
│   │   ├── StarWars-EpisodeIV.txt
│   │   └── vehicles.csv
│   ├── 03
│   │   ├── 012-sum-quantity.awk
│   │   ├── 013-sum-quantity.py
│   │   ├── 014-sum-quantity.c
│   │   ├── 015-sum-quantity-mmap.c
│   │   ├── 016-bit-twiddling.c
│   │   ├── 017-sum-quantity-mmap-block.c
│   │   ├── 018-sum-quantity-mmap-threads.c
│   │   ├── 019-aggregates.sql
│   │   ├── 020-sum-quantity.sql
│   │   └── generate-lineitem.sql
│   ├── 04
│   │   ├── 021-databases.sql
│   │   ├── 022-row-groups.sql
│   │   └── 023-compression.sql
│   ├── 05
│   │   ├── 024-parquet.sql
│   │   ├── 025-pushdown.sql
│   │   ├── 026-bloom-filters.sql
│   │   └── 027-hive-partitioning.sql
│   ├── 06
│   │   ├── 028-row-variables.sql
│   │   ├── 029-cross-products.sql
│   │   ├── 030-inner-join.sql
│   │   ├── 031-outer-join.sql
│   │   ├── 032-semi-anti-join.sql
│   │   ├── 033-join-plans.sql
│   │   ├── 034-bag-algebra.sql
│   │   └── 035-starwars.db
│   ├── 07
│   │   ├── 036-subqueries.sql
│   │   ├── 037-correlation.sql
│   │   ├── 038-decorrelation.sql
│   │   ├── 039-table-valued.sql
│   │   ├── 040-quantification.sql
│   │   ├── 042-embedded.py
│   │   ├── 043-embedded-types.py
│   │   ├── 044-construction.py
│   │   ├── 046-n-plus-one.py
│   │   ├── compositionality.py
│   │   ├── generate-041-railway.sql
│   │   └── generate-045-vehicles.sql
│   └── 08
│       ├── 047-grouping.sql
│       ├── 048-grouping-quiz.sql
│       ├── 049-granularity.sql
│       ├── 050-nyc-taxi.sql
│       ├── 052-grouping.py
│       ├── 053-grouping-and-fds.sql
│       ├── 054-fds-having.sql
│       ├── 055-fd-split.sql
│       ├── 056-views.sql
│       ├── generate-051-nyc-taxi.sql
│       └── nyc-taxi
│           ├── central-park-weather-2024.csv
│           ├── taxi_zone_lookup.csv
│           ├── taxi_zones.dbf
│           ├── taxi_zones.shp
│           └── taxi_zones.shx
├── README.md
└── LICENSE
~~~
