
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
        gp.user_id,
        gp.game_name
),

prev_next_month_data AS (
    SELECT
        md.year_month,
        md.user_id,
        md.game_name,
        md.total_revenue,
        LAG(md.total_revenue) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS prev_month_revenue,
        LEAD(md.total_revenue) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS next_month_revenue
    FROM
        monthly_data md
)

-- Final Query: Combining previous and next month revenue to calculate any relevant metrics (example metric here)
SELECT
    year_month,
    user_id,
    game_name,
    total_revenue,
    prev_month_revenue,
    next_month_revenue,
    COALESCE(next_month_revenue - total_revenue, 0) AS revenue_change_next_month
FROM
    prev_next_month_data
WHERE
    total_revenue IS NOT NULL
ORDER BY
    year_month, user_id, game_name;
