"""Load Cricsheet ball-by-ball JSON into DuckDB.

Reads every Cricsheet JSON match under data/, either loose .json files
(e.g. data/ipl/, data/t20i/) or .json files inside .zip archives
(e.g. data/all_json.zip), keeps men's IPL and men's T20 internationals,
and writes two tables to cricket.duckdb:

    matches     one row per match
    deliveries  one row per ball (including wides, no-balls and super overs)

then runs sql/00_views.sql to create the deliveries_enriched view.

The database is rebuilt from scratch on every run.

Usage:
    python etl/load.py
"""

import json
import zipfile
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
DB_PATH = ROOT / "cricket.duckdb"
VIEWS_SQL = ROOT / "sql" / "00_views.sql"


def competition_of(info):
    """Return 'IPL', 'T20I', or None if the match is out of scope."""
    if info.get("gender") != "male":
        return None
    if info.get("event", {}).get("name") == "Indian Premier League":
        return "IPL"
    # Cricsheet labels official T20 internationals as match_type 'T20' with
    # team_type 'international'. 'IT20' (non-official internationals) is excluded.
    if info.get("match_type") == "T20" and info.get("team_type") == "international":
        return "T20I"
    return None


def iter_match_files():
    """Yield (match_id, raw JSON text) for every Cricsheet JSON file under data/."""
    seen = set()
    for path in sorted(DATA_DIR.rglob("*")):
        if path.suffix == ".json":
            if path.stem not in seen:
                seen.add(path.stem)
                yield path.stem, path.read_text(encoding="utf-8")
        elif path.suffix == ".zip":
            with zipfile.ZipFile(path) as z:
                for name in z.namelist():
                    stem = Path(name).stem
                    if name.endswith(".json") and stem not in seen:
                        seen.add(stem)
                        yield stem, z.read(name).decode("utf-8")


def parse_match(match_id, info, innings_list):
    """Flatten one match into a matches row and a list of deliveries rows."""
    outcome = info.get("outcome", {})
    by = outcome.get("by", {})
    toss = info.get("toss", {})
    teams = info.get("teams", [None, None])

    # Target set for the side batting second (accounts for DLS-revised targets).
    target = {}
    for inn in innings_list:
        if "target" in inn and not inn.get("super_over"):
            target = inn["target"]
            break

    match_row = {
        "match_id": match_id,
        "competition": competition_of(info),
        "season": str(info.get("season")),
        "year": int(info["dates"][0][:4]),
        "date": info["dates"][0],
        "event_name": info.get("event", {}).get("name"),
        "match_number": info.get("event", {}).get("match_number"),
        "stage": info.get("event", {}).get("stage"),
        "city": info.get("city"),
        "venue": info.get("venue"),
        "team1": teams[0],
        "team2": teams[1],
        "toss_winner": toss.get("winner"),
        "toss_decision": toss.get("decision"),
        # For ties settled by a super over, Cricsheet records the winner as 'eliminator'.
        "winner": outcome.get("winner") or outcome.get("eliminator"),
        "result": outcome.get("result", "win" if outcome.get("winner") else None),
        "win_by_runs": by.get("runs"),
        "win_by_wickets": by.get("wickets"),
        "method": outcome.get("method"),
        "overs_limit": info.get("overs"),
        "target_runs": target.get("runs"),
        "target_overs": target.get("overs"),
        "player_of_match": ", ".join(info.get("player_of_match", [])) or None,
    }

    registry = info.get("registry", {}).get("people", {})
    delivery_rows = []
    for innings_no, inn in enumerate(innings_list, start=1):
        is_super_over = bool(inn.get("super_over"))
        for over in inn.get("overs", []):
            for ball_seq, d in enumerate(over["deliveries"], start=1):
                extras = d.get("extras", {})
                wickets = d.get("wickets", [])
                first_wicket = wickets[0] if wickets else {}
                delivery_rows.append({
                    "match_id": match_id,
                    "innings": innings_no,
                    "is_super_over": is_super_over,
                    "batting_team": inn["team"],
                    "over_num": over["over"] + 1,  # Cricsheet overs are 0-based; store 1-20
                    "ball_seq": ball_seq,          # position in the over, counting wides/no-balls
                    "batter": d["batter"],
                    "bowler": d["bowler"],
                    "non_striker": d["non_striker"],
                    "batter_id": registry.get(d["batter"]),
                    "bowler_id": registry.get(d["bowler"]),
                    "runs_batter": d["runs"]["batter"],
                    "runs_extras": d["runs"]["extras"],
                    "runs_total": d["runs"]["total"],
                    "extras_wides": extras.get("wides", 0),
                    "extras_noballs": extras.get("noballs", 0),
                    "extras_byes": extras.get("byes", 0),
                    "extras_legbyes": extras.get("legbyes", 0),
                    "extras_penalty": extras.get("penalty", 0),
                    "is_wide": "wides" in extras,
                    "is_noball": "noballs" in extras,
                    # A handful of balls have two dismissals; the first is stored here
                    # and wicket_count records how many fell.
                    "wicket_count": len(wickets),
                    "wicket_kind": first_wicket.get("kind"),
                    "player_out": first_wicket.get("player_out"),
                })
    return match_row, delivery_rows


def main():
    match_rows, delivery_rows = [], []
    scanned = 0
    for match_id, text in iter_match_files():
        scanned += 1
        data = json.loads(text)
        info = data["info"]
        if competition_of(info) is None:
            continue
        m, ds = parse_match(match_id, info, data.get("innings", []))
        match_rows.append(m)
        delivery_rows.extend(ds)

    if not match_rows:
        raise SystemExit(f"No IPL or men's T20I matches found under {DATA_DIR}")

    matches = pd.DataFrame(match_rows)
    matches["date"] = pd.to_datetime(matches["date"]).dt.date
    deliveries = pd.DataFrame(delivery_rows)

    DB_PATH.unlink(missing_ok=True)
    con = duckdb.connect(str(DB_PATH))
    con.execute("CREATE TABLE matches AS SELECT * FROM matches ORDER BY date, match_id")
    con.execute(
        "CREATE TABLE deliveries AS SELECT * FROM deliveries "
        "ORDER BY match_id, innings, over_num, ball_seq"
    )
    # Recreate the shared views (deliveries_enriched) on top of the fresh tables.
    con.execute(VIEWS_SQL.read_text(encoding="utf-8"))
    con.close()

    counts = matches["competition"].value_counts()
    print(f"Scanned {scanned:,} files -> {DB_PATH.name}")
    print(f"  matches:    {len(matches):,}  (IPL {counts.get('IPL', 0):,}, T20I {counts.get('T20I', 0):,})")
    print(f"  deliveries: {len(deliveries):,}")
    print(f"  dates:      {matches['date'].min()} to {matches['date'].max()}")


if __name__ == "__main__":
    main()
