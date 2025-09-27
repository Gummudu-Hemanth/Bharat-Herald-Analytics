USE bharat_herald_db;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 1.What is the trend in copies sold, copies returned and  net circulation across all states from 2019 to 2024? How has this changed year-over-year?
with State_yearly AS (
	SELECT 
		year,
        State,
        SUM(Copies_Sold) AS Total_Copies_Sold,
        SUM(copies_returned) AS Total_Copies_Returned,
        SUM(Net_Circulation) AS Total_Net_Circulation
	FROM print_sales
    WHERE year BETWEEN 2019 AND 2024
    GROUP BY year, State
),
yoy_state AS (
	SELECT
		year,
        State,
        Total_Copies_Sold,
        Total_Copies_Returned,
        Total_Net_Circulation,
        LAG(Total_Copies_Sold) OVER(PARTITION BY State ORDER BY year) AS Prev_Year_Copies_Sold,
        LAG(Total_Copies_Returned) OVER(PARTITION BY State ORDER BY year) AS Prev_Year_Copies_Returned,
        LAG(Total_Net_Circulation) OVER(PARTITION BY State ORDER BY year) AS Prev_Year_Net_Circulation
	FROM State_yearly
)
SELECT
	year,
    State,
    Total_Copies_Sold,
    Total_Copies_Returned,
    Total_Net_Circulation,
    ROUND(((Total_Copies_Sold - Prev_Year_Copies_Sold) * 100 / NULLIF(Prev_Year_Copies_Sold, 0)), 2) AS YoY_Sold_Change_Percent,
	ROUND(((Total_Copies_Returned - Prev_Year_Copies_Returned) * 100 / NULLIF(Prev_Year_Copies_Returned, 0)), 2) AS YoY_Returned_Change_Percent,
    ROUND(((Total_Net_Circulation - Prev_Year_Net_Circulation) * 100 / NULLIF(Prev_Year_Net_Circulation, 0)), 2) AS YoY_Net_Change_Percent
FROM yoy_state
ORDER BY year;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 2. Which cities contributed the highest to net circulation and copies sold in 2024? Are these cities still profitable to operate in?
WITH city_stats AS (
	SELECT
		c.city_id,
		c.city, 
		SUM(p.Copies_Sold) AS Total_Copies_Sold,
		SUM(p.Net_Circulation) AS Total_Net_Circulation,
        ROUND((SUM(p.copies_returned)*100 / NULLIF(SUM(Copies_Sold),0)), 2) AS Return_Percent
	FROM print_sales AS p
	JOIN city_data AS c
	ON p.City_ID = c.city_id
	WHERE p.year = 2024
	GROUP BY c.city_id, c.city
),
profitability_analysis AS (
	SELECT 
    cs.*,
    ROUND(AVG(cr.literacy_rate),2) AS literacy_rate,
    ROUND(AVG(cr.smartphone_penetration),2) AS smartphone_penetration,
    ROUND(AVG(cr.internet_penetration),2) AS internet_penetration,
    CASE
		WHEN cs.Return_Percent < 10 THEN 'Highly Profitable'
        WHEN cs.Return_Percent < 20 THEN 'Moderately Profitable'
        WHEN cs.Return_Percent < 30 THEN 'Marginally Profitable'
        ELSE 'Needs Review'
	END AS Profitable_Category
    FROM city_stats AS cs
    LEFT JOIN city_readiness AS cr
    ON cs.city_id = cr.city_id
    WHERE cr.year = 2024
    GROUP BY cs.city_id, cs.city, cs.Total_Copies_Sold, cs.Total_Net_Circulation, cs.Return_Percent
)
SELECT 
	city,
    Total_Copies_Sold,
    Total_Net_Circulation,
    literacy_rate,
    smartphone_penetration,
    internet_penetration,
    Return_Percent,
    Profitable_Category
