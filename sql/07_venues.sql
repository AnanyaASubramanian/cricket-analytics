-- 07: Which grounds score highest, and where does chasing win most?
--
-- Scope:       IPL and men's T20Is, super overs excluded
-- Venue names: Cricsheet spells some grounds several ways ("Wankhede Stadium" and
--              "Wankhede Stadium, Mumbai"), and some grounds were renamed. The name is
--              cut at the first comma, then the renames below are merged.
-- Definitions: first-innings score = runs in innings 1, counted only in full
--              20-over matches (rain-shortened games would drag the average down)
--              chasing win % = matches won by the side batting second / decided matches
-- Threshold:   minimum 15 matches at the ground

WITH renames (old_name, new_name) AS (
    VALUES ('Feroz Shah Kotla',                              'Arun Jaitley Stadium'),
           ('M.Chinnaswamy Stadium',                         'M Chinnaswamy Stadium'),
           ('Punjab Cricket Association IS Bindra Stadium',  'Punjab Cricket Association Stadium'),
           ('Sardar Patel Stadium',                          'Narendra Modi Stadium'),
           ('Sheikh Zayed Stadium',                          'Zayed Cricket Stadium'),
           ('New Wanderers Stadium',                         'Wanderers Cricket Ground'),
           ('Subrata Roy Sahara Stadium',                    'Maharashtra Cricket Association Stadium'),
           ('Gahanga International Cricket Stadium. Rwanda', 'Gahanga International Cricket Stadium')
),
innings_one AS (
    -- First-innings total and who batted first, per match
    SELECT match_id,
           ANY_VALUE(batting_team) AS batting_first,
           SUM(runs_total)         AS first_innings_runs
    FROM deliveries_enriched
    WHERE innings = 1
    GROUP BY match_id
),
games AS (
    SELECT COALESCE(r.new_name, split_part(m.venue, ',', 1)) AS venue,
           m.competition,
           m.result,
           m.winner,
           m.target_overs,
           i.batting_first,
           i.first_innings_runs
    FROM matches m
    JOIN innings_one i USING (match_id)
    LEFT JOIN renames r ON r.old_name = split_part(m.venue, ',', 1)
)
SELECT venue,
       string_agg(DISTINCT competition, ' & ' ORDER BY competition) AS competitions,
       COUNT(*)                                                     AS matches,
       ROUND(AVG(first_innings_runs) FILTER (WHERE target_overs = 20), 1) AS avg_first_innings,
       COUNT(*) FILTER (WHERE result = 'win')                       AS decided_matches,
       ROUND(COUNT(*) FILTER (WHERE result = 'win' AND winner <> batting_first) * 100.0
             / NULLIF(COUNT(*) FILTER (WHERE result = 'win'), 0), 1) AS chasing_win_pct
FROM games
GROUP BY venue
HAVING COUNT(*) >= 15
ORDER BY avg_first_innings DESC, venue;
