-- 03: How do batters perform in high-pressure chases (required rate > 10)?
--
-- Scope:       IPL and men's T20Is combined, second innings only, super overs excluded
-- Pressure:    a ball is "pressure" if, before it was bowled, the chasing side needed
--              more than 10 runs per over: runs needed / balls left * 6 > 10
--              (uses the official target, so rain-revised DLS targets are respected)
-- Definitions: balls faced excludes wides; strike rate = runs / balls faced * 100
-- Threshold:   minimum 100 balls faced under pressure AND 100 in the rest of their
--              chasing, so the comparison isn't driven by a handful of balls
-- Output:      strike rate under pressure vs the same batter's strike rate in the
--              rest of their chasing, so you can see who lifts and who freezes

WITH chase_balls AS (
    -- Step 1: every ball of every chase, with the official target attached
    SELECT d.match_id,
           d.over_num,
           d.ball_seq,
           d.batter,
           d.runs_batter,
           d.runs_total,
           d.is_ball_faced,
           d.is_legal_ball,
           m.target_runs,
           -- target_overs is in cricket notation (14.2 = 14 overs + 2 balls)
           CAST(FLOOR(m.target_overs) * 6
                + ROUND((m.target_overs - FLOOR(m.target_overs)) * 10) AS INTEGER) AS target_balls
    FROM deliveries_enriched d
    JOIN matches m USING (match_id)
    WHERE d.innings = 2
      AND m.target_runs IS NOT NULL
),
running AS (
    -- Step 2: running totals of runs scored and legal balls used BEFORE this ball
    SELECT *,
           COALESCE(SUM(runs_total) OVER w, 0)            AS runs_before,
           COALESCE(SUM(is_legal_ball::INT) OVER w, 0)    AS legal_balls_before
    FROM chase_balls
    WINDOW w AS (PARTITION BY match_id
                 ORDER BY over_num, ball_seq
                 ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
),
pressure AS (
    -- Step 3: the required rate at the moment each ball was bowled
    SELECT *,
           (target_runs - runs_before) * 6.0
               / NULLIF(target_balls - legal_balls_before, 0) AS required_rate
    FROM running
    WHERE target_runs - runs_before > 0          -- chase not already won
      AND target_balls - legal_balls_before > 0  -- balls still left
),
batter_split AS (
    -- Step 4: each batter's runs and balls, split into pressure vs everything else
    SELECT batter,
           SUM(runs_batter)           FILTER (WHERE required_rate > 10)  AS pressure_runs,
           COUNT(*) FILTER (WHERE is_ball_faced AND required_rate > 10)  AS pressure_balls,
           SUM(runs_batter)           FILTER (WHERE required_rate <= 10) AS other_runs,
           COUNT(*) FILTER (WHERE is_ball_faced AND required_rate <= 10) AS other_balls
    FROM pressure
    GROUP BY batter
    HAVING COUNT(*) FILTER (WHERE is_ball_faced AND required_rate > 10)  >= 100
       AND COUNT(*) FILTER (WHERE is_ball_faced AND required_rate <= 10) >= 100
)
-- Step 5: compare and rank by strike rate under pressure
SELECT batter,
       pressure_balls,
       pressure_runs,
       ROUND(pressure_runs * 100.0 / pressure_balls, 1)                    AS pressure_sr,
       ROUND(other_runs * 100.0 / NULLIF(other_balls, 0), 1)               AS other_chase_sr,
       ROUND(pressure_runs * 100.0 / pressure_balls
             - other_runs * 100.0 / NULLIF(other_balls, 0), 1)             AS sr_lift,
       RANK() OVER (ORDER BY pressure_runs * 1.0 / pressure_balls DESC)    AS pressure_rank
FROM batter_split
ORDER BY pressure_rank;