FROM profitability_analysis
ORDER BY Total_Copies_Sold DESC, Total_Net_Circulation DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3. How has ad revenue evolved across different ad categories between 2019 and 2024? Which categories have remained strong, and which have declined?
WITH category_revenue AS (
    SELECT
        ac.standard_ad_category,
        ar.Year,
        ROUND(SUM(ar.ad_revenue), 2) AS total_revenue
    FROM ad_revenue AS ar
    JOIN ad_category AS 
    ac ON ar.ad_category = ac.ad_category_id
    WHERE ar.Year BETWEEN 2019 AND 2024
    GROUP BY ac.standard_ad_category, ar.Year
),
trend_metrics AS (
    SELECT
        standard_ad_category,
        -- Revenue values
        MAX(CASE WHEN Year = 2019 THEN total_revenue END) AS revenue_2019,
        MAX(CASE WHEN Year = 2020 THEN total_revenue END) AS revenue_2020,
        MAX(CASE WHEN Year = 2021 THEN total_revenue END) AS revenue_2021,
        MAX(CASE WHEN Year = 2022 THEN total_revenue END) AS revenue_2022,
        MAX(CASE WHEN Year = 2023 THEN total_revenue END) AS revenue_2023,
        MAX(CASE WHEN Year = 2024 THEN total_revenue END) AS revenue_2024,
        
        -- Key Metrics for Decision Making
        -- 1. Overall Trend 
        (MAX(CASE WHEN Year = 2024 THEN total_revenue END) - MAX(CASE WHEN Year = 2019 THEN total_revenue END)) / NULLIF(MAX(CASE WHEN Year = 2019 THEN total_revenue END), 0) AS net_growth_pct,
        
        -- 2. Consistency Score
        (CASE WHEN MAX(CASE WHEN Year = 2020 THEN total_revenue END) > MAX(CASE WHEN Year = 2019 THEN total_revenue END) THEN 1 ELSE 0 END +
         CASE WHEN MAX(CASE WHEN Year = 2021 THEN total_revenue END) > MAX(CASE WHEN Year = 2020 THEN total_revenue END) THEN 1 ELSE 0 END +
         CASE WHEN MAX(CASE WHEN Year = 2022 THEN total_revenue END) > MAX(CASE WHEN Year = 2021 THEN total_revenue END) THEN 1 ELSE 0 END +
         CASE WHEN MAX(CASE WHEN Year = 2023 THEN total_revenue END) > MAX(CASE WHEN Year = 2022 THEN total_revenue END) THEN 1 ELSE 0 END +
         CASE WHEN MAX(CASE WHEN Year = 2024 THEN total_revenue END) > MAX(CASE WHEN Year = 2023 THEN total_revenue END) THEN 1 ELSE 0 END) AS consistency_score,
        
        -- 3. Peak Performance Timing (25% weight)
        CASE 
            WHEN MAX(CASE WHEN Year = 2024 THEN total_revenue END) = 
                 GREATEST(MAX(CASE WHEN Year = 2019 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2020 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2021 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2022 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2023 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2024 THEN total_revenue END)) THEN 1
            WHEN MAX(CASE WHEN Year = 2023 THEN total_revenue END) = 
                 GREATEST(MAX(CASE WHEN Year = 2019 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2020 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2021 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2022 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2023 THEN total_revenue END),
                         MAX(CASE WHEN Year = 2024 THEN total_revenue END)) THEN 0.8
            ELSE 0.4
        END AS peak_timing_score,
        
        -- 4. Recovery Ability (25% weight)
        CASE 
            WHEN MAX(CASE WHEN Year = 2024 THEN total_revenue END) > MAX(CASE WHEN Year = 2022 THEN total_revenue END) 
            AND
			MAX(CASE WHEN Year = 2022 THEN total_revenue END) < MAX(CASE WHEN Year = 2021 THEN total_revenue END) THEN 1  -- Recovery after dip
            ELSE 0.6
        END AS recovery_score
    FROM category_revenue
    GROUP BY standard_ad_category
),
final_scoring AS (
    SELECT
        *,
        -- Combined Strength Score (0-100)
        (CASE WHEN net_growth_pct > 0.20 THEN 30
			WHEN net_growth_pct > 0.10 THEN 25
			WHEN net_growth_pct > 0.05 THEN 20
			WHEN net_growth_pct > -0.05 THEN 15
			WHEN net_growth_pct > -0.10 THEN 10
			WHEN net_growth_pct > -0.25 THEN 5
              ELSE 0 END) +
        (consistency_score * 6) +
        (peak_timing_score * 20) +
        (recovery_score * 20) AS total_strength_score
	FROM trend_metrics
),
final_classification AS (
    SELECT
        *,
        CASE 
            WHEN total_strength_score >= 80 THEN 'STRONG: Sustained Growth'
            WHEN total_strength_score >= 60 THEN 'STABLE: Consistent Performer'
            WHEN total_strength_score >= 40 THEN 'WATCH: Plateauing'
            WHEN total_strength_score >= 20 THEN 'DECLINING: Needs Intervention'
            ELSE 'CRITICAL: Severe Decline'
        END AS final_verdict
    FROM final_scoring
)
SELECT
    standard_ad_category,
    revenue_2019,
    revenue_2020,
    revenue_2021,
    revenue_2022,
    revenue_2023,
    revenue_2024,
    ROUND(net_growth_pct * 100, 2) AS net_growth_percent,
    consistency_score,
    peak_timing_score,
    recovery_score,
    total_strength_score,
    final_verdict
