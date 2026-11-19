-- 02: Which bowler-vs-batter matchups are the most one-sided?
--
-- Scope:       IPL and men's T20Is combined, super overs excluded (via deliveries_enriched)
-- Definitions: balls = balls faced by the batter from this bowler (wides excluded)
--              runs = runs off the bat; dismissals = wickets credited to the bowler
--              strike rate = runs / balls * 100; average = runs / dismissals
-- Threshold:   minimum 30 balls between the pair
-- One-sided:   bowler wins = lowest batter strike rate (ties: more dismissals first)
--              batter wins = highest batter strike rate (ties: fewer dismissals first)
-- Output:      top 10 in each direction

WITH pair_totals AS (
    -- Step 1: one row per bowler-batter pair
    SELECT bowler,
           batter,
           COUNT(*) FILTER (WHERE is_ball_faced)    AS balls,
           SUM(runs_batter)                         AS runs,
           COUNT(*) FILTER (WHERE is_bowler_wicket) AS dismissals
    FROM deliveries_enriched
    GROUP BY bowler, batter
    -- Step 2: drop small samples
    HAVING COUNT(*) FILTER (WHERE is_ball_faced) >= 30
),
pair_rates AS (
    -- Step 3: rates, plus a rank in each direction
    SELECT *,
           ROUND(runs * 100.0 / balls, 1)          AS strike_rate,
           ROUND(runs * 1.0 / NULLIF(dismissals, 0), 1) AS average,
           RANK() OVER (ORDER BY runs * 1.0 / balls ASC,  dismissals DESC) AS bowler_rank,
           RANK() OVER (ORDER BY runs * 1.0 / balls DESC, dismissals ASC)  AS batter_rank
    FROM pair_totals
)
-- Step 4: top 10 each way, in one result
SELECT 'Bowler dominates' AS winner, bowler_rank AS rank,
       bowler, batter, balls, runs, dismissals, strike_rate, average
FROM pair_rates
WHERE bowler_rank <= 10
UNION ALL
SELECT 'Batter dominates', batter_rank,
       bowler, batter, balls, runs, dismissals, strike_rate, average
FROM pair_rates
WHERE batter_rank <= 10
ORDER BY winner DESC, rank, bowler, batter;
