# Cricket Analytics: What Wins T20 Games?

SQL analytics on Cricsheet ball-by-ball data for the IPL and T20 internationals: a DuckDB data model, seven questions answered with CTEs and window functions, and an interactive website with the results and a lookup for 3,300+ players.

**🔗 [View the interactive results →](https://ananyaasubramanian.github.io/cricket-analytics/)**

> **Headline finding:** AB de Villiers has the best death-over strike rate in IPL history: **222.9** in overs 16–20 (1,868 runs off 838 balls), 20 points clear of the next best, Rishabh Pant (202.8). Minimum 300 balls.

**Stack:** DuckDB · SQL · Python · HTML/JavaScript (GitHub Pages)

---

## 1. The question

What separates winning T20 performances from losing ones, and which players deliver when it matters most?

Seven questions answered in SQL:

| # | Question | Main SQL technique |
| --- | --- | --- |
| 1 | Who has the best strike rate in the death overs (16–20), all time and since 2022? | CTE + `RANK()` over `PARTITION BY` period and competition |
| 2 | Which bowler-vs-batter matchups are the most one-sided? | Multi-CTE aggregation, `HAVING` thresholds |
| 3 | How do batters perform in high-pressure chases (required rate > 10)? | Running totals with `SUM() OVER (ORDER BY …)` |
| 4 | Which bowlers are most economical in each phase (powerplay, middle, death)? | `CASE` phase buckets + `PARTITION BY` |
| 5 | Has death-over scoring changed season by season, and does the IPL differ from T20Is? | `LAG()` over seasons |
| 6 | Does winning the toss matter? Is it better to bat first or chase? | `GROUPING SETS` for yearly and all-time totals in one query |
| 7 | Which grounds score highest, and where does chasing win? | Name cleaning with a rename lookup, `FILTER` aggregates |

## 2. The data

- **Source:** [Cricsheet](https://cricsheet.org) ball-by-ball JSON, covering the IPL and T20 internationals (men's). Free and openly licensed.
- **Coverage:** 4,683 matches and 1.07 million deliveries: IPL 2008–2026 (1,243 matches) and men's T20 internationals 2005–2026 (3,440 matches).
- T20Is include associate nations as well as full members, so some leaderboards feature players from teams such as Nepal, Austria or Papua New Guinea. Cricsheet withholds matches involving Afghanistan's men's team.
- **Data model** (DuckDB, `cricket.duckdb`):

| Table | Grain | Key columns |
| --- | --- | --- |
| `matches` | one row per match | `match_id`, `competition` (IPL / T20I), `season`, `year`, `date`, `venue`, `team1`, `team2`, `toss_winner`, `toss_decision`, `winner`, `result`, `method`, `target_runs`, `target_overs` |
| `deliveries` | one row per ball | `match_id`, `innings`, `is_super_over`, `batting_team`, `over_num` (1–20), `ball_seq`, `batter`, `bowler`, `non_striker`, `runs_batter`, `runs_extras`, `runs_total`, `is_wide`, `is_noball`, `wicket_count`, `wicket_kind`, `player_out` |

- Use `year`, not `season`, for IPL seasons: Cricsheet labels some by the year they span (2008 is `2007/08`). Filter `NOT is_super_over` unless you want super overs.

- **Validation:** runs and wickets for 15 innings across 8 landmark matches (including four World Cup finals and the IPL's record totals) match the official scorecards exactly, every ball's runs reconcile, and the only overs longer than six legal balls are 41 genuine umpire miscounts that Cricsheet records (`sql/00_validation.sql`).
- The same database is reused in **Project 3** _[link once it exists]_.

## 3. The method

1. **Load:** `etl/load.py` flattens each match's nested JSON (innings → overs → deliveries) into the two tables.
2. **Define:** every query uses the same cricket definitions:
   - **Balls faced** excludes wides. **Legal balls bowled** exclude wides and no-balls.
   - **Phases:** powerplay is overs 1–6, middle overs are 7–15, death overs are 16–20.
   - **Strike rate** = runs ÷ balls faced × 100. **Economy** = runs conceded ÷ legal overs.
   - **Minimum samples:** 300 death-over balls for batters (Q1), 100 balls in each chase situation (Q3), 300 legal balls per phase for bowlers (Q4), 30 balls for matchups (Q2).
3. **Query:** each question is its own file in `sql/` and is commented so the logic can be read top to bottom.
4. **Visualise:** `etl/export.py` saves each query's results as CSV in `dashboard/data/`, which the [project website](https://ananyaasubramanian.github.io/cricket-analytics/) (`index.html`) reads and charts.

## 4. The answer

| Question | Finding |
| --- | --- |
| Death-over strike rate | AB de Villiers leads the IPL at **222.9** (Pant 202.8, Russell 195.9). In T20Is, Nepal's Dipendra Singh Airee leads at **202.6**, ahead of Glenn Maxwell (197.0). |
| Bowler vs batter matchups | Andre Russell has scored **78 off 30 balls** against Dwayne Bravo (strike rate 260) without being dismissed. On the bowling side, Prasidh Krishna has held Nicholas Pooran to **11 off 30**. |
| Pressure chases | **269 of 301** batters score faster when the required rate is above 10. Phil Salt (189.5) and Tim David (187.7) are the quickest big names under pressure. Corey Anderson has one of the biggest drops, **41 points** slower under pressure. |
| Phase economy | In the IPL, Dale Steyn is the tightest powerplay bowler (**6.26** an over), Munaf Patel the tightest in the middle overs (6.02), and Sunil Narine at the death (**7.25**, ahead of Malinga 7.86 and Bumrah 8.19). |
| Death-over scoring trend | IPL death overs went from **9.95** runs an over in 2008 to a peak of **11.21** in 2024, with boundaries rising from about 1 ball in 5 to 1 in 4. T20Is fell from 9.89 (2018) to about 8.5 as associate matches grew from 72 to 575 a year. |
| Toss | Barely matters: toss winners win **51.6%** of IPL matches and 50.4% of T20Is. Chasing wins 54.7% of IPL matches, yet IPL captains now bowl first after **83%** of tosses (2025–26), up from 34% in 2010. |
| Venues | Of IPL grounds with 40+ matches, Narendra Modi Stadium has the highest average first-innings score (**183.8**); chasing does best at Sawai Mansingh Stadium, Jaipur (**65.2%** of decided matches). |

**So what:** Death overs are where T20 games are won, and they are getting more expensive: IPL teams now score 11 an over at the death. Only two bowlers with 50+ IPL death overs concede under 8 an over there, Narine (7.25) and Malinga (7.86), which makes elite death bowlers as valuable to recruit as elite death hitters. Matchup and pressure splits then give captains and fantasy players a way to plan who bowls, and who bats, when a game is tight.

## 5. What I'd do next

- Adjust for context: normalise for venue and season scoring levels so eras compare fairly
- Add other T20 leagues (BBL, PSL, MLC) through the same pipeline
- Build a ball-by-ball win-probability model on this database (**Project 3**)
- Automate the refresh so new Cricsheet matches load on a schedule

---

## Run it yourself

```bash
git clone https://github.com/AnanyaASubramanian/cricket-analytics.git
cd cricket-analytics
pip install duckdb pandas

# Download "IPL" and "T20 Internationals" (JSON) from cricsheet.org/downloads
# and unzip them into data/ipl/ and data/t20i/, or put all_json.zip in data/
python etl/load.py

duckdb cricket.duckdb < sql/01_death_strike_rate.sql

# Export every query's results to dashboard/data/*.csv, then redraw the preview image
python etl/export.py
python etl/make_preview.py

# Preview the website at http://localhost:8000
python -m http.server
```

## Repo structure

```text
cricket-analytics/
├── etl/
│   ├── load.py                  # JSON → DuckDB
│   ├── export.py                # query results → CSV + meta.json
│   └── make_preview.py          # link-preview image for social sharing
├── sql/
│   ├── 00_views.sql             # shared definitions (deliveries_enriched)
│   ├── 00_validation.sql        # totals vs scorecards
│   ├── 01_death_strike_rate.sql
│   ├── 02_matchups.sql
│   ├── 03_pressure_chases.sql
│   ├── 04_phase_economy.sql
│   ├── 05_death_scoring_trend.sql
│   ├── 06_toss_impact.sql
│   ├── 07_venues.sql
│   ├── 08_player_profiles.sql   # feeds the website's player lookup
│   └── 09_matchup_pairs.sql     # feeds the player cards' matchups
├── dashboard/
│   └── data/                    # exported CSVs (read by the website)
├── data/                        # raw Cricsheet files (git-ignored)
├── assets/preview.png           # link-preview image
├── index.html                   # project website (GitHub Pages)
└── README.md
```

## Data credit

Ball-by-ball data from [Cricsheet](https://cricsheet.org), maintained by Stephen Rushe.
