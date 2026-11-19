-- 06: Does winning the toss matter? And is it better to bat first or chase?
--
-- Scope:       IPL and men's T20Is, matches with a winner (ties settled by super
--              over and no-results are excluded)
-- Definitions: batting first = the toss winner if they chose to bat, otherwise the
--              other team
-- Output:      counts per competition per year, plus an all-years total per
--              competition (the rows where year is empty), via GROUPING SETS.
--              Percentages are counts / decided_matches * 100.

WITH decided AS (
    SELECT competition,
           year,
           toss_winner,
           toss_decision,
           winner,
           CASE WHEN toss_decision = 'bat' THEN toss_winner
                WHEN toss_winner = team1   THEN team2
                ELSE team1
           END AS batting_first
    FROM matches
    WHERE result = 'win'
)
SELECT competition,
       year,                                                                 -- empty = all years
       COUNT(*)                                                    AS decided_matches,
       COUNT(*) FILTER (WHERE winner = toss_winner)                AS toss_winner_won,
       COUNT(*) FILTER (WHERE winner <> batting_first)             AS chasing_side_won,
       COUNT(*) FILTER (WHERE toss_decision = 'field')             AS chose_to_field,
       ROUND(COUNT(*) FILTER (WHERE winner = toss_winner)    * 100.0 / COUNT(*), 1) AS toss_winner_won_pct,
       ROUND(COUNT(*) FILTER (WHERE winner <> batting_first) * 100.0 / COUNT(*), 1) AS chasing_side_won_pct,
       ROUND(COUNT(*) FILTER (WHERE toss_decision = 'field') * 100.0 / COUNT(*), 1) AS chose_to_field_pct
FROM decided
GROUP BY GROUPING SETS ((competition, year), (competition))
ORDER BY competition, year NULLS FIRST;
