-- ============================================================================
-- ClickHouse - UDF функции для парсинга GA4 JSON
-- ============================================================================
--
-- GA4 event_params - JSON массив:
-- [{"key":"ga_session_id","value":{"string_value":null,"int_value":123,...}}, ...]
--
-- Использование:
--   extractEventParamString(event_params, 'firebase_screen')  → String
--   extractEventParamInt(event_params, 'ga_session_id')       → Int64
--   extractEventParamFloat(event_params, 'engagement_time')   → Float64
-- ============================================================================

CREATE OR REPLACE FUNCTION extractEventParamString AS (params, key) -> 
    JSONExtractString(
        arrayFirst(x -> JSONExtractString(x, 'key') = key, JSONExtractArrayRaw(params)),
        'value', 'string_value'
    );

CREATE OR REPLACE FUNCTION extractEventParamInt AS (params, key) -> 
    JSONExtractInt(
        arrayFirst(x -> JSONExtractString(x, 'key') = key, JSONExtractArrayRaw(params)),
        'value', 'int_value'
    );

CREATE OR REPLACE FUNCTION extractEventParamFloat AS (params, key) -> 
    coalesce(
        JSONExtractFloat(
            arrayFirst(x -> JSONExtractString(x, 'key') = key, JSONExtractArrayRaw(params)),
            'value', 'float_value'
        ),
        JSONExtractFloat(
            arrayFirst(x -> JSONExtractString(x, 'key') = key, JSONExtractArrayRaw(params)),
            'value', 'double_value'
        )
    );

CREATE OR REPLACE FUNCTION extractUserPropertyString AS (props, key) -> 
    JSONExtractString(
        arrayFirst(x -> JSONExtractString(x, 'key') = key, JSONExtractArrayRaw(props)),
        'value', 'string_value'
    );

CREATE OR REPLACE FUNCTION extractUserPropertyInt AS (props, key) -> 
    JSONExtractInt(
        arrayFirst(x -> JSONExtractString(x, 'key') = key, JSONExtractArrayRaw(props)),
        'value', 'int_value'
    );
