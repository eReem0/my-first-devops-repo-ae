# Fullstack Go + PostgreSQL: Docker Compose + GitHub Actions (self-hosted runner)

Практические работы:
1. **Docker и Docker Compose** — multi-stage Dockerfile на Go, distroless non-root образ, стек app + db.
2. **GitHub Actions** — деплой этого стека на self-hosted runner (macOS), секреты → `.env`, тесты, артефакты.

## Структура

```
.
├── backend/                 # Go API + раздача статики
│   ├── main.go
│   ├── go.mod / go.sum
│   └── Dockerfile           # multi-stage: golang:1.22-alpine → distroless/static:nonroot
├── frontend/                # статичный фронт (index.html, app.js, style.css)
├── init/01_seed.sql         # создание таблицы items и тестовые данные
├── docker-compose.yml       # app + db, сеть app_net, у БД нет внешних портов
├── tests/run_tests.sh       # тесты приложения для CI
├── .github/workflows/deploy.yml
├── .env.example
└── .gitignore               # .env не коммитится
```

## Эндпоинты

| URL | Что отдаёт |
|---|---|
| `/` | веб-интерфейс со списком items |
| `/api/items` | JSON из таблицы `items` |
| `/api/items/count` | `{"count": N}` |
| `/health` | статус приложения и подключения к БД |

## Локальный запуск (практика 2)

```bash
cp .env.example .env
docker compose config -q          # проверка файла
docker compose up -d --build
docker compose ps
docker compose logs app
curl -s http://localhost:8080/api/items
docker image ls app-backend       # размер финального образа (~10 МБ)
docker compose down               # остановить (том с БД сохранится)
```

## GitHub Actions (практика 3)

### 1. Self-hosted runner на macOS

GitHub → репозиторий → **Settings → Actions → Runners → New self-hosted runner** → выбрать **macOS** и свою архитектуру (Apple Silicon = ARM64). Выполнить в терминале команды со страницы (`mkdir actions-runner`, `curl …`, `tar …`, `./config.sh --url … --token …`), затем:

```bash
./run.sh
```

Терминал держать открытым, Docker Desktop должен быть запущен. Runner должен быть **Idle / Online** в списке.

### 2. Секреты

**Settings → Secrets and variables → Actions → New repository secret**:

| Секрет | Значение |
|---|---|
| `DB_HOST` | `db` (имя сервиса в Compose, не localhost) |
| `DB_PORT` | `5432` |
| `DB_NAME` | `appdb` |
| `DB_USER` | `app` |
| `DB_PASSWORD` | любой пароль |
| `APP_PORT` | `8080` |

### 3. Запуск

Push в `main` или **Actions → Full Stack Deployment Test → Run workflow**.

Что делает workflow:
1. Проверяет runner и Docker, валидирует `docker-compose.yml`.
2. Создаёт `.env` из GitHub Secrets.
3. `docker compose up -d --build`, ждёт `/health`, проверяет, что оба контейнера running.
4. Тест 1: приложение отвечает, БД подключена, API и веб-интерфейс работают.
5. Тест 2: сравнивает записи в БД (через `psql`) с данными веб-интерфейса (`/api/items`) — количество и содержимое.
6. Сохраняет артефакты: замаскированный `.env`, логи контейнеров, `docker ps`, `docker images`, отчёт тестов.
7. Удаляет `.env` с настоящими значениями с машины runner'а.

### Соответствие критериям (10 баллов)

| Критерий | Где |
|---|---|
| Runner установлен, Online, `runs-on: self-hosted` | шаг 1 выше, `deploy.yml` |
| `docker compose up -d`, контейнеры running | шаги *Deploy*, *Verify containers* |
| Secrets → `.env`, артефакты | шаги *Create .env*, *Upload artifacts* |
| Тест приложения и БД, сравнение БД с веб-интерфейсом | `tests/run_tests.sh` |
