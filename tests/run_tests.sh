#!/usr/bin/env bash
# Тесты приложения:
#   1) приложение работает и подключено к БД;
#   2) данные в БД совпадают с тем, что показывает веб-интерфейс.
# Нужны переменные окружения: APP_PORT, DB_USER, DB_NAME
set -euo pipefail

BASE_URL="http://localhost:${APP_PORT:-8080}"
OUT_DIR="test-results"
mkdir -p "$OUT_DIR"
REPORT="$OUT_DIR/test-report.md"

pass() { echo "✅ $1"; echo "- ✅ $1" >> "$REPORT"; }
fail() { echo "❌ $1"; echo "- ❌ $1" >> "$REPORT"; exit 1; }

psql_q() {
  docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -tA -c "$1"
}

{
  echo "# Отчёт о тестировании"
  echo
  echo "- Дата: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- Коммит: ${GITHUB_SHA:-local}"
  echo "- Runner: ${RUNNER_NAME:-local} (${RUNNER_OS:-$(uname)})"
  echo
  echo "## Тест 1. Приложение и подключение к БД"
} > "$REPORT"

# 1.1 /health: сервер отвечает и сам делает Ping в PostgreSQL
HEALTH=$(curl -fsS "$BASE_URL/health") || fail "/health недоступен"
echo "$HEALTH" > "$OUT_DIR/health.json"
echo "$HEALTH" | grep -q '"database":"connected"' \
  && pass "Приложение работает, БД подключена: $HEALTH" \
  || fail "Приложение не может подключиться к БД: $HEALTH"

# 1.2 /api/items отдаёт JSON из БД
curl -fsS "$BASE_URL/api/items" > "$OUT_DIR/api-items.json" || fail "/api/items вернул ошибку"
grep -q '"name"' "$OUT_DIR/api-items.json" \
  && pass "/api/items возвращает JSON с данными из БД" \
  || fail "/api/items вернул пустой или неверный ответ"

# 1.3 Веб-интерфейс отдаётся и подключает скрипт, который читает /api/items
curl -fsS "$BASE_URL/" > "$OUT_DIR/index.html" || fail "Главная страница недоступна"
curl -fsS "$BASE_URL/app.js" > "$OUT_DIR/app.js" || fail "app.js недоступен"
grep -q 'id="items"' "$OUT_DIR/index.html" && grep -q "/api/items" "$OUT_DIR/app.js" \
  && pass "Веб-интерфейс доступен и берёт данные из /api/items" \
  || fail "Веб-интерфейс не содержит списка или не обращается к API"

{
  echo
  echo "## Тест 2. Данные в БД = данные в веб-интерфейсе"
} >> "$REPORT"

# 2.1 Количество записей
DB_COUNT=$(psql_q "SELECT COUNT(*) FROM items;" | tr -d '[:space:]')
WEB_COUNT=$(grep -o '"name"' "$OUT_DIR/api-items.json" | wc -l | tr -d '[:space:]')
API_COUNT=$(curl -fsS "$BASE_URL/api/items/count" | sed 's/[^0-9]//g')

echo "Записей в БД: $DB_COUNT | в веб-интерфейсе: $WEB_COUNT | /api/items/count: $API_COUNT"
{
  echo "- Записей в БД: $DB_COUNT"
  echo "- Записей в веб-интерфейсе: $WEB_COUNT"
  echo "- /api/items/count: $API_COUNT"
} >> "$REPORT"

[ "$DB_COUNT" = "$WEB_COUNT" ] && [ "$DB_COUNT" = "$API_COUNT" ] \
  && pass "Количество записей совпадает" \
  || fail "Количество записей не совпадает"

# 2.2 Содержимое: id и названия построчно
psql_q "SELECT id || '|' || name FROM items ORDER BY id;" > "$OUT_DIR/db-items.txt"
grep -o '"id":[0-9]*,"name":"[^"]*"' "$OUT_DIR/api-items.json" \
  | sed 's/"id":\([0-9]*\),"name":"\(.*\)"/\1|\2/' > "$OUT_DIR/web-items.txt"

if diff -u "$OUT_DIR/db-items.txt" "$OUT_DIR/web-items.txt" > "$OUT_DIR/items.diff"; then
  pass "Записи (id и name) в БД и в веб-интерфейсе совпадают"
else
  cat "$OUT_DIR/items.diff"
  fail "Записи в БД и в веб-интерфейсе различаются (см. items.diff)"
fi

{
  echo
  echo "**Итог: все тесты пройдены ✅**"
} >> "$REPORT"
echo "🎉 Все тесты пройдены"
