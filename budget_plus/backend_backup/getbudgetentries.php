<?php

// This API returns budget entries for one user.
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

function sendJsonResponse($statusCode, $data)
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendJsonResponse(405, [
        'success' => false,
        'message' => 'Use GET to load budget entries.',
    ]);
}

// Read the owner ID from the query string, for example ?user_id=4.
$userId = filter_var($_GET['user_id'] ?? '', FILTER_VALIDATE_INT);
if ($userId === false || $userId < 1) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'A valid user ID is required.',
    ]);
}

try {
    // Connect to SQLite and make sure the tables exist.
    require_once __DIR__ . '/dbconnect.php';

    // Check that this user account exists.
    $userStatement = $database->prepare('SELECT id FROM users WHERE id = :user_id');
    $userStatement->execute([':user_id' => $userId]);
    if (!$userStatement->fetchColumn()) {
        sendJsonResponse(404, [
            'success' => false,
            'message' => 'The user account was not found.',
        ]);
    }

    // Return only entries owned by this user, newest transaction first.
    $entryStatement = $database->prepare(
        'SELECT id, user_id, title, type, category, amount,
                transaction_date, description, image_name
         FROM budget_entries
         WHERE user_id = :user_id
         ORDER BY transaction_date DESC, id DESC'
    );
    $entryStatement->execute([':user_id' => $userId]);
    $entries = $entryStatement->fetchAll(PDO::FETCH_ASSOC);

    foreach ($entries as &$entry) {
        $entry['id'] = (int) $entry['id'];
        $entry['user_id'] = (int) $entry['user_id'];
        $entry['amount'] = (float) $entry['amount'];
    }
    unset($entry);

    sendJsonResponse(200, [
        'success' => true,
        'entries' => $entries,
    ]);
} catch (PDOException $error) {
    error_log('Load budget entries error: ' . $error->getMessage());
    sendJsonResponse(500, [
        'success' => false,
        'message' => 'Budget entries are temporarily unavailable.',
    ]);
}
