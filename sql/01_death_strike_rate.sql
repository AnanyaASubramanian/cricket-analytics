-- 01: Who has the best strike rate in the death overs (16–20)?
--
-- Scope:       IPL and men's T20Is, all seasons, super overs excluded (via deliveries_enriched)
-- Definitions: balls faced excludes wides; strike rate = runs / balls faced * 100
-- Threshold:   minimum 300 death-over balls faced in that competition
-- Ranking:     separately within each competition, so IPL batters are compared with
--              IPL batters and T20I batters with T20I batters

WITH death AS (
    -- One row per batter per competition: runs and balls faced in overs 16–20
    SELECT competition,
           batter,
           SUM(runs_batter)                    AS runs,
           COUNT(*) FILTER (WHERE is_ball_faced) AS balls_faced
    FROM deliveries_enriched
    WHERE phase = 'death'
    GROUP BY competition, batter
)
SELECT competition,
       RANK() OVER (PARTITION BY competition
                    ORDER BY runs * 1.0 / balls_faced DESC) AS sr_rank,
       batter,
       runs,
       balls_faced,
       ROUND(runs * 100.0 / balls_faced, 1)                 AS strike_rate
FROM death
WHERE balls_faced >= 300
ORDER BY competition, sr_rank;
