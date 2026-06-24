<?php

$tables = [
    'User' => 'users',
    'Breed' => 'breeds',
    'Disease' => 'diseases',
    'Symptom' => 'symptoms',
    'Medicine' => 'medicines',
    'Vaccine' => 'vaccines',
    'CheckupType' => 'checkup_types',
    'CowType' => 'cow_types',
    'Farm' => 'farms',
    'Zone' => 'zones',
    'Cow' => 'cows',
    'GrowthRecord' => 'growth_records',
    'CullingRecord' => 'culling_records',
    'HealthRecord' => 'health_records',
    'HealthAppointment' => 'health_appointments',
    'BreedingRecord' => 'breeding_records',
    'CalvingRecord' => 'calving_records',
    'FeedingRecord' => 'feeding_records',
    'FinancialRecord' => 'financial_records',
    'CalendarEvent' => 'calendar_events',
    'Notification' => 'notifications',
    'IssueReport' => 'issue_reports',
    'ChatHistory' => 'chat_histories'
];

// Generate Models
foreach ($tables as $model => $table) {
    $content = "<?php\n\nnamespace App\Models;\n\nuse Illuminate\Database\Eloquent\Factories\HasFactory;\nuse Illuminate\Database\Eloquent\Model;\n\nclass $model extends Model\n{\n    use HasFactory;\n    protected \$table = '$table';\n    protected \$guarded = [];\n";
    if ($model == 'User') continue; // Skip overriding User completely, just append or keep default if exists
    
    // Check if ID is string based on SQL
    $content .= "    protected \$keyType = 'string';\n    public \$incrementing = false;\n";
    
    $content .= "}\n";
    
    file_put_contents(__DIR__ . "/app/Models/{$model}.php", $content);
}

// Ensure User Model has string and non-incrementing ID
$userModelPath = __DIR__ . '/app/Models/User.php';
$userModel = file_get_contents($userModelPath);
if (strpos($userModel, "public \$incrementing = false;") === false) {
    $userModel = str_replace("use HasFactory, Notifiable;", "use HasFactory, Notifiable;\n    protected \$keyType = 'string';\n    public \$incrementing = false;\n    protected \$guarded = [];\n", $userModel);
    file_put_contents($userModelPath, $userModel);
}

// Generate Controllers
if (!is_dir(__DIR__ . '/app/Http/Controllers/Api')) {
    mkdir(__DIR__ . '/app/Http/Controllers/Api', 0777, true);
}
foreach ($tables as $model => $table) {
    $content = "<?php\n\nnamespace App\Http\Controllers\Api;\n\nuse App\Http\Controllers\Controller;\nuse App\Models\\$model;\nuse Illuminate\Http\Request;\n\nclass {$model}Controller extends Controller\n{\n    public function index()\n    {\n        return response()->json($model::all());\n    }\n\n    public function store(Request \$request)\n    {\n        \$data = $model::create(\$request->all());\n        return response()->json(\$data, 201);\n    }\n\n    public function show(\$id)\n    {\n        return response()->json($model::findOrFail(\$id));\n    }\n\n    public function update(Request \$request, \$id)\n    {\n        \$data = $model::findOrFail(\$id);\n        \$data->update(\$request->all());\n        return response()->json(\$data);\n    }\n\n    public function destroy(\$id)\n    {\n        $model::destroy(\$id);\n        return response()->json(null, 204);\n    }\n}\n";
    
    file_put_contents(__DIR__ . "/app/Http/Controllers/Api/{$model}Controller.php", $content);
}

