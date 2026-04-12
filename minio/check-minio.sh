#!/bin/bash
# ==============================================================================
# DataStack AMCD — Проверка MinIO
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

MINIO_UI="${MINIO_UI_PORT:-9003}"
MINIO_API="${MINIO_API_PORT:-9004}"

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILED=$((FAILED + 1)); }
info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

echo ""
echo "============================================================"
echo "  DataStack AMCD — Проверка MinIO"
echo "============================================================"
echo ""

# --- Контейнер ---
echo "--- Контейнер ---"
if docker ps --format '{{.Names}}' | grep -q 'datastack2-minio'; then
    pass "Контейнер запущен"
else
    fail "Контейнер НЕ запущен"
    exit 1
fi

# --- Порты ---
echo ""
echo "--- Порты ---"
if curl -sf "http://localhost:${MINIO_API}/minio/health/live" > /dev/null; then
    pass "API порт ${MINIO_API} доступен"
else
    fail "API порт ${MINIO_API} НЕ доступен"
fi

if curl -sf -o /dev/null -w "%{http_code}" "http://localhost:${MINIO_UI}/" | grep -qE "200|307"; then
    pass "UI порт ${MINIO_UI} доступен"
else
    # MinIO UI может вернуть 403 — это тоже ОК (значит слушает)
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${MINIO_UI}/" | grep -qE "403|200|307"; then
        pass "UI порт ${MINIO_UI} доступен"
    else
        fail "UI порт ${MINIO_UI} НЕ доступен"
    fi
fi

# --- Создаём bucket raw-data ---
echo ""
echo "--- Bucket ---"

# Используем mc (MinIO Client) внутри контейнера
docker exec datastack2-minio mc alias set local http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" > /dev/null 2>&1

BUCKET="${MINIO_BUCKET_RAW:-raw-data}"
docker exec datastack2-minio mc mb "local/${BUCKET}" --ignore-existing > /dev/null 2>&1

if docker exec datastack2-minio mc ls local/ 2>/dev/null | grep -q "${BUCKET}"; then
    pass "Bucket '${BUCKET}' существует"
else
    fail "Bucket '${BUCKET}' НЕ создан"
fi

# --- Изоляция от v1 ---
echo ""
echo "--- Изоляция от v1 ---"
if docker ps --format '{{.Names}}' | grep -qE '^minio$'; then
    pass "DataStack v1 MinIO тоже работает — конфликтов нет"
else
    info "DataStack v1 MinIO не запущен (ОК)"
fi

# --- Инфо ---
echo ""
echo "--- Информация ---"
info "UI: http://1.2.3.4:${MINIO_UI}"
info "API: http://1.2.3.4:${MINIO_API}"
info "User: ${MINIO_ROOT_USER}"

# --- Итог ---
echo ""
echo "============================================================"
echo -e "  Результат: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "============================================================"

if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}Есть проблемы!${NC}"
    exit 1
else
    echo -e "  ${GREEN}MinIO готов!${NC}"
    echo "  Следующий шаг → Фаза 0.3: Airflow"
fi
