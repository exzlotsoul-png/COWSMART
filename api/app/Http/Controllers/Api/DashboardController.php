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
    private array $thaiMonths = [
        'มกราคม' => 1, 'กุมภาพันธ์' => 2, 'มีนาคม' => 3, 'เมษายน' => 4,
        'พฤษภาคม' => 5, 'มิถุนายน' => 6, 'กรกฎาคม' => 7, 'สิงหาคม' => 8,
        'กันยายน' => 9, 'ตุลาคม' => 10, 'พฤศจิกายน' => 11, 'ธันวาคม' => 12
    ];

    private function parseMonth($month): ?int
    {
        if (!$month || $month === 'all') return null;
        if (is_numeric($month)) return (int)$month;
        return $this->thaiMonths[$month] ?? null;
    }

    private function parseYear($year): ?int
    {
        if (!$year || $year === 'all') return null;
        $y = (int)$year;
        if ($y > 2400) {
            $y -= 543; // Convert Thai Buddhist Year to AD
        }
        return $y;
    }

    public function index(Request $request)
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

            // Top 5 Diseases filtered by Month & Year
            $diseaseMonth = $this->parseMonth($request->query('disease_month'));
            $diseaseYear = $this->parseYear($request->query('disease_year'));

            $topDiseasesQuery = DB::table('health_records')
                ->join('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
                ->select('diseases.name as disease_name', DB::raw('count(*) as count'));

            if ($diseaseYear) {
                $topDiseasesQuery->whereYear(DB::raw('COALESCE(health_records.record_date, health_records.created_at)'), $diseaseYear);
            }

            if ($diseaseMonth) {
                $topDiseasesQuery->whereMonth(DB::raw('COALESCE(health_records.record_date, health_records.created_at)'), $diseaseMonth);
            }

            $topDiseases = $topDiseasesQuery
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
                ->take(4)
                ->get();

            // Health Proportion (Active cows only)
            $healthStatus = Cow::select('status', DB::raw('count(*) as count'))
                ->where(function ($q) {
                    $q->whereNotIn('status', ['sold', 'deceased', 'removed', 'ขายแล้ว', 'ตาย', 'คัดทิ้ง'])
                      ->orWhereNull('status');
                })
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
