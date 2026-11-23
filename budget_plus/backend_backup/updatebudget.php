<?php

// Update a budget entry owned by the supplied user ID.
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(405, [
        'success' => false,
        'message' => 'Use POST to update an entry.',
    ]);
}

// Read the fields from the multipart form sent by Flutter.
$entryId = filter_var($_POST['entry_id'] ?? '', FILTER_VALIDATE_INT);
$userId = filter_var($_POST['user_id'] ?? '', FILTER_VALIDATE_INT);
$title = $_POST['title'] ?? '';
$type = $_POST['type'] ?? '';
$category = $_POST['category'] ?? '';
$amount = $_POST['amount'] ?? '';
$transactionDate = $_POST['transaction_date'] ?? '';
$description = $_POST['description'] ?? '';
$removeImage = ($_POST['remove_image'] ?? '0') === '1';

if ($entryId === false || $entryId < 1 || $userId === false || $userId < 1) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'A valid entry ID and user ID are required.',
    ]);
}

if (!is_string($title) || !is_string($type) || !is_string($category)
    || !is_string($amount) || !is_string($transactionDate)
    || !is_string($description)) {
    sendJsonResponse(400, [
        'success' => false,
        'message' => 'Entry fields must be text.',
    ]);
}

$title = trim($title);
$type = trim($type);
$category = trim($category);
$description = trim($description);

if ($title === '' || mb_strlen($title) > 80) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Enter a title up to 80 characters long.',
    ]);
}

if (!in_array($type, ['Expense', 'Income', 'Transfer'], true)) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Choose a valid entry type.',
    ]);
}

if (!in_array($category, ['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Other'], true)) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Choose a valid category.',
    ]);
}

if (!is_numeric($amount) || (float) $amount <= 0) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Enter an amount greater than zero.',
    ]);
}

if (strlen($description) > 240) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Description must be 240 characters or less.',
    ]);
}

$date = DateTime::createFromFormat('Y-m-d H:i:s', $transactionDate);
if (!$date || $date->format('Y-m-d H:i:s') !== $transactionDate) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Choose a valid date and time.',
    ]);
}

$savedImagePath = null;

try {
    // Connect to SQLite and verify that this user owns the entry.
    require_once __DIR__ . '/dbconnect.php';
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

    $oldImageName = $entry['image_name'];
    $imageName = $removeImage ? null : $oldImageName;

    // If a new image was selected, save it with a new random name.
    if (isset($_FILES['image']) && $_FILES['image']['error'] !== UPLOAD_ERR_NO_FILE) {
        if ($_FILES['image']['error'] !== UPLOAD_ERR_OK) {
            sendJsonResponse(400, [
                'success' => false,
                'message' => 'The image could not be uploaded.',
            ]);
        }

        if ($_FILES['image']['size'] > 5 * 1024 * 1024) {
            sendJsonResponse(413, [
                'success' => false,
                'message' => 'Image must be 5 MB or smaller.',
            ]);
        }

        $fileInfo = new finfo(FILEINFO_MIME_TYPE);
        $imageType = $fileInfo->file($_FILES['image']['tmp_name']);
        $allowedImages = [
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
        ];

        if (!isset($allowedImages[$imageType])) {
            sendJsonResponse(415, [
                'success' => false,
                'message' => 'Choose a JPG, PNG, or WEBP image.',
            ]);
        }

        $uploadDirectory = __DIR__ . '/uploads';
        if (!is_dir($uploadDirectory) && !mkdir($uploadDirectory, 0755, true)) {
            throw new RuntimeException('Could not create the uploads folder.');
        }

        $imageName = bin2hex(random_bytes(16)) . '.' . $allowedImages[$imageType];
        $savedImagePath = $uploadDirectory . '/' . $imageName;
        if (!move_uploaded_file($_FILES['image']['tmp_name'], $savedImagePath)) {
            throw new RuntimeException('Could not save the uploaded image.');
        }
    }

    // Update only the row belonging to this user.
    $update = $database->prepare(
        'UPDATE budget_entries
         SET title = :title, type = :type, category = :category,
             amount = :amount, transaction_date = :transaction_date,
             description = :description, image_name = :image_name
         WHERE id = :entry_id AND user_id = :user_id'
    );
    $update->execute([
        ':title' => $title,
        ':type' => $type,
        ':category' => $category,
        ':amount' => (float) $amount,
        ':transaction_date' => $date->format('Y-m-d H:i:s'),
        ':description' => $description,
        ':image_name' => $imageName,
        ':entry_id' => $entryId,
        ':user_id' => $userId,
    ]);

    // Delete the old image after the database points to the new image.
    if ($oldImageName !== null && $oldImageName !== $imageName) {
        $oldImagePath = __DIR__ . '/uploads/' . basename($oldImageName);
        if (is_file($oldImagePath)) {
            @unlink($oldImagePath);
        }
    }

    sendJsonResponse(200, [
        'success' => true,
        'message' => 'Entry updated successfully.',
    ]);
} catch (Throwable $error) {
    // Remove a replacement image if the database update failed.
    if ($savedImagePath !== null && is_file($savedImagePath)) {
        unlink($savedImagePath);
    }

    error_log('Update budget entry error: ' . $error->getMessage());
    sendJsonResponse(500, [
        'success' => false,
        'message' => 'The entry could not be updated.',
    ]);
}
