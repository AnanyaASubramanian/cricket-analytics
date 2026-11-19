-- 04: Which bowlers are most economical in each phase (powerplay, middle, death)?
--
-- Scope:       IPL and men's T20Is combined, super overs excluded (via deliveries_enriched)
-- Phases:      the CASE buckets in sql/00_views.sql: powerplay overs 1–6,
--              middle 7–15, death 16–20
-- Definitions: legal balls exclude wides and no-balls
--              runs conceded = runs off the bat + wides + no-balls (byes/leg byes excluded)
--              economy = runs conceded / legal overs
--              dot ball % = legal balls with no runs conceded / legal balls
--              wickets = dismissals credited to the bowler
-- Threshold:   minimum 300 legal balls (50 overs) in that phase and competition
-- Ranking:     separately within each competition. Economy depends on the strength
--              of the batting faced, so IPL and T20I bowlers aren't ranked together
--              (a combined list is dominated by bowlers facing associate-nation batting).
-- Output:      top 10 most economical bowlers per competition per phase

WITH phase_totals AS (
    -- Step 1: one row per bowler per phase per competition
    SELECT competition,
           phase,
           bowler,
           COUNT(*) FILTER (WHERE is_legal_ball)                    AS legal_balls,
           SUM(bowler_runs)                                         AS runs_conceded,
           COUNT(*) FILTER (WHERE is_legal_ball AND bowler_runs = 0) AS dot_balls,
           COUNT(*) FILTER (WHERE is_bowler_wicket)                 AS wickets
    FROM deliveries_enriched
    GROUP BY competition, phase, bowler
    HAVING COUNT(*) FILTER (WHERE is_legal_ball) >= 300
),
phase_ranked AS (
    -- Step 2: economy, and a separate ranking inside each competition + phase
    SELECT *,
           ROUND(runs_conceded * 6.0 / legal_balls, 2)  AS economy,
           ROUND(dot_balls * 100.0 / legal_balls, 1)    AS dot_ball_pct,
           RANK() OVER (PARTITION BY competition, phase
                        ORDER BY runs_conceded * 1.0 / legal_balls) AS phase_rank
    FROM phase_totals
)
-- Step 3: top 10 per competition per phase, phases in match order
SELECT competition,
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
ORDER BY competition,
         CASE phase WHEN 'powerplay' THEN 1 WHEN 'middle' THEN 2 ELSE 3 END,
         phase_rank;
