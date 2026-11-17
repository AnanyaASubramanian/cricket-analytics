# Cricket Analytics: What Wins T20 Games?

SQL analytics on Cricsheet ball-by-ball data for the IPL and T20 internationals: a DuckDB data model, five questions answered with CTEs and window functions, and a published Tableau Public dashboard.

> **Headline finding:** _[One sentence with a number. e.g. "X has the best death-over strike rate in the IPL since 2008 (min. 300 balls) at 2xx, 40 points above the league average."]_


**Stack:** DuckDB · SQL · Python (pandas) · Tableau Public

---

## 1. The question
What separates winning T20 performances from losing ones, and which players deliver when it matters most?

Five questions answered in SQL:

| # | Question | Main SQL technique |
|---|---|---|
| 1 | Who has the best strike rate in the death overs (16–20)? | CTE + `RANK()` |
| 2 | Which bowler-vs-batter matchups are the most one-sided? | Multi-CTE aggregation, `HAVING` thresholds |
| 3 | How do batters perform in high-pressure chases (required rate > 10)? | Running totals with `SUM() OVER (ORDER BY …)` |
| 4 | Which bowlers are most economical in each phase (powerplay, middle, death)? | `CASE` phase buckets + `PARTITION BY` |
| 5 | _[Your fifth question, e.g. has death-over scoring changed season by season? Does the IPL differ from T20Is?]_ | `LAG()` over seasons |

## 2. The data
- **Source:** [Cricsheet](https://cricsheet.org) ball-by-ball JSON, covering the IPL and T20 internationals (men's). Free and openly licensed.
- **Coverage:** _[seasons/years]_, _[N]_ matches, _[N]_ deliveries
- **Data model** (DuckDB, `cricket.duckdb`):

| Table | Grain | Key columns |
|---|---|---|
| `matches` | one row per match | `match_id`, `competition` (IPL / T20I), `season`, `date`, `venue`, `team1`, `team2`, `toss_winner`, `toss_decision`, `winner` |
| `deliveries` | one row per ball | `match_id`, `innings`, `batting_team`, `over`, `ball_seq`, `batter`, `bowler`, `non_striker`, `runs_batter`, `runs_extras`, `runs_total`, `is_wide`, `is_noball`, `wicket_kind`, `player_out` |

- **Validation:** innings totals were reconciled against official scorecards for _[N]_ matches (`sql/00_validation.sql`).
- The same database is reused in **Project 3** _[link once it exists]_.

## 3. The method
1. **Load:** `etl/load.py` flattens each match's nested JSON (innings → overs → deliveries) into the two tables.
2. **Define:** every query uses the same cricket definitions:
   - **Balls faced** excludes wides. **Legal balls bowled** exclude wides and no-balls.
   - **Phases:** powerplay is overs 1–6, middle overs are 7–15, death overs are 16–20.
   - **Strike rate** = runs ÷ balls faced × 100. **Economy** = runs conceded ÷ legal overs.
   - **Minimum samples:** _[N]_ balls for batters, _[N]_ balls for bowlers, _[N]_ balls for matchups.
3. **Query:** each question is its own file in `sql/` and is commented so the logic can be read top to bottom.
4. **Visualise:** query results are exported to CSV in `dashboard/data/` and feed the Tableau Public dashboard.

## 4. The answer

| Question | Finding |
|---|---|
| Death-over strike rate | _[result + number]_ |
| Bowler vs batter matchups | _[result + number]_ |
| Pressure chases | _[result + number]_ |
| Phase economy | _[result + number]_ |
| _[Q5]_ | _[result + number]_ |

**So what:** _[Two or three sentences on how a team analyst, captain or fantasy player would use this.]_

## 5. What I'd do next
- Adjust for context: normalise for venue and season scoring levels so eras compare fairly
- Add other T20 leagues (BBL, PSL, MLC) through the same pipeline
- Build a ball-by-ball win-probability model on this database (**Project 3**)
- Automate the refresh so new Cricsheet matches load on a schedule

---

## Run it yourself
```bash
git clone https://github.com/[your-username]/cricket-analytics.git
cd cricket-analytics
pip install duckdb pandas

# Download "IPL" and "T20 Internationals" (JSON) from cricsheet.org/downloads
# and unzip them into data/ipl/ and data/t20i/
python etl/load.py

duckdb cricket.duckdb < sql/01_death_strike_rate.sql
```

## Repo structure
```
cricket-analytics/
├── etl/
│   └── load.py                  # JSON → DuckDB
├── sql/
│   ├── 00_validation.sql        # totals vs scorecards
│   ├── 01_death_strike_rate.sql
│   ├── 02_matchups.sql
│   ├── 03_pressure_chases.sql
│   ├── 04_phase_economy.sql
│   └── 05_[your_question].sql
├── dashboard/
│   ├── data/                    # exported CSVs
│   └── screenshot.png
├── data/                        # raw Cricsheet files (git-ignored)
└── README.md
```

## Data credit
Ball-by-ball data from [Cricsheet](https://cricsheet.org), maintained by Stephen Rushe.
