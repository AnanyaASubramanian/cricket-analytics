-- 05: Has death-over scoring changed season by season, and does the IPL differ from T20Is?
--
-- Scope:       IPL and men's T20Is, death overs (16–20) only, super overs excluded
-- Definitions: run rate = all runs (incl. extras) / legal overs, from the batting side's view
--              boundary % = balls faced that went for 4 or 6 / balls faced
--              change = this year's run rate minus the previous year's, via LAG()
--              (compared_with shows which year that was)
-- Caveats:     years with fewer than 20 matches are dropped (early T20Is are too thin)
--              T20I figures mix full members and associates; associate matches grew
--              sharply after 2019, which pulls the T20I average down
--              the latest year may be a part-season

WITH yearly AS (
    -- Step 1: one row per competition per year
    SELECT competition,
           year,
           COUNT(DISTINCT match_id)                                   AS matches,
           SUM(runs_total)                                            AS runs,
           COUNT(*) FILTER (WHERE is_legal_ball)                      AS legal_balls,
           COUNT(*) FILTER (WHERE is_ball_faced)                      AS balls_faced,
           COUNT(*) FILTER (WHERE is_ball_faced AND runs_batter >= 4) AS boundaries
    FROM deliveries_enriched
    WHERE phase = 'death'
    GROUP BY competition, year
    HAVING COUNT(DISTINCT match_id) >= 20
),
rates AS (
    -- Step 2: the yearly rates
    SELECT competition,
           year,
           matches,
           runs * 6.0 / legal_balls          AS run_rate,
           boundaries * 100.0 / balls_faced  AS boundary_pct
    FROM yearly
)
-- Step 3: compare each year with the one before, within the same competition
SELECT competition,
       year,
       matches,
       ROUND(run_rate, 2)                                                AS death_run_rate,
       -- the previous year kept (usually year - 1, but a thin year may have been dropped)
       LAG(year) OVER w                                                  AS compared_with,
       ROUND(LAG(run_rate) OVER w, 2)                                    AS prev_rate,
       ROUND(run_rate - LAG(run_rate) OVER w, 2)                         AS change,
       ROUND(boundary_pct, 1)                                            AS boundary_pct,
       ROUND(boundary_pct - LAG(boundary_pct) OVER w, 1)                 AS boundary_pct_change
FROM rates
WINDOW w AS (PARTITION BY competition ORDER BY year)
ORDER BY competition, year;
