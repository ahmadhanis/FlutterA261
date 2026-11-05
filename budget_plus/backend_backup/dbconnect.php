<?php

// Connect to the SQLite database in this folder.
// SQLite creates budgetplusdb.sqlite automatically if it does not exist.
$databaseFile = __DIR__ . '/budgetplusdb.sqlite';
$database = new PDO('sqlite:' . $databaseFile);

// Make database problems throw an exception so the API can handle them.
$database->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Make sure both registration and login can use the users table.
$database->exec("CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)");
