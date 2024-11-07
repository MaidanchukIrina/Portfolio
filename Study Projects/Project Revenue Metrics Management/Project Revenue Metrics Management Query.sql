-- CTE для розрахунку загального доходу для кожного користувача та гри за кожен місяць
WITH monthly_data AS (
    SELECT
        DATE_TRUNC('month', gp.payment_date) AS year_month,  -- Перший день місяця
        gp.user_id,  -- Ідентифікатор користувача
        gp.game_name,  -- Назва гри
        SUM(gp.revenue_amount_usd) AS total_revenue  -- Загальний дохід за місяць
    FROM
        project.games_payments gp
    GROUP BY
        DATE_TRUNC('month', gp.payment_date),
        gp.user_id,
        gp.game_name
),

-- CTE для отримання попереднього та наступного місяця для кожного користувача
prev_next_month_data AS (
    SELECT
        md.year_month,  -- Місяць доходу
        md.user_id,
        md.game_name,
        md.total_revenue,
        LAG(md.total_revenue) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS prev_month_revenue,  -- Дохід за попередній місяць
        LAG(md.year_month) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS prev_payment_month,  -- Попередній місяць
        LEAD(md.year_month) OVER (PARTITION BY md.user_id ORDER BY md.year_month) AS next_payment_month  -- Наступний місяць
    FROM
        monthly_data md
),

-- CTE для отримання інформації про користувачів
user_data AS (
    SELECT 
        gpu.user_id,  -- Ідентифікатор користувача
        gpu."language",  -- Мова користувача
        gpu.has_older_device_model,  -- Чи має користувач застарілу модель пристрою
        gpu.age  -- Вік користувача
    FROM
        project.games_paid_users gpu
),

-- CTE для розрахунку основних метрик
final_data AS (
    SELECT
        pnm.year_month,  -- Місяць доходу
        pnm.user_id,
        pnm.game_name,
        COUNT(DISTINCT pnm.user_id) AS paid_users,  -- Кількість платних користувачів
        SUM(pnm.total_revenue) AS MRR,  -- Щомісячний повторюваний дохід
        ROUND(SUM(pnm.total_revenue) / COUNT(DISTINCT pnm.user_id), 2) AS ARPPU,  -- Середній дохід на одного платного користувача
        SUM(CASE WHEN pnm.prev_month_revenue IS NULL THEN pnm.total_revenue ELSE 0 END) AS new_mrr,  -- Новий MRR від нових платних користувачів
        COUNT(DISTINCT CASE WHEN pnm.next_payment_month IS NULL THEN pnm.user_id END) AS churned_users,  -- Кількість користувачів, що відмовилися від підписки
        SUM(CASE WHEN pnm.next_payment_month IS NULL THEN pnm.total_revenue ELSE 0 END) AS churned_revenue  -- Дохід від користувачів, що відмовилися
    FROM
        prev_next_month_data pnm
    GROUP BY
        pnm.year_month,
        pnm.user_id,
        pnm.game_name
)
-- Фінальний запит з обчисленням коефіцієнтів відтоку та зростання доходу
SELECT
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
    -- Розрахунок Churn Rate на основі попереднього місяця
    ROUND(
        CASE
            WHEN LAG(fd.paid_users) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month) > 0
            THEN fd.churned_users::NUMERIC / LAG(fd.paid_users) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month) * 100
            ELSE 0
        END, 2
    ) AS churn_rate,
    -- Розрахунок Revenue Churn Rate
    ROUND(
        CASE
            WHEN LAG(fd.MRR) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month) > 0
            THEN fd.churned_revenue / LAG(fd.MRR) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month) * 100
            ELSE 0
        END, 2
    ) AS revenue_churn_rate,
    -- Розрахунок Expansion MRR
    ROUND(
        COALESCE(
            CASE
                WHEN fd.MRR > LAG(fd.MRR) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month)
                THEN fd.MRR - LAG(fd.MRR) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month)
                ELSE 0
            END, 0
        ), 2
    ) AS expansion_mrr,
    -- Розрахунок Contraction MRR
    ROUND(
        COALESCE(
            CASE
                WHEN fd.MRR < LAG(fd.MRR) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month)
                THEN LAG(fd.MRR) OVER (PARTITION BY fd.user_id ORDER BY fd.year_month) - fd.MRR
                ELSE 0
            END, 0
        ), 2
    ) AS contraction_mrr
FROM
    final_data fd
LEFT JOIN 
    user_data ud ON fd.user_id = ud.user_id
ORDER BY
    fd.year_month,
    fd.user_id,
    fd.game_name;

    --Опис коментарів
--monthly_data: Формує щомісячний дохід для кожного користувача і гри.
--prev_next_month_data: Додає значення попереднього і наступного місяця для обчислення відтоку.
--user_data: Інформація про користувачів, включаючи мову і вік.
--final_data: Розрахунок метрик, включаючи MRR, ARPPU, new_mrr, churned_users, і churned_revenue.
--Фінальний запит: Обчислює churn_rate, revenue_churn_rate, expansion_mrr, і contraction_mrr.
