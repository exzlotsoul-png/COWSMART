<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Serve storage files with CORS headers for Flutter web development
Route::get('/storage/{path}', function ($path) {
    $fullPath = storage_path('app/public/' . $path);

    if (!file_exists($fullPath)) {
        abort(404);
    }

    $mime = mime_content_type($fullPath);

    return response()->file($fullPath, [
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Methods' => 'GET',
        'Content-Type' => $mime,
    ]);
})->where('path', '.*');
