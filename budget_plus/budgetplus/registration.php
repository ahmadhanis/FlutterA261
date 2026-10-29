<?php

// Send JSON responses so Flutter can read the result.
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// This helper returns a response and stops the script.
function sendJsonResponse($statusCode, $data)
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

// Browsers send OPTIONS before a cross-origin POST request.
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Registration only accepts POST requests.
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(405, [
        'success' => false,
        'message' => 'Use POST to register.',
    ]);
}

// Read the form fields sent by Flutter. PHP puts form fields in $_POST.
$name = $_POST['name'] ?? '';
$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';

if (!is_string($name) || !is_string($email) || !is_string($password)) {
    sendJsonResponse(400, [
        'success' => false,
        'message' => 'Name, email, and password must be text.',
    ]);
}

$name = trim($name);
$email = strtolower(trim($email));

// Check the fields before saving them.
if ($name === '' || mb_strlen($name) > 120) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Enter a name up to 120 characters long.',
    ]);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 254) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Enter a valid email address.',
    ]);
}

if (strlen($password) < 8 || strlen($password) > 4096) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Password must be at least 8 characters.',
    ]);
}

try {
    // Connect to the SQLite database in this folder.
    // SQLite creates the file automatically if it does not exist.
    $databaseFile = __DIR__ . '/budgetplusdb.sqlite';
    $database = new PDO('sqlite:' . $databaseFile);
    $database->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Create the users table the first time this API is used.
    $createTableSql = "CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )";
    $database->exec($createTableSql);

    // Never save a plain-text password. Store a secure password hash instead.
    $passwordHash = password_hash($password, PASSWORD_DEFAULT);

    // Prepared statements keep user input separate from the SQL command.
    $insertSql = 'INSERT INTO users (name, email, password_hash)
                  VALUES (:name, :email, :password_hash)';
    $statement = $database->prepare($insertSql);
    $statement->execute([
        ':name' => $name,
        ':email' => $email,
        ':password_hash' => $passwordHash,
    ]);

    // Return only public account details, never the password hash.
    sendJsonResponse(201, [
        'success' => true,
        'message' => 'Account created successfully.',
        'user' => [
            'id' => (int) $database->lastInsertId(),
            'name' => $name,
            'email' => $email,
        ],
    ]);
} catch (PDOException $error) {
    // SQLite error code 23000 means a UNIQUE field (the email) already exists.
    if ($error->getCode() === '23000') {
        sendJsonResponse(409, [
            'success' => false,
            'message' => 'An account with this email already exists.',
        ]);
    }

    // Keep technical database details in the PHP error log, not the app response.
    error_log('Registration database error: ' . $error->getMessage());
    sendJsonResponse(500, [
        'success' => false,
        'message' => 'Registration is temporarily unavailable.',
    ]);
}
