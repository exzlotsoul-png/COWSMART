<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index()
    {
        return response()->json(User::all());
    }

    public function store(Request $request)
    {
        $data = User::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(User::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = User::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        User::destroy($id);
        return response()->json(null, 204);
    }

    /**
     * Update or bind FCM device token for push notifications
     */
    public function updateFcmToken(Request $request)
    {
        $request->validate([
            'fcm_token' => 'nullable|string',
        ]);

        $user = $request->user();
        if ($user) {
            $user->update(['fcm_token' => $request->input('fcm_token')]);
            return response()->json([
                'success' => true,
                'message' => 'FCM Device Token updated successfully',
            ]);
        }

        return response()->json(['success' => false, 'message' => 'Unauthorized'], 401);
    }
}
