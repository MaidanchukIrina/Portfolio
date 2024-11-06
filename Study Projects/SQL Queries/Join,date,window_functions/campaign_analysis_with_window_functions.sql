
-- CTE об'єднує дані з Facebook та Google для аналізу
WITH T2_for_HW6 AS (
    SELECT 
        DATE_TRUNC('month', fabd.ad_date)::DATE AS ad_month, -- Перше число місяця для кожного показу реклами
        fc.campaign_name, -- Назва кампанії
        fa.adset_name, -- Назва набору оголошень
        COALESCE(fabd.spend, 0) AS Total_spend, -- Витрати на рекламу (заміна null на 0)
        COALESCE(fabd.impressions, 0) AS Total_impressions, -- Кількість показів (заміна null на 0)
        COALESCE(fabd.reach, 0) AS Total_reach, -- Охоплення
        COALESCE(fabd.clicks, 0) AS Total_clicks, -- Кількість кліків
        COALESCE(fabd.leads, 0) AS Total_leads, -- Ліди
        COALESCE(fabd.value, 0) AS Total_value, -- Значення конверсій
        fabd.url_parameters -- URL параметри для витягнення UTM-кампанії
    FROM 
        facebook_ads_basic_daily AS fabd
    LEFT JOIN 
        facebook_campaign AS fc ON fabd.campaign_id = fc.campaign_id
    LEFT JOIN 
        facebook_adset AS fa ON fabd.adset_id = fa.adset_id
    UNION ALL
    SELECT 
        DATE_TRUNC('month', gabd.ad_date)::DATE AS ad_month,
        gabd.campaign_name, 
        gabd.adset_name, 
        COALESCE(gabd.spend, 0) AS Total_spend, 
        COALESCE(gabd.impressions, 0) AS Total_impressions, 
        COALESCE(gabd.reach, 0) AS Total_reach, 
        COALESCE(gabd.clicks, 0) AS Total_clicks, 
        COALESCE(gabd.conversions, 0) AS Total_leads, 
        COALESCE(gabd.value, 0) AS Total_value, 
        gabd.url_parameters 
    FROM 
        google_ads_basic_daily AS gabd
),

-- Другий CTE агрегує дані по місяцях для подальшого аналізу
part_2 AS (
    SELECT 
        ad_month, 
        SUBSTRING(url_parameters, 'utm_campaign=([^&#$]+)') AS utm_campaign, -- Витягування utm_campaign з URL
        SUM(Total_spend) AS Total_spend, 
        SUM(Total_impressions) AS Total_impressions, 
        SUM(Total_clicks) AS Total_clicks, 
        SUM(Total_value) AS Total_value,
        -- Розрахунок метрик CTR, CPC, CPM, ROMI для кожного місяця
        CASE WHEN SUM(Total_impressions) > 0 THEN ROUND((SUM(Total_clicks)::NUMERIC * 100) / SUM(Total_impressions), 2) ELSE NULL END AS CTR,
        CASE WHEN SUM(Total_clicks) > 0 THEN ROUND(SUM(Total_spend)::NUMERIC / SUM(Total_clicks), 2) ELSE NULL END AS CPC,
        CASE WHEN SUM(Total_impressions) > 0 THEN ROUND((SUM(Total_spend)::NUMERIC * 1000) / SUM(Total_impressions), 2) ELSE NULL END AS CPM,
        CASE WHEN SUM(Total_spend) > 0 THEN ROUND(((SUM(Total_value)::NUMERIC - SUM(Total_spend)) * 100) / SUM(Total_spend), 2) ELSE NULL END AS ROMI
    FROM 
        T2_for_HW6
    GROUP BY 
        ad_month, utm_campaign
),

-- Фінальний запит обчислює відсоткову різницю метрик CPM, CTR, ROMI порівняно з попереднім місяцем
final_result AS (
    SELECT 
        ad_month, 
        utm_campaign, 
        Total_spend, 
        Total_impressions, 
        Total_clicks, 
        Total_value, 
        CTR, 
        CPC, 
        CPM, 
        ROMI,
        -- Відсоткова зміна CPM
        ROUND((CPM - LAG(CPM) OVER (PARTITION BY utm_campaign ORDER BY ad_month)) * 100 / LAG(CPM) OVER (PARTITION BY utm_campaign ORDER BY ad_month), 2) AS CPM_diff_percentage,
        -- Відсоткова зміна CTR
        ROUND((CTR - LAG(CTR) OVER (PARTITION BY utm_campaign ORDER BY ad_month)) * 100 / LAG(CTR) OVER (PARTITION BY utm_campaign ORDER BY ad_month), 2) AS CTR_diff_percentage,
        -- Відсоткова зміна ROMI
        ROUND((ROMI - LAG(ROMI) OVER (PARTITION BY utm_campaign ORDER BY ad_month)) * 100 / LAG(ROMI) OVER (PARTITION BY utm_campaign ORDER BY ad_month), 2) AS ROMI_diff_percentage
    FROM 
        part_2
)

-- Виведення фінального результату
SELECT * FROM final_result
ORDER BY ad_month, utm_campaign;
