"""Export each analysis query's results to CSV for the Tableau dashboard.

Runs every sql/01_*.sql ... sql/05_*.sql file against cricket.duckdb and writes
the result to dashboard/data/<same name>.csv. The 00_ files (view definition
and validation checks) are not exported.

The database is opened read-only. DuckDB lets only one program write to the
file at a time, so close DBeaver first (Cmd+Q) if this fails with a lock error.

Usage:
    python etl/export.py
"""

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "cricket.duckdb"
SQL_DIR = ROOT / "sql"
OUT_DIR = ROOT / "dashboard" / "data"


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH), read_only=True)

    query_files = sorted(p for p in SQL_DIR.glob("0[1-9]_*.sql"))
    if not query_files:
        raise SystemExit(f"No query files found in {SQL_DIR}")

    for sql_file in query_files:
        result = con.sql(sql_file.read_text(encoding="utf-8"))
        out_path = OUT_DIR / f"{sql_file.stem}.csv"
        # DuckDB writes the CSV itself, so whole numbers stay whole (1868, not 1868.0)
        result.write_csv(str(out_path))
        print(f"  {sql_file.name:<32} -> {out_path.relative_to(ROOT)}  ({result.shape[0]} rows)")

    con.close()


if __name__ == "__main__":
    main()
