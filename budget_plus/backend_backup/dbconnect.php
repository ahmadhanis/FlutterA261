<?php

// Connect to the SQLite database in this folder.
// SQLite creates budgetplusdb.sqlite automatically if it does not exist.
$databaseFile = __DIR__ . '/budgetplusdb.sqlite';
$database = new PDO('sqlite:' . $databaseFile);

// Make database problems throw an exception so the API can handle them.
$database->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$database->exec('PRAGMA foreign_keys = ON');

// Make sure both registration and login can use the users table.
$database->exec("CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)");

// Store each entry's details and the random name of its optional image.
$database->exec("CREATE TABLE IF NOT EXISTS budget_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    type TEXT NOT NULL,
    category TEXT NOT NULL,
    amount REAL NOT NULL,
    transaction_date TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    image_name TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)");

// Add the owner column to an existing database without deleting old entries.
$hasUserIdColumn = false;
foreach ($database->query('PRAGMA table_info(budget_entries)') as $column) {
    if ($column['name'] === 'user_id') {
        $hasUserIdColumn = true;
        break;
    }
}

if (!$hasUserIdColumn) {
    // Old entries keep a NULL owner until they can be assigned manually.
    $database->exec(
        'ALTER TABLE budget_entries ADD COLUMN user_id INTEGER REFERENCES users(id) ON DELETE CASCADE'
    );
}

$database->exec(
    'CREATE INDEX IF NOT EXISTS idx_budget_entries_user_date
     ON budget_entries (user_id, transaction_date DESC)'
);
