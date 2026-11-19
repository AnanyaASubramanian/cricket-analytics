-- 09: Every bowler-vs-batter pair with enough history, for the player lookup.
--
-- Scope:       IPL and men's T20Is combined, super overs excluded (via deliveries_enriched)
-- Definitions: balls = balls faced by the batter from this bowler (wides excluded)
--              runs = runs off the bat; dismissals = wickets credited to the bowler
-- Threshold:   minimum 24 balls (four overs) between the pair
-- Note:        query 02 ranks the most one-sided of these (with a 30-ball minimum);
--              this file keeps them all so each player's card can list their own.

SELECT bowler,
       batter,
       COUNT(*) FILTER (WHERE is_ball_faced)                          AS balls,
       SUM(runs_batter)                                               AS runs,
       COUNT(*) FILTER (WHERE is_bowler_wicket)                       AS dismissals,
       ROUND(SUM(runs_batter) * 100.0
             / COUNT(*) FILTER (WHERE is_ball_faced), 1)              AS strike_rate
FROM deliveries_enriched
GROUP BY bowler, batter
HAVING COUNT(*) FILTER (WHERE is_ball_faced) >= 24
ORDER BY batter, bowler;