FROM final_classification
ORDER BY total_strength_score DESC, revenue_2024 DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 4. Which state has generated the most ad revenue, and how does that correlate with their print circulation?
WITH Edition_Ad_Revenue AS (
    SELECT
        edition_id,
        SUM(ad_revenue_inr) AS Total_Ad_Revenue_INR
    FROM ad_revenue
    GROUP BY edition_id
),
Edition_Circulation_City AS (
    SELECT
        edition_id,
        City_ID,
        ROUND(SUM(Net_Circulation), 2) AS Total_Net_Circulation
    FROM print_sales
    GROUP BY edition_id, City_ID
)
SELECT
    CD.city,
    CD.state,
    ROUND(SUM(EAR.Total_Ad_Revenue_INR), 2) AS Total_City_Ad_Revenue,
    ROUND(SUM(ECC.Total_Net_Circulation), 2) AS Total_City_Net_Circulation,
    ROUND(SUM(EAR.Total_Ad_Revenue_INR) / NULLIF(SUM(ECC.Total_Net_Circulation), 0),2) AS Revenue_Per_Net_Copy_Ratio
FROM city_data CD
JOIN Edition_Circulation_City ECC ON CD.city_id = ECC.city_id
JOIN Edition_Ad_Revenue EAR ON ECC.edition_id = EAR.edition_id
GROUP BY CD.city, CD.state
ORDER BY Total_City_Ad_Revenue DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Which cities show high digital readiness but had low digital pilot engagement?
WITH City_Readiness_Scores AS (
    SELECT
        city_id,
        AVG(literacy_rate + smartphone_penetration + internet_penetration) / 3 AS Avg_Readiness_Score
    FROM city_readiness
    GROUP BY city_id
),
City_Engagement_Scores AS (
    SELECT
        city_id,
        SUM(users_reached + downloads_or_accesses) AS Total_Engagement
    FROM digital_plot
    GROUP BY city_id
),
Global_Averages AS (
    SELECT
        (SELECT AVG(Avg_Readiness_Score) FROM City_Readiness_Scores) AS Global_Readiness_Avg,
        (SELECT AVG(Total_Engagement) FROM City_Engagement_Scores) AS Global_Engagement_Avg 
)
SELECT
    CD.city,
    CD.state,
    ROUND(CRS.Avg_Readiness_Score, 2) AS Avg_Readiness_Score,
    CES.Total_Engagement
