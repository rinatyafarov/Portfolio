/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Яфаров Ринат
 * Дата: 07.10.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- рассчитываем общее количество игроков, зарегистрированных в игре:
WITH count_us AS (
	SELECT
	*,
	COUNT(id) OVER() AS users_count --количество игроков, зарегистрированных в игре
	FROM fantasy.users
),
 --рассчитываем общее количество платящих игроков, зарегистрированных в игре:
pay_users AS (
	SELECT
	users_count, --количество игроков, зарегистрированных в игре
	COUNT(*) AS count_pay_users  --количество платящих игроков
	FROM count_us
	WHERE payer = 1
	GROUP BY users_count)
-- рассчитываем долю платящих игроков от общего количества пользователей, зарегистрированных в игре.
SELECT 
	users_count,--количество игроков, зарегистрированных в игре
	count_pay_users,--количество платящих игроков
	ROUND(count_pay_users::numeric/users_count::NUMERIC,3) AS fraction_pay_users --доля платящих игроков от общего количества пользователей, зарегистрированных в игре.
FROM pay_users


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
--рассчитаем общее количество игроков в разрезе каждом расы:
WITH count_race_users AS(
	SELECT 
	race,--раса персонажа
	COUNT(id) AS count_race_id --общее количество игроков
	FROM fantasy.users
	JOIN fantasy.race USING(race_id)
	GROUP BY race
	ORDER BY count_race_id desc
),
--рассчитаем общее количество платящих игроков в разрезе каждой разы:
count_pay_race_users AS(
	SELECT
	race, 
	COUNT(*) AS count_pay_race_id  --количество платящих игроков в разрезе рас
	FROM fantasy.users
	JOIN fantasy.race USING(race_id)
	WHERE payer = 1
	GROUP BY race)
--рассчитаем долю платящих игроков от общего количества пользователей, зарегистрированных в игре в разрезе каждой расы персонажа и выведем результаты вычислений
SELECT 
	race,--раса персонажа
	count_race_id,--общее количество игроков
	count_pay_race_id,--количество платящих игроков в разрезе рас
	ROUND(count_pay_race_id::numeric/count_race_id::numeric,3) AS fraction_users_race --доля платящих игроков в разрезе каждой расы
FROM count_race_users
JOIN count_pay_race_users USING(race)
ORDER BY fraction_users_race DESC

	
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT(*) AS count_transaction,--общее количество покупок;
	SUM(amount) AS sum_amount,--суммарную стоимость всех покупок;
	MIN(amount) AS min_amount,--минимальную стоимость покупки;
	MAX(amount) AS max_amount,--максимальную стоимость покупки
	AVG(amount) AS avg_amount,--среднее значение стоимости покупки
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,--медиану стоимости покупки
	STDDEV(amount) AS stav_amount -- стандартное отклонение стоимости покупки
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
--Проверяем существуют ли покупки с нулевой стоимостью:
SELECT *
FROM fantasy.events 
WHERE amount = 0
--записи существуют, значит рассчитываем общее количество числа нулевых покупок:
WITH count_events AS (
	SELECT
	*,
	COUNT(*) OVER() AS count_transaction--общее количество покупок;
	FROM fantasy.events),
count_zero_events AS (
	SELECT 
	count_transaction,--общее количество покупок
	COUNT(*) AS count_zero_transaction --количество нулевых покупок
	FROM count_events 
	WHERE amount = 0
	GROUP BY count_transaction
)
SELECT 
	count_transaction,--общее количество покупок
	count_zero_transaction,--количество нулевых покупок
	ROUND(count_zero_transaction::NUMERIC/count_transaction::NUMERIC,3) AS fraction_zero_transaction --доля нулевых покупок от общего числа покупок
FROM count_zero_events;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
SELECT 
    CASE 
    	WHEN upayer = 1
    		THEN 'Платящие игроки'
    	ELSE 'Не платящие игроки'
    END AS
    upayer,
    COUNT(uid) AS total_users, --общее количество игроков для каждой категории
    AVG(total_transactions) AS avg_total_transactions,--среднее количество покупок для каждой категории
    AVG(total_spent) AS avg_spent_per_users --среднюю суммарную стоимость покупок на одного игрока
