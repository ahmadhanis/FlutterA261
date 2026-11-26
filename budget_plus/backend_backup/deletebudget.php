<?php

header('Content-Type: application/json; charset=utf-8');

function sendJsonResponse($statusCode, $data)
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(405, [
        'success' => false,
        'message' => 'Use POST to delete an entry.',
    ]);
}

$entryId = filter_var($_POST['entry_id'] ?? '', FILTER_VALIDATE_INT);
$userId = filter_var($_POST['user_id'] ?? '', FILTER_VALIDATE_INT);

if ($entryId === false || $entryId < 1 || $userId === false || $userId < 1) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'A valid entry ID and user ID are required.',
    ]);
}

try {
    require_once __DIR__ . '/dbconnect.php';

    // Only find and delete an entry owned by the supplied user.
    $findEntry = $database->prepare(
        'SELECT image_name FROM budget_entries
         WHERE id = :entry_id AND user_id = :user_id'
    );
    $findEntry->execute([
        ':entry_id' => $entryId,
        ':user_id' => $userId,
    ]);
    $entry = $findEntry->fetch(PDO::FETCH_ASSOC);

    if (!$entry) {
        sendJsonResponse(404, [
            'success' => false,
            'message' => 'The entry was not found for this user.',
        ]);
    }

    $deleteEntry = $database->prepare(
        'DELETE FROM budget_entries WHERE id = :entry_id AND user_id = :user_id'
    );
    $deleteEntry->execute([
        ':entry_id' => $entryId,
        ':user_id' => $userId,
    ]);

    // Remove the associated upload after deleting its database record.
    if (!empty($entry['image_name'])) {
        $imagePath = __DIR__ . '/uploads/' . basename($entry['image_name']);
        if (is_file($imagePath)) {
            @unlink($imagePath);
        }
    }

    sendJsonResponse(200, [
        'success' => true,
        'message' => 'Entry deleted successfully.',
    ]);
} catch (Throwable $error) {
    error_log('Delete budget entry error: ' . $error->getMessage());
    sendJsonResponse(500, [
        'success' => false,
        'message' => 'The entry could not be deleted.',
    ]);
}
