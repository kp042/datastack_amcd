-- ============================================================================
-- ClickHouse - Создание баз данных (dbt-style слои)
-- ============================================================================
--
--  raw       - Сырые данные "как есть" из источников
--  staging   - Очищенные данные (dbt staging models)  
--  marts     - Бизнес-модели (dbt mart models)
--  quality   - Data Quality метрики и тесты
-- ============================================================================

CREATE DATABASE IF NOT EXISTS raw;
CREATE DATABASE IF NOT EXISTS staging;
CREATE DATABASE IF NOT EXISTS marts;
CREATE DATABASE IF NOT EXISTS quality;
