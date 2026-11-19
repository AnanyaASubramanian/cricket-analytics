-- 00: Shared definitions used by every analysis query.
--
-- deliveries_enriched = deliveries + match context + per-ball helper columns,
-- so each cricket definition lives in exactly one place.
-- etl/load.py runs this file after every rebuild.
--
-- Note: no blank lines inside the statement. DBeaver treats a blank line as
-- the end of a statement, so a blank line would split this view in two.

CREATE OR REPLACE VIEW deliveries_enriched AS
SELECT
    d.*,
    m.competition,
    m.year,
    m.date,
    m.venue,
    -- Phase of the innings by over (powerplay 1–6, middle 7–15, death 16–20)
    CASE
        WHEN d.over_num <= 6  THEN 'powerplay'
        WHEN d.over_num <= 15 THEN 'middle'
        ELSE 'death'
    END AS phase,
    -- Balls faced by the batter: everything except wides
    NOT d.is_wide                         AS is_ball_faced,
    -- Legal balls bowled: excludes wides and no-balls (6 per over)
    NOT d.is_wide AND NOT d.is_noball     AS is_legal_ball,
    -- Runs charged to the bowler: byes and leg byes are not the bowler's fault
    d.runs_batter + d.extras_wides + d.extras_noballs AS bowler_runs,
    -- Dismissals credited to the bowler (run outs, retirements etc. are not)
    COALESCE(d.wicket_kind IN (
        'bowled', 'caught', 'caught and bowled', 'lbw', 'stumped', 'hit wicket'
    ), FALSE)                             AS is_bowler_wicket
FROM deliveries d
JOIN matches m USING (match_id)
WHERE NOT d.is_super_over;
