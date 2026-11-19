-- 01: Who has the best strike rate in the death overs (16–20)?
--
-- Scope:       IPL, all seasons, super overs excluded
-- Definitions: balls faced excludes wides; strike rate = runs / balls faced * 100
-- Threshold:   minimum 300 death-over balls faced

WITH death AS (
    -- One row per batter: runs and balls faced in overs 16–20
    SELECT d.batter,
           SUM(d.runs_batter)                    AS runs,
           COUNT(*) FILTER (WHERE NOT d.is_wide) AS balls_faced
    FROM deliveries d
    JOIN matches m USING (match_id)
    WHERE m.competition = 'IPL'
      AND d.over_num BETWEEN 16 AND 20
      AND NOT d.is_super_over
    GROUP BY d.batter
)
SELECT batter,
       runs,
       balls_faced, 
       ROUND(runs * 100.0 / balls_faced, 1)                 AS strike_rate,
       RANK() OVER (ORDER BY runs * 1.0 / balls_faced DESC) AS sr_rank
FROM death
WHERE balls_faced >= 300
ORDER BY sr_rank;
