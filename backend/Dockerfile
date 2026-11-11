# ---------- Этап 1: сборка ----------
# Полный образ с компилятором Go нужен только чтобы собрать бинарник;
# в финальный образ он не попадёт.
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Сначала ТОЛЬКО файлы зависимостей: этот слой кэшируется,
# и при правке main.go модули не скачиваются заново.
COPY go.mod go.sum ./
RUN go mod download

# Теперь исходники. CGO_ENABLED=0 даёт статический бинарник,
# который работает в distroless/static без glibc.
# -ldflags="-s -w" убирает debug-информацию — образ меньше.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/app ./main.go

# ---------- Этап 2: исполнение ----------
# distroless/static: нет shell, нет пакетного менеджера — минимальная
# поверхность атаки. Тег :nonroot запускает процесс под пользователем nonroot.
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app
COPY --from=builder /out/app /app/app

# EXPOSE только документирует порт; пробрасывает его Compose.
EXPOSE 8080

# Явно фиксируем non-root (uid 65532 = nonroot в distroless).
USER nonroot:nonroot

# ENTRYPOINT — что запускать; аргументы при желании можно передать через CMD.
ENTRYPOINT ["/app/app"]
