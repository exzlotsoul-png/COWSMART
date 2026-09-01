<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class NotificationController extends Controller
{
    public function index()
    {
        $user = Auth::user();
        return response()->json(
            Notification::where('email', $user->email)
                ->orderByDesc('created_at')
                ->orderByDesc('notify_datetime')
                ->get()
        );
    }

    public function store(Request $request)
    {
        $data = $request->all();
        if (empty($data['email'])) {
            $data['email'] = Auth::user()->email;
        }
        $notif = Notification::create($data);
        return response()->json($notif, 201);
    }

    public function show($id)
    {
        return response()->json(Notification::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Notification::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Notification::destroy($id);
        return response()->json(null, 204);
    }

    /**
     * Admin: Get all broadcast history and system stats
     */
    public function adminBroadcastIndex(Request $request)
    {
        $notifications = Notification::where('message', 'like', '%[broadcast:%')
            ->orWhere('title', 'like', '%ประกาศ%')
            ->orderByDesc('created_at')
            ->get();

        $broadcasts = [];
        $grouped = $notifications->groupBy(function ($item) {
            if (preg_match('/\[broadcast:(.*?)\]/', $item->message, $matches)) {
                return $matches[1];
            }
            return $item->title . '_' . ($item->created_at ? $item->created_at->format('Y-m-d H:i') : '');
        });

        foreach ($grouped as $key => $items) {
            $first = $items->first();
            $cleanMessage = preg_replace('/\[broadcast:.*?\]/', '', $first->message ?? '');
            $cleanMessage = trim($cleanMessage);

            $broadcasts[] = [
                'id' => $first->id,
                'broadcast_key' => $key,
                'title' => $first->title,
                'message' => $cleanMessage,
                'sent_at' => $first->notify_datetime ?? $first->created_at,
                'recipients_count' => $items->count(),
                'read_count' => $items->where('is_read', 1)->count(),
                'recipients' => $items->pluck('email')->unique()->values(),
            ];
        }

        $totalUsers = User::count();
        $totalNotifications = Notification::count();
        $totalBroadcasts = count($broadcasts);

        return response()->json([
            'success' => true,
            'data' => $broadcasts,
            'stats' => [
                'total_users' => $totalUsers,
                'total_broadcasts' => $totalBroadcasts,
                'total_notifications' => $totalNotifications,
            ],
        ]);
    }

    /**
     * Admin: Send broadcast notification to all users or target group
     */
    public function broadcast(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'category' => 'nullable|string|max:100',
            'target_type' => 'nullable|string|in:all,active,farmers',
        ]);

        $title = trim($validated['title']);
        $message = trim($validated['message']);
        $category = $validated['category'] ?? 'ประกาศทั่วไป';
        $targetType = $validated['target_type'] ?? 'all';

        // Tag format in message to track broadcast group
        $broadcastTag = '[broadcast:' . uniqid('bc_') . ']';
        $fullMessage = "{$message}\n{$broadcastTag}";

        // Get recipients
        $usersQuery = User::query();
        if ($targetType === 'active') {
            $usersQuery->where('is_active', true);
        }
        $users = $usersQuery->get(['email', 'first_name', 'last_name']);

        if ($users->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'ไม่พบบัญชีผู้ใช้งานในระบบสำหรับส่งการแจ้งเตือน',
            ], 400);
        }

        $now = Carbon::now();
        $createdCount = 0;

        foreach ($users as $user) {
            Notification::create([
                'email' => $user->email,
                'title' => $title,
                'message' => $fullMessage,
                'notify_datetime' => $now,
                'is_read' => 0,
            ]);
            $createdCount++;
        }

        return response()->json([
            'success' => true,
            'message' => "ส่งประกาศแจ้งเตือนถึงผู้ใช้งานสำเร็จทั้งหมด {$createdCount} บัญชี",
            'data' => [
                'title' => $title,
                'category' => $category,
                'recipients_count' => $createdCount,
                'sent_at' => $now->toDateTimeString(),
            ],
        ], 201);
    }

    /**
     * Admin: Delete broadcast announcement by key or title
     */
    public function deleteBroadcastByGroup(Request $request)
    {
        $validated = $request->validate([
            'broadcast_key' => 'nullable|string',
            'title' => 'nullable|string',
            'id' => 'nullable|string',
        ]);

        if (!empty($validated['broadcast_key'])) {
            $key = $validated['broadcast_key'];
            Notification::where('message', 'like', "%[broadcast:{$key}]%")->delete();
        } elseif (!empty($validated['id'])) {
            $notif = Notification::find($validated['id']);
            if ($notif) {
                if (preg_match('/\[broadcast:(.*?)\]/', $notif->message, $matches)) {
                    Notification::where('message', 'like', "%[broadcast:{$matches[1]}]%")->delete();
                } else {
                    Notification::where('title', $notif->title)
                        ->where('created_at', $notif->created_at)
                        ->delete();
                }
            }
        } elseif (!empty($validated['title'])) {
            Notification::where('title', $validated['title'])->delete();
        }

        return response()->json([
            'success' => true,
            'message' => 'ลบประกาศแจ้งเตือนเรียบร้อยแล้ว',
        ]);
    }
}
