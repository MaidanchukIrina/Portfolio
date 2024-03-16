with T2_for_HW6 as 
(select date (date_trunc('month', fabd.ad_date)) as ad_month, campaign_name, adset_name, coalesce (spend,0) as Total_spend, coalesce (impressions,0) as Total_impressions, 
coalesce (reach,0) as Total_reach, coalesce (clicks,0) as Total_clicks, coalesce (leads,0) as Total_leads, 
coalesce (value,0) as Total_value, url_parameters
from facebook_ads_basic_daily fabd 
left join facebook_campaign as fc on fabd.campaign_id = fc.campaign_id
left join facebook_adset as fa on fabd.adset_id = fa.adset_id
union all
select date (date_trunc('month', gabd.ad_date)) as ad_month, campaign_name, adset_name, coalesce (spend,0) as Total_spend, coalesce (impressions,0) as Total_impressions, 
coalesce (reach,0) as Total_reach, coalesce (clicks,0) as Total_clicks, coalesce (leads,0) as Total_leads, 
coalesce (value,0) as Total_value, url_parameters
from google_ads_basic_daily gabd),
part_2 as(
select ad_month, substring(url_parameters,'utm_campaign=([^&#$]+)') as utm_campaign, sum(Total_spend), sum(Total_impressions), sum(Total_clicks), sum(Total_value),
case 
	when sum(Total_clicks)>0 then round (SUM (Total_spend) :: numeric/ SUM (Total_clicks),2)
	else null
end as CPC,
case 
	when sum(Total_impressions)>0 then round ((sum(Total_spend)::numeric*1000) /sum(Total_impressions),2) 
	else null
end as CTM,
case 
	when sum(Total_impressions)>0 then round ((sum(Total_clicks)::numeric *100)/sum(Total_impressions),2) 
	else null
end as CTR,
case 
	when sum(Total_spend)>0 then round (((((sum(Total_value)::numeric-sum(Total_spend)::numeric))*100)/sum(Total_spend)::numeric ),2) 
	else null
end as ROMI
from T2_for_HW6
group by utm_campaign, ad_month)
select *,
round (part_2.CPC/lag (CPC) over (partition by utm_campaign order by part_2.ad_month desc),2) as dif_CPC,
round (part_2.CTM/lag (CTM) over (partition by utm_campaign order by part_2.ad_month desc),2) as dif_CTM,
round (part_2.CTR/lag (CTR) over (partition by utm_campaign order by part_2.ad_month desc),2) as dif_CTR,
round (part_2.ROMI/lag(romi) over(partition by utm_campaign order by part_2.ad_month desc),2) as dif_ROMI
from part_2
where CPC>0 and CTM>0 and CTR>0 and ROMI>0
order by 2,1
