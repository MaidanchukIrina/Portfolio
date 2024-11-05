select t1.campaign_name, sum (spend) as Total_spend, sum (impressions) as Total_impressions, 
sum (clicks ) as Total_clicks, sum (value) as Total_value,
round (((((sum(value)::numeric-sum(spend)::numeric))*100)/sum(spend)::numeric ),2) as ROMI
from (
with 
FB_for_HW3_joined as
(select fabd.ad_date , fc.campaign_name , fa.adset_name , fabd.spend, fabd.impressions,fabd.reach , 
fabd.clicks , fabd.leads , fabd.value
from facebook_ads_basic_daily fabd 
left join facebook_campaign as fc on fabd.campaign_id = fc.campaign_id
left join facebook_adset as fa on fabd.adset_id = fa.adset_id),
Google_for_HW3 as
(select gabd.ad_date, gabd.campaign_name,gabd.adset_name, gabd.spend , gabd.impressions , gabd.reach , gabd.clicks , 
gabd.leads , gabd.value 
from google_ads_basic_daily gabd)
select *
from FB_for_HW3_joined 
union all
select *
from Google_for_hw3) as t1
where t1.ad_date is not null 
group by t1.campaign_name
having sum(spend)>500000
order by round (((((sum(value)::numeric-sum(spend)::numeric))*100)/sum(spend)::numeric ),2) desc
limit 1