FROM city_data CD
JOIN City_Readiness_Scores CRS ON CD.city_id = CRS.city_id
JOIN City_Engagement_Scores CES ON CD.city_id = CES.city_id
CROSS JOIN Global_Averages GA
WHERE
	CRS.Avg_Readiness_Score > GA.Global_Readiness_Avg
    AND
    CES.Total_Engagement < GA.Global_Engagement_Avg
ORDER BY CRS.Avg_Readiness_Score DESC, CES.Total_Engagement ASC;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 6.Which cities had the highest ad revenue per net circulated copy? Is this ratio  improving or worsening over time?
WITH City_Yearly_Metrics AS (
    SELECT
        CD.city_id,
        CD.city,
        AR.year,
        SUM(AR.ad_revenue_inr) AS Yearly_Ad_Revenue,
        SUM(PS.Net_Circulation) AS Yearly_Net_Circulation
    FROM city_data CD
    INNER JOIN print_sales PS ON CD.city_id = PS.city_id
    INNER JOIN Ad_Revenue AR ON PS.edition_id = AR.edition_id AND PS.year = AR.year
    GROUP BY CD.city_id, CD.city, AR.year
    HAVING SUM(PS.Net_Circulation) > 0 
),
City_Performance AS (
    SELECT
        city_id,
        city,
        year,
        Yearly_Ad_Revenue,
        Yearly_Net_Circulation,
        ROUND(CAST(Yearly_Ad_Revenue AS DECIMAL(18, 2)) / Yearly_Net_Circulation,4) AS Revenue_Per_Copy_Ratio
    FROM City_Yearly_Metrics
)
SELECT
    city,
    year,
    Revenue_Per_Copy_Ratio,
    LAG(Revenue_Per_Copy_Ratio, 1) OVER (PARTITION BY city_id ORDER BY year) AS Previous_Year_Ratio,
    ROUND((Revenue_Per_Copy_Ratio - LAG(Revenue_Per_Copy_Ratio, 1) OVER (PARTITION BY city_id ORDER BY year)) * 100.0 / NULLIF(LAG(Revenue_Per_Copy_Ratio, 1) OVER (PARTITION BY city_id ORDER BY year), 0),2) AS YoY_Ratio_Change_Percentage,
    CASE
        WHEN LAG(Revenue_Per_Copy_Ratio, 1) OVER (PARTITION BY city_id ORDER BY year) IS NULL THEN 'No Prior Year Data'
        WHEN Revenue_Per_Copy_Ratio > LAG(Revenue_Per_Copy_Ratio, 1) OVER (PARTITION BY city_id ORDER BY year) THEN 'Improving (Wider Margin)'
        WHEN Revenue_Per_Copy_Ratio < LAG(Revenue_Per_Copy_Ratio, 1) OVER (PARTITION BY city_id ORDER BY year) THEN 'Worsening (Tighter Margin)'
        ELSE 'Stable'
    END AS Ratio_Trend
