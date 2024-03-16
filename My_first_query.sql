select
ad_date, 
spend, 
clicks,
spend/clicks as one_click_price
from
public.facebook_ads_basic_daily
WHERE 
clicks>0
order by
ad_date desc;
