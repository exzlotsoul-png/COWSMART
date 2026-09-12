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
use App\Http\Controllers\Api\FeedInventoryController;
use App\Http\Controllers\Api\FinancialRecordController;
use App\Http\Controllers\Api\CalendarEventController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\IssueReportController;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ImageController;
use App\Http\Controllers\Api\MarketPriceController;
use App\Http\Controllers\Api\AIchatbotController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UnitController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\AppointmentTypeController;
use App\Http\Controllers\Api\CowCostController;
use App\Http\Controllers\Api\ReportTopicController;

Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/verify-otp', [AuthController::class, 'verifyOtp']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

Route::get('/test-db', function () {
    try {
        \Illuminate\Support\Facades\DB::connection()->getPdo();
        $userCount = \App\Models\User::count();
        return response()->json([
            'status' => 'connected',
            'database' => \Illuminate\Support\Facades\DB::connection()->getDatabaseName(),
            'users_count' => $userCount
        ]);
    } catch (\Throwable $e) {
        return response()->json([
            'status' => 'error',
            'message' => $e->getMessage(),
            'trace' => $e->getTraceAsString()
        ], 500);
    }
});

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
    Route::post('/user/fcm-token', [UserController::class, 'updateFcmToken']);
    Route::post('/images/upload', [ImageController::class, 'upload']);
    Route::post('/images/delete', [ImageController::class, 'deleteImage']);

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
    Route::get('/cow_costs/{cowId}', [CowCostController::class, 'show']);
    Route::apiResource('growth_records', GrowthRecordController::class);
    Route::apiResource('culling_records', CullingRecordController::class);
    Route::apiResource('health_records', HealthRecordController::class);
    Route::apiResource('health_appointments', HealthAppointmentController::class);
    Route::apiResource('breeding_records', BreedingRecordController::class);

    Route::apiResource('feed_inventories', FeedInventoryController::class);
    Route::apiResource('financial_records', FinancialRecordController::class);
    Route::apiResource('calendar_events', CalendarEventController::class);
    Route::get('/admin/broadcast-notifications', [NotificationController::class, 'adminBroadcastIndex']);
    Route::post('/admin/broadcast-notifications', [NotificationController::class, 'broadcast']);
    Route::post('/admin/broadcast-notifications/delete-group', [NotificationController::class, 'deleteBroadcastByGroup']);
    Route::apiResource('notifications', NotificationController::class);
    Route::apiResource('issue_reports', IssueReportController::class);

    Route::post('/market_prices/sync', [MarketPriceController::class, 'sync']);
    Route::post('/market_prices/parse-image', [MarketPriceController::class, 'parseImageReport']);
    Route::post('/market_prices/batch', [MarketPriceController::class, 'batchStore']);
    Route::get('/market_prices/history', [MarketPriceController::class, 'history']);
    Route::apiResource('market_prices', MarketPriceController::class);
    Route::apiResource('users', UserController::class);
    Route::apiResource('units', UnitController::class);
    Route::apiResource('settings', SettingController::class);
    Route::apiResource('appointment_types', AppointmentTypeController::class);
    Route::apiResource('report_topics', ReportTopicController::class);
    Route::apiResource('ai_chatbot', AIchatbotController::class);
    Route::apiResource('ai_knowledges', AIchatbotController::class);
    Route::get('/ai/suggested-topics', [AIchatbotController::class, 'getSuggestedTopics']);
    Route::post('/ai/consult', [AIchatbotController::class, 'consult']);
});