FROM City_Performance
ORDER BY year DESC, Revenue_Per_Copy_Ratio DESC; 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 7. Based on digital readiness, pilot engagement, and print decline, which 3 cities should be prioritized for Phase 1 of the digital relaunch?
WITH City_Readiness_Scores AS (
    SELECT
        city_id,
        AVG(literacy_rate + smartphone_penetration + internet_penetration) / 3 AS Avg_Readiness_Score
    FROM city_readiness
    GROUP BY city_id
),
City_Engagement_Scores AS (
    SELECT
        city_id,
        SUM(users_reached + downloads_or_accesses) AS Total_Engagement
    FROM digital_plot
    GROUP BY city_id
),
City_Print_Decline AS (
    WITH Yearly_Circulation AS (
        SELECT
            city_id,
            year,
            SUM(Net_Circulation) AS Yearly_Net_Circulation,
            (SUM(Net_Circulation) - LAG(SUM(Net_Circulation), 1) OVER (PARTITION BY city_id ORDER BY year)) * 100.0
            / NULLIF(LAG(SUM(Net_Circulation), 1) OVER (PARTITION BY city_id ORDER BY year), 0) AS Net_Circulation_YoY_Change
        FROM print_sales
        GROUP BY city_id, year
    )
    SELECT
        city_id,
        AVG(Net_Circulation_YoY_Change) AS Avg_Decline_Rate
    FROM Yearly_Circulation
    WHERE Net_Circulation_YoY_Change IS NOT NULL
    GROUP BY city_id
)
SELECT
    CD.city,
    CD.state,
    CD.tier,
    ROUND(CRS.Avg_Readiness_Score, 4) AS Avg_Readiness_Score,
    CES.Total_Engagement,
    ROUND(CPD.Avg_Decline_Rate, 2) AS Avg_Decline_Rate_Percent,
    NTILE(4) OVER (ORDER BY CRS.Avg_Readiness_Score DESC) AS Readiness_Priority, -- Higher Score = Higher Priority
    NTILE(4) OVER (ORDER BY CES.Total_Engagement ASC) AS Engagement_Priority,    -- Lower Engagement = Higher Priority
    NTILE(4) OVER (ORDER BY CPD.Avg_Decline_Rate ASC) AS Decline_Priority,       -- Steeper Decline = Higher Priority
    (
        NTILE(4) OVER (ORDER BY CRS.Avg_Readiness_Score DESC) +
        NTILE(4) OVER (ORDER BY CES.Total_Engagement ASC) +
        NTILE(4) OVER (ORDER BY CPD.Avg_Decline_Rate ASC)
    ) AS Prioritization_Score
FROM
    city_data CD
INNER JOIN City_Readiness_Scores CRS ON CD.city_id = CRS.city_id
INNER JOIN City_Engagement_Scores CES ON CD.city_id = CES.city_id
INNER JOIN City_Print_Decline CPD ON CD.city_id = CPD.city_id 
ORDER BY Prioritization_Score DESC, Avg_Readiness_Score DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 8.Top 3 months (2019–2024) where any city recorded the sharpest month-over-month decline in net_circulation.
WITH Monthly_Circulation AS (
    SELECT
        CD.city_id,
        CD.city AS city_name,
        PS.year, 
        PS.month_num,
        CAST(PS.year AS CHAR) || '-' || LPAD(CAST(PS.month_num AS CHAR), 2, '0') AS month_year_key,
        SUM(PS.Net_Circulation) AS Current_Month_Circulation
    FROM print_sales PS
    JOIN city_data CD ON PS.city_id = CD.city_id
    GROUP BY CD.city_id, CD.city, PS.year, PS.month_num
    ORDER BY CD.city_id, month_year_key 
),
MoM_Decline AS (
    SELECT
        city_name,
        year, 
        month_year_key AS month_key,
        Current_Month_Circulation AS net_circulation,
        LAG(Current_Month_Circulation, 1) OVER (PARTITION BY city_id ORDER BY month_year_key) AS Previous_Month_Circulation
    FROM Monthly_Circulation
),
Decline_Analysis AS (
    SELECT
        city_name,
        year, 
        month_key AS month,
        net_circulation,
        ROUND((net_circulation - Previous_Month_Circulation) * 100.0 / NULLIF(Previous_Month_Circulation, 0),2) AS MoM_Decline_Percentage,
        ROW_NUMBER() OVER (ORDER BY (net_circulation - Previous_Month_Circulation) * 100.0 / NULLIF(Previous_Month_Circulation, 0) ASC) AS Decline_Rank
    FROM MoM_Decline
    WHERE
       (net_circulation - Previous_Month_Circulation) < 0 AND Previous_Month_Circulation IS NOT NULL 
)
SELECT
    city_name,
    year, 
    month,
    net_circulation,
    MoM_Decline_Percentage
