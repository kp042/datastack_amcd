#!/bin/bash
# ==============================================================================
# DataStack - Проверка ClickHouse
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

# Загружаем переменные — СНАЧАЛА source, ПОТОМ используем
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Присваиваем ПОСЛЕ source
CH_PORT="${CLICKHOUSE_HTTP_PORT:-8124}"
CH_PASS="${CLICKHOUSE_PASSWORD}"

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILED=$((FAILED + 1)); }
info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

ch_query() {
    # query передаём как чистый текст в POST body (без --data-urlencode)
    curl -sf "http://localhost:${CH_PORT}/?user=default&password=${CH_PASS}" \
        -d "$1" 2>/dev/null
}

echo ""
echo "============================================================"
echo "  DataStack - Проверка ClickHouse"
echo "============================================================"
echo ""

# --- Контейнер ---
echo "--- Контейнер ---"
if docker ps --format '{{.Names}}' | grep -q 'datastack2-clickhouse'; then
    pass "Контейнер запущен"
else
    fail "Контейнер НЕ запущен"
    echo "  Запустите: cd clickhouse && docker compose --env-file ../.env up -d"
    exit 1
fi

# --- HTTP ---
echo ""
echo "--- Подключение ---"
if curl -sf "http://localhost:${CH_PORT}/ping" > /dev/null; then
    pass "HTTP порт ${CH_PORT} доступен"
else
    fail "HTTP порт ${CH_PORT} НЕ доступен"
fi

# --- Аутентификация ---
RESULT=$(ch_query "SELECT 1")
if [ "$RESULT" = "1" ]; then
    pass "Аутентификация работает"
else
    fail "Аутентификация НЕ работает"
fi

# --- Базы данных ---
echo ""
echo "--- Базы данных ---"
for DB in raw staging marts quality; do
    if ch_query "SELECT 1 FROM system.databases WHERE name='${DB}'" | grep -q "1"; then
        pass "База '${DB}' существует"
    else
        fail "База '${DB}' НЕ найдена"
    fi
done

# --- UDF ---
echo ""
echo "--- UDF функции ---"
TEST_JSON='[{"key":"test","value":{"string_value":"hello","int_value":42,"float_value":null,"double_value":null}}]'

STR_RESULT=$(ch_query "SELECT extractEventParamString('${TEST_JSON}', 'test')")
if [ "$STR_RESULT" = "hello" ]; then
    pass "extractEventParamString работает"
else
    fail "extractEventParamString НЕ работает (got: $STR_RESULT)"
fi

INT_RESULT=$(ch_query "SELECT extractEventParamInt('${TEST_JSON}', 'test')")
if [ "$INT_RESULT" = "42" ]; then
    pass "extractEventParamInt работает"
else
    fail "extractEventParamInt НЕ работает (got: $INT_RESULT)"
fi

# # --- Изоляция от v1 ---
# echo ""
# echo "--- Изоляция от v1 ---"
# if docker ps --format '{{.Names}}' | grep -qE '^clickhouse$'; then
#     pass "DataStack v1 ClickHouse тоже работает — конфликтов нет"
# else
#     info "DataStack v1 ClickHouse не запущен (ОК)"
# fi

# --- Инфо ---
echo ""
echo "--- Информация ---"
VERSION=$(ch_query "SELECT version()")
info "Версия: ${VERSION}"

UPTIME=$(ch_query "SELECT formatReadableTimeDelta(uptime())")
info "Uptime: ${UPTIME}"

DISK=$(ch_query "SELECT concat(formatReadableSize(free_space), ' свободно из ', formatReadableSize(total_space)) FROM system.disks WHERE name='default'")
info "Диск: ${DISK}"

# --- Итог ---
echo ""
echo "============================================================"
echo -e "  Результат: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "============================================================"

if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}Есть проблемы!${NC}"
    exit 1
else
    echo -e "  ${GREEN}ClickHouse v2 готов!${NC}"
    echo "  Следующий шаг → Фаза 0.2: MinIO v2"
fi
