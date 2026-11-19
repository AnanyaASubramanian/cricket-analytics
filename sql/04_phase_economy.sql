-- 04: Which bowlers are most economical in each phase (powerplay, middle, death)?
--
-- Scope:       IPL and men's T20Is, super overs excluded (via deliveries_enriched)
-- Periods:     'All time' and 'Since 2022' (recent form), each ranked separately
-- Phases:      the CASE buckets in sql/00_views.sql: powerplay overs 1–6,
--              middle 7–15, death 16–20
-- Definitions: legal balls exclude wides and no-balls
--              runs conceded = runs off the bat + wides + no-balls (byes/leg byes excluded)
--              economy = runs conceded / legal overs
--              dot ball % = legal balls with no runs conceded / legal balls
--              wickets = dismissals credited to the bowler
-- Threshold:   minimum 300 legal balls (50 overs) in that phase all time, 120 (20 overs) since 2022
-- Ranking:     separately within each period, competition and phase. Economy depends on
--              the strength of the batting faced, so IPL and T20I bowlers aren't ranked
--              together (a combined list is dominated by bowlers facing associate batting).
-- Output:      top 10 most economical bowlers per period, competition and phase

WITH periods (period, from_year, min_balls) AS (
    VALUES ('All time', 0, 300), ('Since 2022', 2022, 120)
),
phase_totals AS (
    -- Step 1: one row per bowler per period, competition and phase
    SELECT p.period,
           p.min_balls,
           d.competition,
           d.phase,
           d.bowler,
           COUNT(*) FILTER (WHERE d.is_legal_ball)                      AS legal_balls,
           SUM(d.bowler_runs)                                           AS runs_conceded,
           COUNT(*) FILTER (WHERE d.is_legal_ball AND d.bowler_runs = 0) AS dot_balls,
           COUNT(*) FILTER (WHERE d.is_bowler_wicket)                   AS wickets
    FROM deliveries_enriched d
    JOIN periods p ON d.year >= p.from_year
    GROUP BY p.period, p.min_balls, d.competition, d.phase, d.bowler
),
phase_ranked AS (
    -- Step 2: economy, and a separate ranking inside each period + competition + phase
    SELECT *,
           ROUND(runs_conceded * 6.0 / legal_balls, 2)  AS economy,
           ROUND(dot_balls * 100.0 / legal_balls, 1)    AS dot_ball_pct,
           RANK() OVER (PARTITION BY period, competition, phase
                        ORDER BY runs_conceded * 1.0 / legal_balls) AS phase_rank
    FROM phase_totals
    WHERE legal_balls >= min_balls
)
-- Step 3: top 10 per period, competition and phase, phases in match order
SELECT period,
       competition,
       phase,
       phase_rank,
       bowler,
       -- overs in cricket notation: 90.2 = 90 overs and 2 balls
       (legal_balls // 6) || '.' || (legal_balls % 6) AS overs,
       runs_conceded,
       wickets,
       economy,
       dot_ball_pct
FROM phase_ranked
WHERE phase_rank <= 10
ORDER BY period,
         competition,
         CASE phase WHEN 'powerplay' THEN 1 WHEN 'middle' THEN 2 ELSE 3 END,
         phase_rank, bowler;
