<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $log = "[" . date('Y-m-d H:i:s') . "] User: " . $_POST['username'] . "\n";
    file_put_contents('/usr/local/apache2/logs/login_attempts.log', $log, FILE_APPEND);
    header("Location: /failed.html");
}
?>
