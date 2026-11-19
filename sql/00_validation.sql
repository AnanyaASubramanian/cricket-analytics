-- 00: Validation - does the database match the real scorecards?
--
-- Check 1: innings totals (runs/wickets) for well-known matches vs the published
--          scorecards. Every row should say PASS.
-- Check 2: every ball's runs add up (runs_total = runs off the bat + extras).
-- Check 3: no over has 8+ legal balls (7-ball overs are real umpire miscounts).
-- Check 2 and check 3's overs_8_plus_legal_balls should both return 0.
--
-- Wickets exclude 'retired hurt' and 'retired not out', which scorecards don't
-- count as dismissals.

-- Check 1: innings totals vs published scorecards
WITH expected (date, batting_team, runs, wickets, note) AS (
    VALUES
    (DATE '2008-04-18', 'Kolkata Knight Riders',       222,  3, 'IPL opener, McCullum 158*'),
    (DATE '2008-04-18', 'Royal Challengers Bangalore',  82, 10, 'IPL opener'),
    (DATE '2013-04-23', 'Royal Challengers Bangalore', 263,  5, 'Gayle 175*'),
    (DATE '2024-04-15', 'Sunrisers Hyderabad',         287,  3, 'IPL record total'),
    (DATE '2024-04-15', 'Royal Challengers Bengaluru', 262,  7, 'reply to 287'),
    (DATE '2024-04-26', 'Kolkata Knight Riders',       261,  6, 'set 262'),
    (DATE '2024-04-26', 'Punjab Kings',                262,  2, 'record T20 chase'),
    (DATE '2007-09-24', 'India',                       157,  5, 'World T20 final'),
    (DATE '2007-09-24', 'Pakistan',                    152, 10, 'World T20 final'),
    (DATE '2016-04-03', 'England',                     155,  9, 'World T20 final'),
    (DATE '2016-04-03', 'West Indies',                 161,  6, 'World T20 final, Brathwaite 4 sixes'),
    (DATE '2022-11-13', 'Pakistan',                    137,  8, 'T20 World Cup final'),
    (DATE '2022-11-13', 'England',                     138,  5, 'T20 World Cup final'),
    (DATE '2024-06-29', 'India',                       176,  7, 'T20 World Cup final'),
    (DATE '2024-06-29', 'South Africa',                169,  8, 'T20 World Cup final')
),
actual AS (
    SELECT date,
           batting_team,
           SUM(runs_total) AS runs,
           COUNT(*) FILTER (WHERE wicket_kind NOT IN ('retired hurt', 'retired not out')) AS wickets
    FROM deliveries_enriched
    GROUP BY date, batting_team
)
SELECT e.date,
       e.batting_team,
       e.note,
       e.runs    AS expected_runs,
       a.runs    AS actual_runs,
       e.wickets AS expected_wkts,
       a.wickets AS actual_wkts,
       CASE WHEN a.runs = e.runs AND a.wickets = e.wickets THEN 'PASS' ELSE 'FAIL' END AS result
FROM expected e
LEFT JOIN actual a USING (date, batting_team)
ORDER BY e.date, e.batting_team;

-- Check 2: balls where runs don't add up (should be 0)
SELECT COUNT(*) AS balls_not_adding_up
FROM deliveries
WHERE runs_total <> runs_batter + runs_extras
   OR runs_extras <> extras_wides + extras_noballs + extras_byes + extras_legbyes + extras_penalty;

-- Check 3: overs with too many legal balls.
-- Umpires occasionally miscount and allow a 7-ball over. Cricsheet records these
-- (its 'miscounted_overs' field), so seven_ball_overs is real cricket, not an error.
-- An over with 8+ legal balls would mean a loading error (should be 0).
SELECT COUNT(*) FILTER (WHERE legal_balls = 7) AS seven_ball_overs,
       COUNT(*) FILTER (WHERE legal_balls > 7) AS overs_8_plus_legal_balls
FROM (
    SELECT match_id, innings, over_num,
           COUNT(*) FILTER (WHERE is_legal_ball) AS legal_balls
    FROM deliveries_enriched
    GROUP BY match_id, innings, over_num
);
