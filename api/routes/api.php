<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\BreedController;
use App\Http\Controllers\Api\DiseaseController;
use App\Http\Controllers\Api\MedicineController;
use App\Http\Controllers\Api\VaccineController;
use App\Http\Controllers\Api\CheckupTypeController;
use App\Http\Controllers\Api\CowTypeController;
use App\Http\Controllers\Api\FarmController;
use App\Http\Controllers\Api\ZoneController;
use App\Http\Controllers\Api\CowController;
use App\Http\Controllers\Api\GrowthRecordController;
use App\Http\Controllers\Api\CullingRecordController;
use App\Http\Controllers\Api\HealthRecordController;
use App\Http\Controllers\Api\HealthAppointmentController;
use App\Http\Controllers\Api\BreedingRecordController;
use App\Http\Controllers\Api\CalvingRecordController;
use App\Http\Controllers\Api\FeedingRecordController;
use App\Http\Controllers\Api\FeedInventoryController;
use App\Http\Controllers\Api\FinancialRecordController;
use App\Http\Controllers\Api\CalendarEventController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\IssueReportController;
use App\Http\Controllers\Api\ChatHistoryController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ImageController;
use App\Http\Controllers\Api\MarketPriceController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UnitController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\DashboardController;

Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/verify-otp', [AuthController::class, 'verifyOtp']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

// Serve storage files with CORS headers (for Flutter web)
Route::get('/storage/{path}', function ($path) {
    $fullPath = storage_path('app/public/' . $path);
    if (!file_exists($fullPath)) {
        abort(404);
    }
    $mime = mime_content_type($fullPath);
    return response()->file($fullPath, [
        'Access-Control-Allow-Origin' => '*',
        'Content-Type' => $mime,
    ]);
})->where('path', '.*');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);
    Route::post('/images/upload', [ImageController::class, 'upload']);

    Route::apiResource('breeds', BreedController::class);
    Route::apiResource('diseases', DiseaseController::class);
    Route::apiResource('medicines', MedicineController::class);
    Route::apiResource('vaccines', VaccineController::class);
    Route::apiResource('checkup_types', CheckupTypeController::class);
    Route::apiResource('cow_types', CowTypeController::class);
    
    // Dashboard
    Route::get('/dashboard', [DashboardController::class, 'index']);

    // Standard resources
    Route::apiResource('farms', FarmController::class);
    Route::apiResource('zones', ZoneController::class);
    Route::apiResource('cows', CowController::class);
    Route::apiResource('growth_records', GrowthRecordController::class);
    Route::apiResource('culling_records', CullingRecordController::class);
    Route::apiResource('health_records', HealthRecordController::class);
    Route::apiResource('health_appointments', HealthAppointmentController::class);
    Route::apiResource('breeding_records', BreedingRecordController::class);
    Route::apiResource('calving_records', CalvingRecordController::class);
    Route::apiResource('feeding_records', FeedingRecordController::class);
    Route::apiResource('feed_inventories', FeedInventoryController::class);
    Route::apiResource('financial_records', FinancialRecordController::class);
    Route::apiResource('calendar_events', CalendarEventController::class);
    Route::apiResource('notifications', NotificationController::class);
    Route::apiResource('issue_reports', IssueReportController::class);
    Route::apiResource('chat_histories', ChatHistoryController::class);
    Route::apiResource('market_prices', MarketPriceController::class);
    Route::apiResource('users', UserController::class);
    Route::apiResource('units', UnitController::class);
    Route::apiResource('settings', SettingController::class);
});
