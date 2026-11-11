-- Выполняется автоматически при ПЕРВОМ старте postgres (пустой том db_data).
CREATE TABLE IF NOT EXISTS items (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

INSERT INTO items (name) VALUES
    ('first item'),
    ('second item'),
    ('third item'),
    ('fourth item'),
    ('fifth item');
