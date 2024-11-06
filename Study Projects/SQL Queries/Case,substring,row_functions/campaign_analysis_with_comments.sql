
-- Основний запит: Об'єднання даних з таблиць рекламних кампаній у Facebook і Google, обробка рядків та розрахунок метрик

SELECT 
    ad_date,  -- Дата показу реклами
    campaign_name,  -- Назва кампанії
    Total_spend,  -- Загальна сума витрат на рекламу
    Total_impressions,  -- Загальна кількість показів
    Total_clicks,  -- Загальна кількість кліків
    Total_value,  -- Загальна вартість конверсій

    -- Розрахунок CPC (вартість за клік), уникнення ділення на нуль
    CASE 
        WHEN Total_clicks > 0 THEN ROUND(SUM(Total_spend)::NUMERIC / SUM(Total_clicks), 2)
        ELSE NULL
    END AS CPC,

    -- Розрахунок CPM (вартість за 1000 показів), уникнення ділення на нуль
    CASE 
        WHEN Total_impressions > 0 THEN ROUND((SUM(Total_spend)::NUMERIC * 1000) / SUM(Total_impressions), 2)
        ELSE NULL
    END AS CPM,

    -- Розрахунок CTR (клікабельність), уникнення ділення на нуль
    CASE 
        WHEN Total_impressions > 0 THEN ROUND((SUM(Total_clicks)::NUMERIC * 100) / SUM(Total_impressions), 2)
        ELSE NULL
    END AS CTR,

    -- Розрахунок ROMI (рентабельність інвестицій у маркетинг), уникнення ділення на нуль
    CASE 
        WHEN Total_spend > 0 THEN ROUND(((SUM(Total_value)::NUMERIC - SUM(Total_spend)::NUMERIC) * 100) / SUM(Total_spend)::NUMERIC, 2)
        ELSE NULL
    END AS ROMI,

    -- Витягнення UTM-параметра utm_campaign з URL, заміна 'nan' на NULL
    CASE 
        WHEN LOWER(SUBSTRING(url_parameters, 'utm_campaign=([^&#$]+)')) = 'nan' THEN NULL
        ELSE LOWER(SUBSTRING(url_parameters, 'utm_campaign=([^&#$]+)'))
    END AS utm_campaign

FROM (
    -- З'єднання таблиць Facebook для отримання даних кампаній та метрик
    WITH FB_for_HW5_joined AS (
        SELECT 
            fabd.ad_date, 
            fc.campaign_name, 
            fa.adset_name, 
            fabd.spend, 
            fabd.impressions, 
            fabd.reach, 
            fabd.clicks, 
            fabd.leads, 
            fabd.value, 
            fabd.url_parameters 
        FROM 
            facebook_ads_basic_daily AS fabd
        JOIN 
            facebook_adset AS fa ON fabd.adset_id = fa.adset_id
        JOIN 
            facebook_campaign AS fc ON fa.campaign_id = fc.campaign_id
    ),
    -- З'єднання таблиць Google для отримання даних про покази та метрики рекламних кампаній
    Google_for_HW5_joined AS (
        SELECT 
            gad.ad_date, 
            gad.campaign_name, 
            gad.spend, 
            gad.impressions, 
            gad.clicks, 
            gad.conversions AS leads, 
            gad.value, 
            gad.url_parameters 
        FROM 
            google_ads_basic_daily AS gad
    )

    -- Об'єднання даних з Facebook та Google
    SELECT * FROM FB_for_HW5_joined
    UNION ALL
    SELECT * FROM Google_for_HW5_joined
) AS Combined_data

GROUP BY 
    ad_date, campaign_name, utm_campaign
ORDER BY 
    ad_date, campaign_name;