FROM (
    SELECT 
        u.id AS uid,
        u.payer AS upayer,
        COUNT(e.transaction_id) AS total_transactions,
        SUM(e.amount) AS total_spent
    FROM fantasy.users AS u
    LEFT JOIN fantasy.events AS e ON e.id = u.id
    WHERE e.amount > 0
    GROUP BY u.id, u.payer
) AS users_stat
GROUP BY upayer;
-- 2.4: Популярные эпические предметы:
--рассчитаем общее количество внутриигровых продаж в абсолютном значении в разрезе каждого предмета
WITH count_items AS (
	SELECT 
		item_code,
		COUNT(amount) AS count_items_transaction --общее количество внутриигровых продаж в абсолютном значении в разрезе каждого предмета
	FROM fantasy.events
	WHERE amount > 0
	GROUP BY item_code
),
-- рассчитаем количество игроков, купивших хотя бы один раз предмет
count_buy_users AS (
	SELECT
		item_code,
		COUNT(DISTINCT id) AS count_id --количество игроков, купивших хотя бы один раз предмет
	FROM fantasy.events
	GROUP BY item_code
)
SELECT 
	i.game_items,--название предмета
	ci.count_items_transaction,--общее количество внутриигровых продаж в абсолютном значении в разрезе каждого предмета
	ci.count_items_transaction::NUMERIC/(SELECT COUNT(item_code) FROM fantasy.events WHERE amount IS NOT NULL AND amount>0)::NUMERIC AS relative_value, --общее количество внутриигровых продаж в относительном значении в разрезе каждого предмета
	cbu.count_id::NUMERIC/(SELECT COUNT(DISTINCT id) FROM fantasy.events)::NUMERIC  AS fraction_events --доля игроков, которые хотя бы раз покупали этот предмет
FROM fantasy.items AS i
JOIN count_items AS ci USING(item_code)
JOIN count_buy_users AS cbu USING(item_code)
ORDER BY ci.count_items_transaction DESC;
	
	
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- рассчитаем общее количество игроков в разрезе каждой расы
WITH race_count_users AS(
	SELECT 
		race_id,
		COUNT(DISTINCT id) AS c_race_users --общее количество игроков в разрезе каждой расы
	FROM fantasy.users
	GROUP BY race_id
),
race_count_buy_users AS (
	SELECT 
		race_id,
		c_race_users,
		COUNT(DISTINCT id) AS buy_race_users,--количество игроков совершивших покупку разрезе каждой расы
		ROUND(COUNT(DISTINCT id)::NUMERIC/c_race_users::NUMERIC,3) AS fraction_buy_users--доля игроков совершивших покупку от общего количества пользователей
	FROM fantasy.users
	LEFT JOIN fantasy.events USING(id)
	LEFT JOIN race_count_users USING(race_id)
	WHERE amount IS NOT NULL AND amount > 0
	GROUP BY race_id,c_race_users
),
race_count_pay_users AS (
	SELECT 
		race_id,
		buy_race_users,
		COUNT(DISTINCT id) AS pay_race_users,--количество платящих игроков совершивших покупку разрезе каждой расы
		ROUND(COUNT(DISTINCT id)::NUMERIC/buy_race_users::NUMERIC,3) AS fraction_pay_users--доля платящих игроков от количества игроков, которые совершили покупки
	FROM fantasy.users
	LEFT JOIN fantasy.events USING(id)
	LEFT JOIN race_count_buy_users USING(race_id)
	WHERE amount IS NOT NULL AND amount > 0 AND payer = 1
	GROUP BY race_id,buy_race_users
),
-- рассчитаем информацию об активности игроков с учётом расы персонажа:
stats_users AS (
	SELECT 	
		race_id,
		COUNT(transaction_id)::NUMERIC/COUNT(DISTINCT id) AS buy_per_users, -- среднее количество покупок на одного игрока
		AVG(amount) AS avg_amount_per_users, --средняя стоимость одной покупки на одного игрока
		(SUM(amount)::NUMERIC/COUNT(DISTINCT id)) AS sum_buy_per_users -- средняя стоимость покупок на одного игрока
	FROM fantasy.users 
	LEFT JOIN fantasy.events USING(id)
	WHERE amount IS NOT NULL AND amount > 0 
	GROUP BY race_id
)
SELECT 
	r.race,--раса персонажа
	rcu.c_race_users,----общее количество игроков в разрезе каждой расы
	rcbu.buy_race_users,--количество игроков совершивших покупку разрезе каждой расы
	rcbu.fraction_buy_users,--доля игроков совершивших покупку от общего количества пользователей
	rcpu.pay_race_users,--количество платящих игроков совершивших покупку разрезе каждой расы
	rcpu.fraction_pay_users,--доля платящих игроков от количества игроков, которые совершили покупки
	su.buy_per_users AS avg_perchase_per_users,--среднее количество покупок на одного игрока
	su.avg_amount_per_users,--средняя стоимость одной покупки на одного игрока
	su.sum_buy_per_users AS avg_sum_purchase_per_users--средняя суммарная стоимость всех покупок на одного игрока
FROM race_count_users rcu
JOIN fantasy.race r USING(race_id)
LEFT JOIN race_count_buy_users rcbu USING(race_id)
LEFT JOIN race_count_pay_users rcpu USING(race_id)
LEFT JOIN stats_users su USING(race_id)
ORDER BY rcu.c_race_users DESC;


-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь