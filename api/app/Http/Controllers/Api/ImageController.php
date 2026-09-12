<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CloudinaryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Auth;

class ImageController extends Controller
{
    protected CloudinaryService $cloudinary;

    public function __construct(CloudinaryService $cloudinary)
    {
        $this->cloudinary = $cloudinary;
    }

    public function upload(Request $request)
    {
        $request->validate([
            'type' => 'required|string|in:avatar,farm,cow,health,issue',
            'entity_id' => 'required|string',
            'image' => 'required|image|mimes:jpg,jpeg,png,webp,heic,heif|max:20480',
        ]);

        $type = $request->input('type');
        $entityId = $request->input('entity_id');
        $user = Auth::user();

        $response = [];

        // Upload to Cloudinary first
        $cloudinaryResult = $this->cloudinary->upload($request->file('image'), $type . 's');
        $imageUrl = $cloudinaryResult['secure_url'] ?? null;

        // Fallback to local storage if Cloudinary fails
        if (!$imageUrl) {
            $folderMap = [
                'avatar' => 'avatars',
                'farm' => 'farms',
                'cow' => 'cows',
                'health' => 'health',
                'issue' => 'issues',
            ];
            $localFolder = $folderMap[$type] ?? 'uploads';
            $path = $request->file('image')->store($localFolder, 'public');
            $imageUrl = $path; // relative path for local storage
        }

        switch ($type) {
            case 'avatar':
                if ($user->email != $entityId) {
                    return response()->json(['message' => 'ไม่มีสิทธิ์อัปโหลดรูปนี้'], 403);
                }

                // Delete old avatar
                $this->deleteOldImage($user->profile_image);

                $user->profile_image = $imageUrl;
                $user->save();

                $response = [
                    'message' => 'อัปโหลดรูปโปรไฟล์สำเร็จ',
                    'user' => $user,
                    'url' => $user->avatar_full_url ?? $imageUrl,
                ];
                break;

            case 'farm':
                $farm = \App\Models\Farm::where('farm_id', $entityId)
                    ->where('email', $user->email)
                    ->firstOrFail();

                // Delete old farm image
                $this->deleteOldImage($farm->image_url);

                $farm->image_url = $imageUrl;
                $farm->save();

                $response = [
                    'message' => 'อัปโหลดรูปฟาร์มสำเร็จ',
                    'farm' => $farm,
                    'url' => $farm->image_full_url ?? $imageUrl,
                ];
                break;

            case 'cow':
                $cow = \App\Models\Cow::where('cow_id', $entityId)
                    ->whereHas('farm', function ($query) use ($user) {
                        $query->where('email', $user->email);
                    })
                    ->firstOrFail();

                // Delete old cow image
                $this->deleteOldImage($cow->image_url);

                $cow->image_url = $imageUrl;
                $cow->save();

                $response = [
                    'message' => 'อัปโหลดรูปวัวสำเร็จ',
                    'cow' => $cow,
                    'url' => $cow->image_full_url ?? $imageUrl,
                ];
                break;

            case 'health':
                $response = [
                    'message' => 'อัปโหลดรูปแผล/อาการสำเร็จ',
                    'path' => $imageUrl,
                    'url' => str_starts_with($imageUrl, 'http') ? $imageUrl : asset('storage/' . $imageUrl),
                ];
                break;

            case 'issue':
                $response = [
                    'message' => 'อัปโหลดรูปภาพรายงานปัญหาสำเร็จ',
                    'path' => $imageUrl,
                    'url' => str_starts_with($imageUrl, 'http') ? $imageUrl : asset('storage/' . $imageUrl),
                ];
                break;
        }

        return response()->json($response);
    }

    /**
     * Delete an old image whether it is stored on Cloudinary or local storage
     */
    protected function deleteOldImage(?string $pathOrUrl): void
    {
        if (empty($pathOrUrl)) {
            return;
        }

        if (str_contains($pathOrUrl, 'cloudinary.com')) {
            $this->cloudinary->delete($pathOrUrl);
        } else {
            $localPath = preg_match('/storage\/(.+)$/', $pathOrUrl, $matches) ? $matches[1] : ltrim($pathOrUrl, '/');
            $localPath = preg_replace('/^storage\//', '', $localPath);
            if ($localPath && !str_starts_with($localPath, 'http') && Storage::disk('public')->exists($localPath)) {
                Storage::disk('public')->delete($localPath);
            }
        }
    }

    public function deleteImage(Request $request)
    {
        $request->validate([
            'path' => 'required|string',
        ]);

        $rawPath = $request->input('path');
        $this->deleteOldImage($rawPath);

        return response()->json(['message' => 'ลบรูปภาพจากระบบเรียบร้อยแล้ว']);
    }
}
