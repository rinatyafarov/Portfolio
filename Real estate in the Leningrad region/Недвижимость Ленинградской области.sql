/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Яфаров Ринат
 * Дата: 29.10.2024
*/


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),
filtered_values AS 
	(SELECT 
		CASE 
			WHEN f.city_id = '6X8I' THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл'
		END AS city_category,--распределяем объявления по категории города
		CASE 
			WHEN days_exposition::NUMERIC  >= 1 AND days_exposition::NUMERIC <= 30 THEN 'До месяца'
			WHEN days_exposition::NUMERIC  >= 31 AND days_exposition::NUMERIC <= 90 THEN 'Квартал'
			WHEN days_exposition::NUMERIC  >= 91 AND days_exposition::NUMERIC <= 180 THEN 'Полгода'
			ELSE 'Больше полугода'
		END AS period_category,--распределяем объявления по категории длительности продажи
		*
	FROM real_estate.flats f
	JOIN real_estate.advertisement a USING(id)
	JOIN real_estate.TYPE t USING(type_id)
	WHERE id IN (SELECT id FROM filtered_id) AND t.type = 'город'),
dop AS (SELECT
	city_category,
	period_category,
	COUNT(id)  AS count_advert,--общее кол-во объявлений
	ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_cost_per_metr,--средняя стоимость метра 
	ROUND(AVG(total_area)::NUMERIC,2) AS avg_area,--средняя площадь квартиры
	ROUND(AVG(rooms)::NUMERIC,2) AS avg_rooms,--среднее кол-во комнат
	ROUND(percentile_disc(0.5) WITHIN GROUP (ORDER BY rooms)::NUMERIC,2) AS median_rooms,-- медиана кол-во комнат
	ROUND(AVG(balcony)::NUMERIC,2) AS avg_balcony,-- среднее кол-во балконов
	ROUND(percentile_disc(0.5) WITHIN GROUP (ORDER BY balcony)::NUMERIC,2) AS median_balcony,-- медиана кол-во балконов
	ROUND(AVG(floors_total)::NUMERIC,2) AS avg_floors_total,-- средняя высота потолка
	ROUND(percentile_disc(0.5) WITHIN GROUP (ORDER BY floors_total)::NUMERIC,2) AS median_floors_total--медиана высоты потолка
FROM filtered_values
GROUP BY city_category,period_category
ORDER BY city_category,period_category)
SELECT  
	city_category,
	period_category,
	count_advert,
	ROUND(count_advert::NUMERIC/(SUM(count_advert) OVER(PARTITION BY city_category))::NUMERIC,4) * 100 AS PERCENT,--процент объявлений в разрере СПБ И области
	avg_cost_per_metr,
	avg_area,
	avg_rooms,
	median_rooms,
	avg_balcony,
	median_balcony,
	avg_floors_total,
	median_floors_total