// Generate Migration
$migration = "<?php\n\nuse Illuminate\Database\Migrations\Migration;\nuse Illuminate\Database\Schema\Blueprint;\nuse Illuminate\Support\Facades\Schema;\n\nreturn new class extends Migration\n{\n    public function up(): void\n    {\n";
$migration .= <<<'PHP'
        // Master Data
        Schema::create('breeds', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('name', 100)->nullable();
            $table->text('description')->nullable();
            $table->timestamps();
        });

        Schema::create('diseases', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('name', 150)->nullable();
            $table->text('cause')->nullable();
            $table->text('symptoms_desc')->nullable();
            $table->text('observation')->nullable();
            $table->text('treatment')->nullable();
            $table->text('prevention')->nullable();
            $table->timestamps();
        });

        Schema::create('symptoms', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('name', 150)->nullable();
            $table->text('description')->nullable();
            $table->timestamps();
        });

        Schema::create('medicines', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('category', 100)->nullable();
            $table->string('name', 150)->nullable();
            $table->text('indications')->nullable();
            $table->text('dosage_usage')->nullable();
            $table->timestamps();
        });

        Schema::create('vaccines', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('category', 100)->nullable();
            $table->string('name', 150)->nullable();
            $table->text('indications')->nullable();
            $table->text('dosage_usage')->nullable();
            $table->timestamps();
        });

        Schema::create('checkup_types', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('type_name', 100)->nullable();
            $table->timestamps();
        });

        Schema::create('cow_types', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('type_name', 100)->nullable();
            $table->timestamps();
        });

        // Foreign Key Tables
        Schema::create('farms', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('owner_email', 150)->nullable();
            $table->string('name', 150)->nullable();
            $table->text('address')->nullable();
            $table->string('image_url', 255)->nullable();
            $table->timestamps();
            
            $table->foreign('owner_email')->references('email')->on('users')->onUpdate('cascade');
        });

        Schema::create('zones', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('farm_id', 10)->nullable();
            $table->string('name', 100)->nullable();
            $table->timestamps();
            
            $table->foreign('farm_id')->references('id')->on('farms');
        });

        Schema::create('cows', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('farm_id', 10)->nullable();
            $table->string('zone_id', 10)->nullable();
            $table->string('breed_id', 10)->nullable();
            $table->string('cow_type_id', 10)->nullable();
            $table->string('tag_number', 50)->nullable();
            $table->string('name', 100)->nullable();
            $table->date('birth_date')->nullable();
            $table->string('gender', 20)->nullable();
            $table->string('sire_id', 10)->nullable();
            $table->string('dam_id', 10)->nullable();
            $table->string('status', 50)->nullable();
            $table->string('nfc_tag', 100)->nullable();
            $table->string('qr_code', 100)->nullable();
            $table->string('image_url', 255)->nullable();
            $table->timestamps();
            
            $table->foreign('farm_id')->references('id')->on('farms');
            $table->foreign('zone_id')->references('id')->on('zones');
            $table->foreign('breed_id')->references('id')->on('breeds');
            $table->foreign('cow_type_id')->references('id')->on('cow_types');
            $table->foreign('sire_id')->references('id')->on('cows');
            $table->foreign('dam_id')->references('id')->on('cows');
        });

        Schema::create('growth_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('cow_id', 10)->nullable();
            $table->dateTime('record_datetime')->nullable();
            $table->decimal('girth', 8, 2)->nullable();
            $table->decimal('weight', 8, 2)->nullable();
            $table->timestamps();
            
            $table->foreign('cow_id')->references('id')->on('cows');
        });

        Schema::create('culling_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('cow_id', 10)->nullable();
            $table->dateTime('cull_datetime')->nullable();
            $table->string('reason', 255)->nullable();
            $table->decimal('price', 10, 2)->nullable();
            $table->text('note')->nullable();
            $table->timestamps();
            
            $table->foreign('cow_id')->references('id')->on('cows');
        });

        Schema::create('health_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('cow_id', 10)->nullable();
            $table->dateTime('record_datetime')->nullable();
            $table->string('checkup_type_id', 10)->nullable();
            $table->string('disease_id', 10)->nullable();
            $table->string('symptom_id', 10)->nullable();
            $table->string('medicine_id', 10)->nullable();
            $table->string('vaccine_id', 10)->nullable();
            $table->decimal('cost', 10, 2)->nullable();
            $table->string('admin_name', 100)->nullable();
            $table->timestamps();
            
            $table->foreign('cow_id')->references('id')->on('cows');
            $table->foreign('checkup_type_id')->references('id')->on('checkup_types');
            $table->foreign('disease_id')->references('id')->on('diseases');
            $table->foreign('symptom_id')->references('id')->on('symptoms');
            $table->foreign('medicine_id')->references('id')->on('medicines');
            $table->foreign('vaccine_id')->references('id')->on('vaccines');
        });

        Schema::create('health_appointments', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('health_record_id', 10)->nullable();
            $table->string('cow_id', 10)->nullable();
            $table->dateTime('appoint_datetime')->nullable();
            $table->text('description')->nullable();
            $table->string('status', 50)->nullable();
            $table->timestamps();
            
            $table->foreign('health_record_id')->references('id')->on('health_records');
            $table->foreign('cow_id')->references('id')->on('cows');
        });

        Schema::create('breeding_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('dam_id', 10)->nullable();
            $table->date('heat_date')->nullable();
            $table->date('mating_date')->nullable();
            $table->string('sire_id', 10)->nullable();
            $table->date('check_date')->nullable();
            $table->string('pregnancy_result', 100)->nullable();
            $table->date('expected_calving')->nullable();
            $table->timestamps();
            
            $table->foreign('dam_id')->references('id')->on('cows');
            $table->foreign('sire_id')->references('id')->on('cows');
        });

        Schema::create('calving_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('breeding_record_id', 10)->nullable();
            $table->string('dam_id', 10)->nullable();
            $table->dateTime('calving_datetime')->nullable();
            $table->string('calf_id', 10)->nullable();
            $table->string('calving_result', 100)->nullable();
            $table->timestamps();
            
            $table->foreign('breeding_record_id')->references('id')->on('breeding_records');
            $table->foreign('dam_id')->references('id')->on('cows');
            $table->foreign('calf_id')->references('id')->on('cows');
        });

        Schema::create('feeding_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('zone_id', 10)->nullable();
            $table->dateTime('feed_datetime')->nullable();
            $table->string('feed_type', 150)->nullable();
            $table->decimal('amount', 8, 2)->nullable();
            $table->decimal('cost', 10, 2)->nullable();
            $table->timestamps();
            
            $table->foreign('zone_id')->references('id')->on('zones');
        });

        Schema::create('financial_records', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('farm_id', 10)->nullable();
            $table->dateTime('transaction_datetime')->nullable();
            $table->string('trans_type', 50)->nullable();
            $table->string('category', 100)->nullable();
            $table->decimal('amount', 10, 2)->nullable();
            $table->text('description')->nullable();
            $table->timestamps();
            
            $table->foreign('farm_id')->references('id')->on('farms');
        });

        Schema::create('calendar_events', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('farm_id', 10)->nullable();
            $table->string('title', 255)->nullable();
            $table->dateTime('event_datetime')->nullable();
            $table->text('description')->nullable();
            $table->string('reminder_setting', 100)->nullable();
            $table->string('cow_id', 10)->nullable();
            $table->timestamps();
            
            $table->foreign('farm_id')->references('id')->on('farms');
            $table->foreign('cow_id')->references('id')->on('cows');
        });

        Schema::create('notifications', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('user_email', 150)->nullable();
            $table->string('title', 255)->nullable();
            $table->text('message')->nullable();
            $table->dateTime('notify_datetime')->nullable();
            $table->boolean('is_read')->default(0);
            $table->timestamps();
            
            $table->foreign('user_email')->references('email')->on('users')->onUpdate('cascade');
        });

        Schema::create('issue_reports', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('user_email', 150)->nullable();
            $table->string('topic', 255)->nullable();
            $table->text('description')->nullable();
            $table->string('image_url', 255)->nullable();
            $table->string('status', 50)->nullable();
            $table->timestamps();
            
            $table->foreign('user_email')->references('email')->on('users')->onUpdate('cascade');
        });

        Schema::create('chat_histories', function (Blueprint $table) {
            $table->string('id', 10)->primary();
            $table->string('user_email', 150)->nullable();
            $table->text('user_message')->nullable();
            $table->text('ai_response')->nullable();
            $table->dateTime('chat_datetime')->nullable();
            $table->timestamps();
            
            $table->foreign('user_email')->references('email')->on('users')->onUpdate('cascade');
        });
PHP;
$migration .= "\n    }\n\n    public function down(): void\n    {\n";
foreach (array_reverse($tables) as $model => $table) {
    if ($table != 'users') {
        $migration .= "        Schema::dropIfExists('$table');\n";
    }
}
$migration .= "    }\n};\n";

file_put_contents(__DIR__ . "/database/migrations/2025_01_01_000001_create_farm_management_tables.php", $migration);

// Generate API Routes
$routes = "<?php\n\nuse Illuminate\Http\Request;\nuse Illuminate\Support\Facades\Route;\n\n";
foreach ($tables as $model => $table) {
    if ($model == 'User') continue;
    $routes .= "use App\Http\Controllers\Api\\{$model}Controller;\n";
}
$routes .= "\nRoute::middleware('auth:sanctum')->get('/user', function (Request \$request) {\n    return \$request->user();\n});\n\n";
foreach ($tables as $model => $table) {
    if ($model == 'User') continue;
    $routes .= "Route::apiResource('$table', {$model}Controller::class);\n";
}
file_put_contents(__DIR__ . "/routes/api.php", $routes);

echo "Generation complete!\n";
