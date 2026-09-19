package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq"
)

var db *sql.DB

const shortCodeChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

func generateShortCode(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	for i := range b {
		b[i] = shortCodeChars[int(b[i])%len(shortCodeChars)]
	}
	return string(b), nil
}

type shortenRequest struct {
	URL string `json:"url"`
}

type shortenResponse struct {
	ShortCode string `json:"short_code"`
	ShortURL  string `json:"short_url"`
}

func shortenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req shortenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.URL == "" {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	code, err := generateShortCode(6)
	if err != nil {
		http.Error(w, "failed to generate code", http.StatusInternalServerError)
		return
	}

	_, err = db.Exec(
		`INSERT INTO urls (short_code, original_url, click_count) VALUES ($1, $2, 0)`,
		code, req.URL,
	)
	if err != nil {
		log.Printf("db insert error: %v", err)
		http.Error(w, "failed to save url", http.StatusInternalServerError)
		return
	}

	resp := shortenResponse{
		ShortCode: code,
		ShortURL:  fmt.Sprintf("/r/%s", code),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func redirectHandler(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Path[len("/r/"):]
	if code == "" {
		http.NotFound(w, r)
		return
	}

	var originalURL string
	err := db.QueryRow(`SELECT original_url FROM urls WHERE short_code = $1`, code).Scan(&originalURL)
	if err == sql.ErrNoRows {
		http.NotFound(w, r)
		return
	} else if err != nil {
		log.Printf("db select error: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	_, err = db.Exec(`UPDATE urls SET click_count = click_count + 1 WHERE short_code = $1`, code)
	if err != nil {
		log.Printf("db update error: %v", err)
	}

	http.Redirect(w, r, originalURL, http.StatusFound)
}

type statsResponse struct {
	ShortCode   string `json:"short_code"`
	OriginalURL string `json:"original_url"`
	ClickCount  int    `json:"click_count"`
}

func statsHandler(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Path[len("/api/stats/"):]
	if code == "" {
		http.NotFound(w, r)
		return
	}

	var resp statsResponse
	resp.ShortCode = code
	err := db.QueryRow(
		`SELECT original_url, click_count FROM urls WHERE short_code = $1`, code,
	).Scan(&resp.OriginalURL, &resp.ClickCount)
	if err == sql.ErrNoRows {
		http.NotFound(w, r)
		return
	} else if err != nil {
		log.Printf("db select error: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func mustInitDB() *sql.DB {
	host := getenv("DB_HOST", "localhost")
	port := getenv("DB_PORT", "5432")
	user := getenv("DB_USER", "postgres")
	password := getenv("DB_PASSWORD", "changeme")
	dbname := getenv("DB_NAME", "shortener")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	conn, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("failed to open db: %v", err)
	}
	if err := conn.Ping(); err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}

	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS urls (
			id SERIAL PRIMARY KEY,
			short_code VARCHAR(16) UNIQUE NOT NULL,
			original_url TEXT NOT NULL,
			click_count INTEGER NOT NULL DEFAULT 0,
			created_at TIMESTAMP NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		log.Fatalf("failed to create table: %v", err)
	}
	return conn
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	db = mustInitDB()
	defer db.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/api/shorten", shortenHandler)
	mux.HandleFunc("/r/", redirectHandler)
	mux.HandleFunc("/api/stats/", statsHandler)
	mux.HandleFunc("/healthz", healthHandler)

	port := getenv("PORT", "8080")
	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