FROM dop
GROUP BY city_category,period_category,count_advert,avg_cost_per_metr,avg_area,avg_rooms,median_rooms,avg_balcony,median_balcony,avg_floors_total,median_floors_total
-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),
--Проведем основные вычисленния для месяца публикации
PUBLICATION AS (
	SELECT 
	EXTRACT(MONTH FROM a.first_day_exposition) AS MONTH,--вычленям месяц публикации
	COUNT(DISTINCT a.id) AS count_publications,--кол-во объявлений в каждом месяце публикации
	ROUND(COUNT(DISTINCT a.id)::NUMERIC/(
	SELECT count(*) 
	FROM real_estate.advertisement 
	JOIN real_estate.flats f USING(id)
	JOIN real_estate.TYPE t USING(type_id)
	WHERE f.id IN (SELECT id FROM filtered_id) AND (first_day_exposition BETWEEN '01-01-2015' AND '01-01-2019') AND t.type = 'город' )::NUMERIC,2) AS fraction_publish,
	ROUND(AVG(a.last_price/f.total_area)::NUMERIC,2) AS avg_price_metr_public,--средняя стоимость квадратного метра
	ROUND(AVG(f.total_area)::NUMERIC,2) AS avg_area_public,--средняя площадь квартиры
	DENSE_RANK() OVER(ORDER BY COUNT(a.id) desc) AS publication_rank--проводим ранжирования по количеству объявлений
	FROM real_estate.advertisement a
	JOIN real_estate.flats f USING(id)
	JOIN real_estate.TYPE t USING(type_id)
	WHERE f.id IN (SELECT id FROM filtered_id) AND (first_day_exposition BETWEEN '01-01-2015' AND '01-01-2019') AND t.type = 'город'
	GROUP BY month
),
--Проведем основные вычисления для месяца снятия с продажи
removal AS (
	SELECT 
		EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition * INTERVAL '1 day') AS MONTH,--вычленгяем месяц снятия с продажи
		ROUND(COUNT(DISTINCT a.id)::NUMERIC/(
	SELECT count(*) 
	FROM real_estate.advertisement 
	JOIN real_estate.flats f USING(id)
	JOIN real_estate.TYPE t USING(type_id)
	WHERE f.id IN (SELECT id FROM filtered_id) AND (first_day_exposition BETWEEN '01-01-2015' AND '01-01-2019') AND t.type = 'город' )::NUMERIC,2) AS fraction_removal,
		COUNT(DISTINCT a.id) AS count_removal,--кол-во объявлений
		ROUND(AVG(a.last_price/f.total_area)::NUMERIC,2) AS avg_price_metr_removal,--средняя стоимость кевадратного метра
		ROUND(AVG(f.total_area)::NUMERIC,2) AS avg_area_removal,--средняя площадь квартиры
		DENSE_RANK() OVER(ORDER BY COUNT(a.id) desc) AS removal_rank-- проводим ранжирования по количеству объявлений
	FROM real_estate.advertisement a
	JOIN real_estate.flats f USING(id)
	JOIN real_estate.TYPE t USING(type_id)
	WHERE f.id IN (SELECT id FROM filtered_id ) AND (first_day_exposition BETWEEN '01-01-2015' AND '01-01-2019') AND  t.type = 'город'
	GROUP BY month
)
SELECT 
	MONTH,
	count_publications,
	fraction_publish,
	count_removal,
	fraction_removal,
	avg_price_metr_public,
	avg_price_metr_removal,
	avg_area_public,
	avg_area_removal,
	publication_rank,
	removal_rank
FROM publication 
JOIN removal USING(month)
ORDER BY month 


-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),
 main AS (
	SELECT 
		city,--делаем выборку городов
		COUNT(id) AS num_ads,--считаем кол-во объявлений
		COUNT(days_exposition)::numeric/count(*)::NUMERIC AS fraction_ads,--рассчитываем долю объявлений
		ROUND(AVG(a.last_price/f.total_area)::NUMERIC,2) AS avg_price_metr,--среднеяя стоимость квадратного метра
		ROUND(AVG(f.total_area)::NUMERIC,2) AS avg_area,--средняя площадь
		ROUND(AVG( a.days_exposition )::NUMERIC,2) AS time_of_publish,--среднее время публикации(днях)
		NTILE(4) OVER(ORDER BY COUNT(a.id) desc) AS RANK_COUNT_ADV,--ранк города по кол-ву объявлений
		NTILE(4) OVER(ORDER BY ROUND(AVG( a.days_exposition )::NUMERIC,2) desc) AS RANK_TIME_OfF_PUBLISH--ранк города по среднему времени публикации
	FROM real_estate.flats f
	JOIN real_estate.city c USING(city_id)
	JOIN real_estate.advertisement a USING(id)
	WHERE id IN (SELECT id FROM filtered_id) AND city <> 'Санкт-Петербург' 
	GROUP BY city
	HAVING COUNT(id)> 50
	ORDER BY num_ads desc)
	SELECT *
	FROM main
	--Спасибо большое за ревью, я переделал все пункты(надеюсь правильно), все улучшения внесу на след. неделе, сейчас катастрофически не хватает времени! :)