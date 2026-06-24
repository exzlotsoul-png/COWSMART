<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Cow;
use App\Models\User;
use App\Models\Farm;
use App\Models\IssueReport;
use App\Models\HealthRecord;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class DashboardController extends Controller
{
    public function index()
    {
        try {
            $totalCows = Cow::count();
            $totalUsers = User::count();
            $activeFarms = Farm::count();
            $newborns = Cow::where('birth_date', '>=', Carbon::now()->subMonth())->count();
            
            // Latest User Reports (Issue Reports)
            $latestReports = DB::table('issue_reports')
                ->leftJoin('users', 'issue_reports.email', '=', 'users.email')
                ->select('issue_reports.*', 'users.first_name', 'users.last_name')
                ->orderBy('issue_reports.created_at', 'desc')
                ->take(4)
                ->get();

            // Top 5 Diseases
            $topDiseases = DB::table('health_records')
                ->join('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
                ->select('diseases.name as disease_name', DB::raw('count(*) as count'))
                ->groupBy('health_records.disease_id', 'diseases.name')
                ->orderByDesc('count')
                ->take(5)
                ->get();
                
            // Popular Breeds
            $popularBreeds = DB::table('cows')
                ->join('breeds', 'cows.breed_id', '=', 'breeds.breed_id')
                ->select('breeds.name as breed_name', DB::raw('count(*) as count'))
                ->groupBy('cows.breed_id', 'breeds.name')
                ->orderByDesc('count')
                ->take(4) // fetch top 4 or 3
                ->get();

            // Health Proportion
            $healthStatus = Cow::select('status', DB::raw('count(*) as count'))
                ->whereNotNull('status')
                ->groupBy('status')
                ->get();

            return response()->json([
                'success' => true,
                'data' => [
                    'summary' => [
                        'total_users' => $totalUsers,
                        'active_farms' => $activeFarms,
                        'total_cows' => $totalCows,
                        'newborns' => $newborns,
                    ],
                    'latest_reports' => $latestReports,
                    'top_diseases' => $topDiseases,
                    'popular_breeds' => $popularBreeds,
                    'health_status' => $healthStatus
                ]
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Error fetching dashboard data',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}
