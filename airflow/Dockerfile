# ============================================================================
# DataStack v2 — Custom Apache Airflow 3.1.7 Image
# ============================================================================
#
# Что внутри:
#   1. Airflow 3.1.7 + Python 3.12 (официальный образ)
#   2. Провайдеры: Google, PostgreSQL, MySQL, Amazon(S3), HTTP, Celery, Redis
#   3. Драйверы: clickhouse-connect, pymysql, psycopg2, boto3
#   4. Данные: pandas, pyarrow
#   5. Уведомления: aiogram (Telegram Bot)
#   6. dbt: в отдельном virtualenv (изоляция от Airflow)
#
# Почему кастомный образ:
#   - Все зависимости запекаются при сборке
#   - Контейнеры стартуют мгновенно (без pip install при каждом запуске)
#   - Гарантия идентичного окружения для всех сервисов
#   - constraints файл обеспечивает совместимость пакетов
#
# ============================================================================

FROM apache/airflow:3.1.7-python3.12

# --- Версии для constraints ---
# Constraints = файл с проверенными версиями всех зависимостей Airflow.
# Без него pip может установить несовместимые версии.
ARG AIRFLOW_VERSION=3.1.7
ARG PYTHON_VERSION=3.12
ARG CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

# ── Системные зависимости ──
# Нужны для компиляции C-расширений Python-пакетов
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # Компиляторы C/C++ (для cython, некоторых драйверов)
        gcc g++ \
        # PostgreSQL client library (для psycopg2-binary)
        libpq-dev \
        # MySQL client library (для mysqlclient)
        default-libmysqlclient-dev \
        # Нужен для mysqlclient build
        pkg-config \
    && rm -rf /var/lib/apt/lists/*
# Возвращаемся к непривилегированному пользователю airflow
USER airflow

# ── Python-зависимости ──
# Устанавливаем ВСЕ провайдеры и драйверы одной командой.
# --constraint гарантирует совместимость с Airflow 3.1.7
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
    --constraint "${CONSTRAINT_URL}"

# ── dbt в отдельном virtualenv ──
# ПОЧЕМУ ОТДЕЛЬНЫЙ VENV:
#   dbt-core тянёт свои версии Jinja2, SQLAlchemy, agate и др.
#   Эти версии могут конфликтовать с Airflow.
#   Отдельный venv = полная изоляция. Нет конфликтов.
#
# КАК ВЫЗЫВАТЬ:
#   Из DAG через BashOperator:
#     /opt/airflow/dbt_venv/bin/dbt run --project-dir /opt/airflow/dbt ...
#
#   Или через ExternalPythonOperator:
#     python_path="/opt/airflow/dbt_venv/bin/python"
RUN python -m venv /opt/airflow/dbt_venv \
    && /opt/airflow/dbt_venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/airflow/dbt_venv/bin/pip install --no-cache-dir \
        dbt-core~=1.8.0 \
        dbt-clickhouse~=1.8.0
