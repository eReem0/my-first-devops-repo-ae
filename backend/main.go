// backend/main.go
// Минимальный Go-сервер: раздаёт статичный frontend и JSON API,
// который читает записи из PostgreSQL.
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
)

type Item struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

func main() {
	// Параметры БД берутся из окружения (их задаёт Compose из .env),
	// поэтому в коде нет ни одного секрета.
	dsn := "host=" + env("DB_HOST", "db") +
		" port=" + env("DB_PORT", "5432") +
		" user=" + env("DB_USER", "app") +
		" password=" + env("DB_PASSWORD", "secret") +
		" dbname=" + env("DB_NAME", "appdb") +
		" sslmode=disable"

	// sql.Open не подключается сразу — соединение открывается при первом запросе,
	// поэтому приложение не падает, если БД ещё поднимается.
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	staticDir := env("STATIC_DIR", "/app/static")
	fs := http.FileServer(http.Dir(staticDir))

	// /health — проверяет не только процесс, но и связь с БД (нужно для тестов в CI).
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		defer cancel()
		w.Header().Set("Content-Type", "application/json")
		if err := db.PingContext(ctx); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]string{"status": "error", "database": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "database": "connected"})
	})

	http.HandleFunc("/api/items", func(w http.ResponseWriter, r *http.Request) {
		rows, err := db.Query(`SELECT id, name FROM items ORDER BY id`)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		items := []Item{}
		for rows.Next() {
			var it Item
			if err := rows.Scan(&it.ID, &it.Name); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			items = append(items, it)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(items)
	})

	http.HandleFunc("/api/items/count", func(w http.ResponseWriter, r *http.Request) {
		var n int
		if err := db.QueryRow(`SELECT COUNT(*) FROM items`).Scan(&n); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]int{"count": n})
	})

	// FileServer сам отдаёт index.html для "/" (а на "/index.html" отвечает редиректом).
	http.Handle("/", fs)

	addr := ":" + env("HTTP_PORT", "8080")
	log.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
