-- 01: Who has the best strike rate in the death overs (16–20)?
--
-- Scope:       IPL and men's T20Is, super overs excluded (via deliveries_enriched)
-- Periods:     'All time' and 'Since 2022' (recent form), each ranked separately
-- Definitions: balls faced excludes wides; strike rate = runs / balls faced * 100
-- Threshold:   minimum 300 death-over balls faced all time, 120 since 2022
-- Ranking:     separately within each period and competition, so IPL batters are
--              compared with IPL batters and T20I batters with T20I batters

WITH periods (period, from_year, min_balls) AS (
    VALUES ('All time', 0, 300), ('Since 2022', 2022, 120)
),
death AS (
    -- One row per period, competition and batter: runs and balls faced in overs 16–20
    SELECT p.period,
           p.min_balls,
           d.competition,
           d.batter,
           SUM(d.runs_batter)                      AS runs,
           COUNT(*) FILTER (WHERE d.is_ball_faced) AS balls_faced
    FROM deliveries_enriched d
    JOIN periods p ON d.year >= p.from_year
    WHERE d.phase = 'death'
    GROUP BY p.period, p.min_balls, d.competition, d.batter
)
SELECT period,
       competition,
       RANK() OVER (PARTITION BY period, competition
                    ORDER BY runs * 1.0 / balls_faced DESC) AS sr_rank,
       batter,
       runs,
       balls_faced,
       ROUND(runs * 100.0 / balls_faced, 1)                 AS strike_rate
FROM death
WHERE balls_faced >= min_balls
ORDER BY period, competition, sr_rank, batter;
