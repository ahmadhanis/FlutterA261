<?php

// This API receives form fields and an optional image from Flutter.
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
        'message' => 'Use POST to add an entry.',
    ]);
}

// Read the text fields sent with the image upload.
$title = $_POST['title'] ?? '';
$type = $_POST['type'] ?? '';
$category = $_POST['category'] ?? '';
$amount = $_POST['amount'] ?? '';
$transactionDate = $_POST['transaction_date'] ?? '';
$description = $_POST['description'] ?? '';
$userId = $_POST['user_id'] ?? '';

if (!is_string($title) || !is_string($type) || !is_string($category)
    || !is_string($amount) || !is_string($transactionDate)
    || !is_string($description) || !is_string($userId)) {
    sendJsonResponse(400, [
        'success' => false,
        'message' => 'Entry fields must be text.',
    ]);
}

$title = trim($title);
$type = trim($type);
$category = trim($category);
$description = trim($description);
$userId = filter_var($userId, FILTER_VALIDATE_INT);

// Validate the entry fields before writing to the database.
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

if ($userId === false || $userId < 1) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'A valid user ID is required.',
    ]);
}

// Flutter sends the selected date and time as YYYY-MM-DD HH:MM:SS.
$date = DateTime::createFromFormat('Y-m-d H:i:s', $transactionDate);
if (!$date || $date->format('Y-m-d H:i:s') !== $transactionDate) {
    sendJsonResponse(422, [
        'success' => false,
        'message' => 'Choose a valid date and time.',
    ]);
}

$imageName = null;
$savedImagePath = null;

try {
    // Connect to SQLite. This also creates the tables if they do not exist.
    require_once __DIR__ . '/dbconnect.php';

    // Make sure the owner account exists before saving the entry or its image.
    $userStatement = $database->prepare('SELECT id FROM users WHERE id = :user_id');
    $userStatement->execute([':user_id' => $userId]);
    if (!$userStatement->fetchColumn()) {
        sendJsonResponse(404, [
            'success' => false,
            'message' => 'The selected user account was not found.',
        ]);
    }

    // If an image was attached, check its size and real file type.
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

        // Create the image folder if this is the first upload.
        $uploadDirectory = __DIR__ . '/uploads';
        if (!is_dir($uploadDirectory) && !mkdir($uploadDirectory, 0755, true)) {
            throw new RuntimeException('Could not create the uploads folder.');
        }

        // Use a random name so uploaded files do not keep their original names.
        $imageName = bin2hex(random_bytes(16)) . '.' . $allowedImages[$imageType];
        $savedImagePath = $uploadDirectory . '/' . $imageName;

        if (!move_uploaded_file($_FILES['image']['tmp_name'], $savedImagePath)) {
            throw new RuntimeException('Could not save the uploaded image.');
        }
    }

    // Save all form data and the generated image name in SQLite.
    $statement = $database->prepare(
        'INSERT INTO budget_entries
            (user_id, title, type, category, amount, transaction_date, description, image_name)
         VALUES
            (:user_id, :title, :type, :category, :amount, :transaction_date, :description, :image_name)'
    );
    $statement->execute([
        ':user_id' => $userId,
        ':title' => $title,
        ':type' => $type,
        ':category' => $category,
        ':amount' => (float) $amount,
        ':transaction_date' => $date->format('Y-m-d H:i:s'),
        ':description' => $description,
        ':image_name' => $imageName,
    ]);

    sendJsonResponse(201, [
        'success' => true,
        'message' => 'Entry saved successfully.',
        'entry' => [
            'id' => (int) $database->lastInsertId(),
            'user_id' => (int) $userId,
            'title' => $title,
            'type' => $type,
            'category' => $category,
            'amount' => (float) $amount,
            'transaction_date' => $date->format('Y-m-d H:i:s'),
            'description' => $description,
            'image_name' => $imageName,
        ],
    ]);
} catch (Throwable $error) {
    // Remove the image if saving the database row failed.
    if ($savedImagePath !== null && file_exists($savedImagePath)) {
        unlink($savedImagePath);
    }

    error_log('Add budget entry error: ' . $error->getMessage());
    sendJsonResponse(500, [
        'success' => false,
        'message' => 'The entry could not be saved.',
    ]);
}
