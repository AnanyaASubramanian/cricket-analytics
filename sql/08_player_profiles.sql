-- 08: Player profiles for the website's player lookup.
--
-- Scope:       IPL and men's T20Is combined, super overs excluded (via deliveries_enriched)
-- Output:      one row per player with their batting and bowling, overall and by phase
-- Definitions: same as every other query (see sql/00_views.sql)
--              batting average = runs / times dismissed (retirements not counted)
--              bowling average = runs conceded / wickets
-- Threshold:   players with at least 60 balls faced or 60 legal balls bowled

WITH appearances AS (
    -- Every match a player took part in, as striker, non-striker or bowler
    SELECT match_id, competition, year, batter      AS player FROM deliveries_enriched
    UNION
    SELECT match_id, competition, year, non_striker AS player FROM deliveries_enriched
    UNION
    SELECT match_id, competition, year, bowler      AS player FROM deliveries_enriched
),
careers AS (
    SELECT player,
           COUNT(DISTINCT match_id)                                     AS matches,
           string_agg(DISTINCT competition, ' & ' ORDER BY competition) AS competitions,
           MIN(year)                                                    AS first_year,
           MAX(year)                                                    AS last_year
    FROM appearances
    GROUP BY player
),
batting AS (
    SELECT batter AS player,
           SUM(runs_batter)                                                   AS bat_runs,
           COUNT(*) FILTER (WHERE is_ball_faced)                              AS bat_balls,
           COUNT(*) FILTER (WHERE runs_batter = 4)                            AS fours,
           COUNT(*) FILTER (WHERE runs_batter = 6)                            AS sixes,
           SUM(runs_batter)  FILTER (WHERE phase = 'powerplay')               AS pp_runs,
           COUNT(*) FILTER (WHERE is_ball_faced AND phase = 'powerplay')      AS pp_balls,
           SUM(runs_batter)  FILTER (WHERE phase = 'middle')                  AS mid_runs,
           COUNT(*) FILTER (WHERE is_ball_faced AND phase = 'middle')         AS mid_balls,
           SUM(runs_batter)  FILTER (WHERE phase = 'death')                   AS death_runs,
           COUNT(*) FILTER (WHERE is_ball_faced AND phase = 'death')          AS death_balls
    FROM deliveries_enriched
    GROUP BY batter
),
dismissals AS (
    -- Counted on player_out, so a non-striker run out is charged to the right player
    SELECT player_out AS player,
           COUNT(*)   AS times_out
    FROM deliveries_enriched
    WHERE player_out IS NOT NULL
      AND wicket_kind NOT IN ('retired hurt', 'retired not out')
    GROUP BY player_out
),
bowling AS (
    SELECT bowler AS player,
           COUNT(*) FILTER (WHERE is_legal_ball)                              AS bowl_balls,
           SUM(bowler_runs)                                                   AS bowl_runs,
           COUNT(*) FILTER (WHERE is_bowler_wicket)                           AS wickets,
           COUNT(*) FILTER (WHERE is_legal_ball AND bowler_runs = 0)          AS dot_balls,
           SUM(bowler_runs)  FILTER (WHERE phase = 'powerplay')               AS pp_runs_conceded,
           COUNT(*) FILTER (WHERE is_legal_ball AND phase = 'powerplay')      AS pp_legal_balls,
           SUM(bowler_runs)  FILTER (WHERE phase = 'middle')                  AS mid_runs_conceded,
           COUNT(*) FILTER (WHERE is_legal_ball AND phase = 'middle')         AS mid_legal_balls,
           SUM(bowler_runs)  FILTER (WHERE phase = 'death')                   AS death_runs_conceded,
           COUNT(*) FILTER (WHERE is_legal_ball AND phase = 'death')          AS death_legal_balls
    FROM deliveries_enriched
    GROUP BY bowler
)
SELECT c.player,
       c.competitions,
       c.first_year,
       c.last_year,
       c.matches,
       -- batting
       COALESCE(b.bat_runs, 0)                                       AS bat_runs,
       COALESCE(b.bat_balls, 0)                                      AS bat_balls,
       COALESCE(o.times_out, 0)                                      AS times_out,
       ROUND(b.bat_runs * 100.0 / NULLIF(b.bat_balls, 0), 1)         AS strike_rate,
       ROUND(b.bat_runs * 1.0 / NULLIF(o.times_out, 0), 1)           AS bat_average,
       COALESCE(b.fours, 0)                                          AS fours,
       COALESCE(b.sixes, 0)                                          AS sixes,
       COALESCE(b.pp_balls, 0)                                       AS pp_balls,
       ROUND(b.pp_runs * 100.0 / NULLIF(b.pp_balls, 0), 1)           AS pp_strike_rate,
       COALESCE(b.mid_balls, 0)                                      AS mid_balls,
       ROUND(b.mid_runs * 100.0 / NULLIF(b.mid_balls, 0), 1)         AS mid_strike_rate,
       COALESCE(b.death_balls, 0)                                    AS death_balls,
       ROUND(b.death_runs * 100.0 / NULLIF(b.death_balls, 0), 1)     AS death_strike_rate,
       -- bowling
       COALESCE(w.bowl_balls, 0)                                     AS bowl_balls,
       COALESCE(w.wickets, 0)                                        AS wickets,
       ROUND(w.bowl_runs * 6.0 / NULLIF(w.bowl_balls, 0), 2)         AS economy,
       ROUND(w.bowl_runs * 1.0 / NULLIF(w.wickets, 0), 1)            AS bowl_average,
       ROUND(w.dot_balls * 100.0 / NULLIF(w.bowl_balls, 0), 1)       AS dot_ball_pct,
       COALESCE(w.pp_legal_balls, 0)                                 AS pp_legal_balls,
       ROUND(w.pp_runs_conceded * 6.0 / NULLIF(w.pp_legal_balls, 0), 2)       AS pp_economy,
       COALESCE(w.mid_legal_balls, 0)                                AS mid_legal_balls,
       ROUND(w.mid_runs_conceded * 6.0 / NULLIF(w.mid_legal_balls, 0), 2)     AS mid_economy,
       COALESCE(w.death_legal_balls, 0)                              AS death_legal_balls,
       ROUND(w.death_runs_conceded * 6.0 / NULLIF(w.death_legal_balls, 0), 2) AS death_economy
FROM careers c
LEFT JOIN batting    b ON b.player = c.player
LEFT JOIN dismissals o ON o.player = c.player
LEFT JOIN bowling    w ON w.player = c.player
WHERE COALESCE(b.bat_balls, 0) >= 60
   OR COALESCE(w.bowl_balls, 0) >= 60
ORDER BY c.player;
