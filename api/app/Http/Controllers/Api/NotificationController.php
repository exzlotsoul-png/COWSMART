<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class NotificationController extends Controller
{
    public function index()
    {
        $user = Auth::user();
        return response()->json(
            Notification::where('email', $user->email)
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
        if (empty($data['id'])) {
            $data['id'] = 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8);
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
}
