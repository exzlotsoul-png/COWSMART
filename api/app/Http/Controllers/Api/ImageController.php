<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Auth;

class ImageController extends Controller
{
    public function upload(Request $request)
    {
        $request->validate([
            'type' => 'required|string|in:avatar,farm,cow,health',
            'entity_id' => 'required|string',
            'image' => 'required|image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);

        $type = $request->input('type');
        $entityId = $request->input('entity_id');
        $user = Auth::user();

        $path = null;
        $response = [];

        switch ($type) {
            case 'avatar':
                // User's primary key is email, so entity_id should be the user's email
                if ($user->email != $entityId) {
                    return response()->json(['message' => 'ไม่มีสิทธิ์อัปโหลดรูปนี้'], 403);
                }

                if ($user->profile_image && !str_starts_with($user->profile_image, 'http')) {
                    Storage::disk('public')->delete($user->profile_image);
                }

                $path = $request->file('image')->store('avatars', 'public');
                $user->profile_image = $path;
                $user->save();

                $response = [
                    'message' => 'อัปโหลดรูปโปรไฟล์สำเร็จ',
                    'user' => $user,
                    'url' => asset('storage/' . $path),
                ];
                break;

            case 'farm':
                $farm = \App\Models\Farm::where('farm_id', $entityId)
                    ->where('email', $user->email)
                    ->firstOrFail();

                if ($farm->image_url && !str_starts_with($farm->image_url, 'http')) {
                    Storage::disk('public')->delete($farm->image_url);
                }

                $path = $request->file('image')->store('farms', 'public');
                $farm->image_url = $path;
                $farm->save();

                $response = [
                    'message' => 'อัปโหลดรูปฟาร์มสำเร็จ',
                    'farm' => $farm,
                    'url' => asset('storage/' . $path),
                ];
                break;

            case 'cow':
                $cow = \App\Models\Cow::where('cow_id', $entityId)
                    ->whereHas('farm', function ($query) use ($user) {
                        $query->where('email', $user->email);
                    })
                    ->firstOrFail();

                if ($cow->image_url && !str_starts_with($cow->image_url, 'http')) {
                    Storage::disk('public')->delete($cow->image_url);
                }

                $path = $request->file('image')->store('cows', 'public');
                $cow->image_url = $path;
                $cow->save();

                $response = [
                    'message' => 'อัปโหลดรูปวัวสำเร็จ',
                    'cow' => $cow,
                    'url' => asset('storage/' . $path),
                ];
                break;

            case 'health':
                $path = $request->file('image')->store('health', 'public');
                $response = [
                    'message' => 'อัปโหลดรูปแผล/อาการสำเร็จ',
                    'path' => $path,
                    'url' => asset('storage/' . $path),
                ];
                break;
        }

        return response()->json($response);
    }
}
