CREATE TEMP FUNCTION ga4EventParams(
    parameter_key_to_be_queried STRING,
    event_params ARRAY < STRUCT < KEY STRING,
    value STRUCT < string_value STRING,
    int_value INT64,
    float_value FLOAT64,
    double_value FLOAT64 > > >
) AS (
    (
        SELECT
            AS STRUCT COALESCE(
                value.string_value,
                CAST(value.int_value AS STRING),
                CAST(value.float_value AS STRING),
                CAST(value.double_value AS STRING)
            ) AS value,
            CASE
                WHEN value.string_value IS NOT NULL THEN "STRING"
                WHEN value.int_value IS NOT NULL THEN "INT64"
                WHEN value.float_value IS NOT NULL THEN "FLOAT64"
                WHEN value.double_value IS NOT NULL THEN "FLOAT64"
                ELSE NULL
            END AS value_type
        FROM
            UNNEST(event_params)
        WHERE
            KEY = parameter_key_to_be_queried
    )
);

WITH conversions as (
    SELECT
        DISTINCT event_name
    FROM
        `nlp-api-test-260216.analytics_conversions.ga4_conversions`
)
SELECT
    EXTRACT(
        DATE
        FROM
            TIMESTAMP_MICROS(event_timestamp) AT TIME ZONE "Europe/Copenhagen"
    ) as day,
    COUNT(DISTINCT user_pseudo_id) users,
    COUNT(
        DISTINCT CONCAT(
            user_pseudo_id,
            ga4EventParams('ga_session_id', event_params).value
        )
    ) sessions,
    COUNTIF(event_name = 'page_view') as page_views,
    COUNTIF(
        event_name in (
            SELECT
                event_name
            FROM
                conversions
        )
    ) as conversions,
    COUNT(*) as total_events
FROM
    `nlp-api-test-260216.analytics_250400352.events_*`
WHERE
    REGEXP_EXTRACT(_table_suffix, '[0-9]+') BETWEEN '20240104'
    AND '20240204'
    AND ga4EventParams('page_location', event_params).value NOT LIKE '%gtm_debug%'
GROUP BY
    1
ORDER BY
    1 ASC;