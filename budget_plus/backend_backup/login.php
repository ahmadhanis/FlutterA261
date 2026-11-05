<?php

// Send JSON responses so Flutter can read the result.
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Return a JSON response and stop running this file.
function sendJsonResponse($statusCode, $data)
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

// Handle the browser's preflight request.
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Login only accepts POST requests.
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(405, [
        'success' => false,
        'message' => 'Use POST to log in.',
    ]);
}

// Read the email and password from the form data.
$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';

if (!is_string($email) || !is_string($password)) {
    sendJsonResponse(400, [
        'success' => false,
        'message' => 'Email and password must be text.',
    ]);
}

$email = strtolower(trim($email));

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Enter a valid email address.',
    ]);
}

if ($password === '') {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Enter your password.',
    ]);
}

try {
    // Connect to SQLite. dbconnect.php also makes sure the users table exists.
    require_once __DIR__ . '/dbconnect.php';

    // Find the account by email using a prepared statement.
    $statement = $database->prepare(
        'SELECT id, name, email, password_hash FROM users WHERE email = :email'
    );
    $statement->execute([':email' => $email]);
    $user = $statement->fetch(PDO::FETCH_ASSOC);

    // Check the submitted password against the saved password hash.
    if (!$user || !password_verify($password, $user['password_hash'])) {
        sendJsonResponse(401, [
            'success' => false,
            'message' => 'Email or password is incorrect.',
        ]);
    }

    // Return account details without sending the password hash.
    sendJsonResponse(200, [
        'success' => true,
        'message' => 'Login successful.',
        'user' => [
            'id' => (int) $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
        ],
    ]);
} catch (PDOException $error) {
    // Keep database details in the PHP log instead of showing them in the app.
    error_log('Login database error: ' . $error->getMessage());
    sendJsonResponse(500, [
        'success' => false,
        'message' => 'Login is temporarily unavailable.',
    ]);
}
