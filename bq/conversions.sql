DECLARE start_date STRING DEFAULT '202402001';

DECLARE end_date STRING DEFAULT '20240204';

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

WITH once_per_event_conversions AS (
    SELECT
        DISTINCT event_name
    FROM
        `nlp-api-test-260216.analytics_conversions.ga4_conversions`
    WHERE
        property_id = '250400352'
        AND counting_method = 'ONCE_PER_EVENT'
),
once_per_session_conversions AS (
    SELECT
        DISTINCT event_name
    FROM
        `nlp-api-test-260216.analytics_conversions.ga4_conversions`
    WHERE
        property_id = '250400352'
        AND counting_method = 'ONCE_PER_SESSION'
),
session_info AS (
    SELECT
        user_pseudo_id,
        ga4EventParams('ga_session_id', event_params).value AS session_id,
        EXTRACT(
            DATE
            FROM
                TIMESTAMP_MICROS(event_timestamp) AT TIME ZONE "Europe/Copenhagen"
        ) AS day,
        COUNTIF(
            event_name IN (
                SELECT
                    event_name
                FROM
                    once_per_session_conversions
            )
        ) > 0 AS has_session_conversion
    FROM
        `nlp-api-test-260216.analytics_250400352.events_*`
    WHERE
        REGEXP_EXTRACT(_table_suffix, '[0-9]+') BETWEEN start_date
        AND end_date
    GROUP BY
        user_pseudo_id,
        session_id,
        day
)
SELECT
    day,
    COUNT(DISTINCT s.user_pseudo_id) AS users,
    COUNT(DISTINCT CONCAT(s.user_pseudo_id, session_id)) AS sessions,
    COUNTIF(event_name = 'page_view') AS page_views,
    COUNTIF(
        event_name IN (
            SELECT
                event_name
            FROM
                once_per_event_conversions
        )
    ) AS conversions,
    SUM(IF(has_session_conversion, 1, 0)) AS session_conversions,
    COUNT(*) AS total_events
FROM
    session_info as s
    JOIN `nlp-api-test-260216.analytics_250400352.events_*` as e ON CONCAT(s.user_pseudo_id, session_id) = CONCAT(
        e.user_pseudo_id,
        ga4EventParams('ga_session_id', event_params).value
    )
GROUP BY
    day
ORDER BY
    day ASC;