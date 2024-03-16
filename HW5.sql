select ad_date, campaign_name, Total_spend, Total_impressions, Total_clicks, Total_value,
case 
	when Total_clicks>0 then round (SUM (Total_spend) :: numeric/ SUM (Total_clicks),2)
	else null
end as CPC,
case 
	when Total_impressions>0 then round ((sum(Total_spend)::numeric*1000) /sum(Total_impressions),2) 
	else null
end as CTM,
case 
	when Total_impressions>0 then round ((sum(Total_clicks)::numeric *100)/sum(Total_impressions),2) 
	else null
end as CTR,
case 
	when Total_spend>0 then round (((((sum(Total_value)::numeric-sum(Total_spend)::numeric))*100)/sum(Total_spend)::numeric ),2) 
	else null
end as ROMI,
case 
	when lower(substring(url_parameters, 'utm_campaign=([^&#$]+)'))='nan' then null
	else lower(substring(url_parameters, 'utm_campaign=([^&#$]+)'))
end as utm_campaign
from (
with FB_for_HW5_joined as
(select fabd.ad_date , fc.campaign_name , fa.adset_name , fabd.spend, fabd.impressions,fabd.reach , 
fabd.clicks , fabd.leads , fabd.value, fabd.url_parameters 
from facebook_ads_basic_daily fabd 
left join facebook_campaign as fc on fabd.campaign_id = fc.campaign_id
left join facebook_adset as fa on fabd.adset_id = fa.adset_id),
Google_for_HW5 as
(select gabd.ad_date, gabd.campaign_name,gabd.adset_name, gabd.spend , gabd.impressions , gabd.reach , gabd.clicks , 
gabd.leads , gabd.value, gabd.url_parameters 
from google_ads_basic_daily gabd)
select ad_date, campaign_name, adset_name, coalesce (spend,0) as Total_spend, coalesce (impressions,0) as Total_impressions, 
coalesce (reach,0) as Total_reach, coalesce (clicks,0) as Total_clicks, coalesce (leads,0) as Total_leads, 
coalesce (value,0) as Total_value, fb_for_hw5_joined.url_parameters
from FB_for_HW5_joined 
union all
select ad_date, campaign_name, adset_name, coalesce (spend,0) as Total_spend, coalesce (google_for_hw5.impressions,0) as Total_impressions, 
coalesce (reach,0) as Total_reach, coalesce (clicks,0) as Total_clicks, coalesce (leads,0) as Total_leads, 
coalesce (value,0) as Total_value, url_parameters
from Google_for_HW5) as t1
group by t1.ad_date, t1.campaign_name, t1.total_spend, t1.total_impressions, t1. Total_value, t1. total_clicks, t1.url_parameters
order by t1.ad_date asc 


