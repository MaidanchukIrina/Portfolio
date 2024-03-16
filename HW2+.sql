SELECT ad_date, campaign_id, sum(impressions) as Total_impression, 
sum (spend) as Total_spend, sum (clicks) as Total_clicks, sum (value) as Total_value,
round (SUM (spend) :: numeric/ SUM (clicks),2) as CPC,
round ((sum(spend)::numeric*1000) /sum(impressions),2) as CPM,
round ((sum(clicks)::numeric *100)/sum(impressions),2) as CTR,
round (((((sum(value)::numeric-sum(spend)::numeric))*100)/sum(spend)::numeric ),2) as ROMI
FROM public.facebook_ads_basic_daily
where clicks >0
group by ad_date, campaign_id
having sum(spend)>50000
order by round (((((sum(value)::numeric-sum(spend)::numeric))*100)/sum(spend)::numeric ),2) desc 




 