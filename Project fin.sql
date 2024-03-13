WITH monthly_data AS (
    SELECT
        DATE_TRUNC('month', gp.payment_date) AS year_month,
        gp.user_id,
        gp.game_name,
        SUM(gp.revenue_amount_usd) AS total_revenue
    FROM
        project.games_payments gp
    GROUP BY
        year_month,
        user_id,
        game_name
),
prev_next_month_data AS (
    SELECT
        md.year_month,
        md.user_id,
        md.game_name,
        md.total_revenue,
        LAG(md.total_revenue) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS prev_month_revenue,
        (md.year_month - interval '1' month) as previous_calendar_month,
        (md.year_month + interval '1' month) as next_calendar_month,
        LAG(md.year_month) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS prev_payment_month,
        LEAD(md.year_month) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS next_payment_month
    FROM
        monthly_data md
    ORDER BY
        md.year_month
),
user_data as (
    select 
        gpu.user_id ,
        gpu."language",
        gpu.has_older_device_model ,
        gpu.age 
    from
        project.games_paid_users gpu
    order by gpu.user_id 
),
final_data as (
    SELECT
        pnm.year_month,
        pnm.user_id,
        pnm.game_name,
        COUNT(DISTINCT pnm.user_id) AS paid_users,
        SUM(pnm.total_revenue) AS MRR,
        ROUND(SUM(pnm.total_revenue) / COUNT(DISTINCT pnm.user_id), 2) AS ARPPU,
        SUM(CASE WHEN pnm.prev_month_revenue IS NULL THEN pnm.total_revenue ELSE 0 END) AS new_mrr,
        COUNT(DISTINCT CASE WHEN pnm.next_payment_month is null THEN pnm.user_id END) AS churned_users,
        sum(case when pnm.next_payment_month is null then pnm.total_revenue else 0 end) as churned_revenue
        FROM
        prev_next_month_data pnm
    GROUP BY
        pnm.year_month,
        pnm.user_id,
        pnm.game_name
)
select
    fd.user_id,
    fd.game_name,
    ud."language",
    ud.age, 
    fd.year_month,
    fd.paid_users,
    fd.MRR,
    fd.ARPPU,
    fd.new_mrr,
    fd.churned_users,
    fd.churned_revenue,
    ROUND(
        CASE
            WHEN LAG(fd.paid_users) OVER (partition by fd.user_id ORDER BY fd.year_month) > 0 THEN fd.churned_users::numeric / LAG(fd.paid_users) OVER (partition by fd.user_id ORDER BY fd.year_month) * 100
            ELSE 0
        END, 2
    ) AS churn_rate,
    ROUND(
        CASE
            WHEN LAG(fd.MRR) OVER (partition by fd.user_id ORDER BY fd.year_month) > 0 THEN fd.churned_revenue/ LAG(fd.MRR) OVER (partition by fd.user_id ORDER BY fd.year_month) * 100
            ELSE 0
        END, 2
    ) AS revenue_churn_rate,
     ROUND(
        coalesce (CASE
            WHEN fd.MRR>LAG(fd.MRR) OVER (partition by fd.user_id ORDER BY fd.user_id) THEN fd.MRR-LAG(fd.MRR) OVER (partition by fd.user_id ORDER BY fd.user_id)
            ELSE 0
        END, 0),2
    ) AS expancion_mrr,
    ROUND(
        coalesce (CASE
            WHEN fd.MRR<LAG(fd.MRR) OVER (partition by fd.user_id ORDER BY fd.user_id) THEN fd.MRR-LAG(fd.MRR) OVER (partition by fd.user_id ORDER BY fd.user_id)
            ELSE 0
        END, 0),2
    ) AS contraction_mrr
FROM
    final_data fd
left join 
    user_data ud on  fd.user_id=ud.user_id 
ORDER BY
    fd.year_month,
    fd.user_id,
    fd.game_name;