FROM Decline_Analysis
WHERE Decline_Rank <= 3
ORDER BY MoM_Decline_Percentage ASC;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 9. 2024 Print Efficiency Leaderboard
WITH City_2024_Metrics AS (
    SELECT
        city_id,
        SUM(Net_Circulation) AS net_circulation_2024,
        SUM(copies_sold + copies_returned) AS copies_printed_2024
    FROM print_sales
    WHERE year = 2024
    GROUP BY city_id
    HAVING SUM(copies_sold + copies_returned) > 0
),
Efficiency_Ranked AS (
    SELECT
        CM.city_id,
        CM.net_circulation_2024,
        CM.copies_printed_2024,
        (CAST(CM.net_circulation_2024 AS DECIMAL(18, 4)) / CM.copies_printed_2024) AS efficiency_ratio,
        RANK() OVER (ORDER BY (CAST(CM.net_circulation_2024 AS DECIMAL(18, 4)) / CM.copies_printed_2024) DESC) AS efficiency_rank_2024
    FROM City_2024_Metrics CM
)
SELECT
    CD.city AS city_name,
    ER.copies_printed_2024,
    ER.net_circulation_2024,
    ROUND(ER.efficiency_ratio, 4) AS efficiency_ratio,
    ER.efficiency_rank_2024
FROM Efficiency_Ranked ER
JOIN city_data CD ON ER.city_id = CD.city_id
WHERE ER.efficiency_rank_2024 <= 5
ORDER BY ER.efficiency_rank_2024 ASC;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 10. Internet Readiness Growth (2021)
WITH Q1_Q4_Penetration AS (
    SELECT
        city_id,
        MAX(CASE WHEN quarter_num = 1 THEN internet_penetration END) AS internet_rate_q1_2021,
        MAX(CASE WHEN quarter_num = 4 THEN internet_penetration END) AS internet_rate_q4_2021
    FROM city_readiness
    WHERE year = 2021 AND quarter_num IN (1, 4)
    GROUP BY city_id
    HAVING MAX(CASE WHEN quarter_num = 1 THEN 1 END) IS NOT NULL AND MAX(CASE WHEN quarter_num = 4 THEN 1 END) IS NOT NULL
)
SELECT
    CD.city AS city_name,
    Q.internet_rate_q1_2021,
    Q.internet_rate_q4_2021,
    ROUND(Q.internet_rate_q4_2021 - Q.internet_rate_q1_2021, 4) AS delta_internet_rate
FROM Q1_Q4_Penetration Q
JOIN city_data CD ON Q.city_id = CD.city_id
ORDER BY delta_internet_rate DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 11. Identify the cities that have experienced the most frequent negative year-over-year trends
WITH City_Yearly_Metrics AS (
    SELECT CD.city_id, CD.city AS city_name, AR.year,
           SUM(PS.Net_Circulation) AS yearly_net_circulation,
           SUM(AR.ad_revenue_inr) AS yearly_ad_revenue
    FROM city_data CD
    JOIN print_sales PS ON CD.city_id = PS.city_id
    JOIN ad_revenue AR ON PS.edition_id = AR.edition_id AND PS.year = AR.year
    WHERE AR.year BETWEEN 2019 AND 2024
    GROUP BY CD.city_id, CD.city, AR.year
),
YoY_Decline_Flags AS (
    SELECT *,
        CASE WHEN yearly_net_circulation < LAG(yearly_net_circulation) OVER (PARTITION BY city_id ORDER BY year) THEN 1 ELSE 0 END AS print_declined_flag,
        CASE WHEN yearly_ad_revenue < LAG(yearly_ad_revenue) OVER (PARTITION BY city_id ORDER BY year) THEN 1 ELSE 0 END AS ad_declined_flag
    FROM City_Yearly_Metrics
    WHERE year >= 2020
),
Decline_Summary AS (
    SELECT
        city_id,
        city_name,
        SUM(print_declined_flag) AS num_print_declines,
        SUM(ad_declined_flag) AS num_ad_declines
    FROM YoY_Decline_Flags
    GROUP BY city_id, city_name
)
SELECT
    city_name,
    num_print_declines,
    num_ad_declines,
    (num_print_declines + num_ad_declines) AS total_decline_events
FROM
    Decline_Summary
ORDER BY
    total_decline_events DESC,
    num_print_declines DESC   
LIMIT 5;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
