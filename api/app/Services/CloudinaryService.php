<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class CloudinaryService
{
    protected ?string $cloudName;
    protected ?string $apiKey;
    protected ?string $apiSecret;

    public function __construct()
    {
        $this->cloudName = config('services.cloudinary.cloud_name') ?? env('CLOUDINARY_CLOUD_NAME');
        $this->apiKey = config('services.cloudinary.api_key') ?? env('CLOUDINARY_API_KEY');
        $this->apiSecret = config('services.cloudinary.api_secret') ?? env('CLOUDINARY_API_SECRET');
    }

    /**
     * Upload an image file to Cloudinary
     *
     * @param UploadedFile|string $file UploadedFile instance or local file path
     * @param string $folder Folder name on Cloudinary (e.g. 'cows', 'farms', 'avatars')
     * @return array|null Returns ['secure_url' => ..., 'public_id' => ...] or null on failure
     */
    public function upload($file, string $folder = 'uploads'): ?array
    {
        if (empty($this->cloudName) || empty($this->apiKey) || empty($this->apiSecret)) {
            Log::warning('Cloudinary credentials are not set in environment or config.');
            return null;
        }

        try {
            $timestamp = time();
            $params = [
                'folder' => 'cowsmart/' . $folder,
                'timestamp' => $timestamp,
            ];

            // Generate signature: sha1 of sorted params + apiSecret
            ksort($params);
            $sigString = '';
            foreach ($params as $key => $val) {
                $sigString .= "$key=$val&";
            }
            $sigString = rtrim($sigString, '&') . $this->apiSecret;
            $signature = sha1($sigString);

            $endpoint = "https://api.cloudinary.com/v1_1/{$this->cloudName}/image/upload";

            // Prepare HTTP request with multipart attachment
            $request = Http::asMultipart();

            if ($file instanceof UploadedFile) {
                $request->attach('file', file_get_contents($file->getRealPath()), $file->getClientOriginalName());
            } else {
                $request->attach('file', file_get_contents($file), basename($file));
            }

            $response = $request->post($endpoint, [
                'api_key' => $this->apiKey,
                'timestamp' => $timestamp,
                'folder' => 'cowsmart/' . $folder,
                'signature' => $signature,
            ]);

            if ($response->successful()) {
                $data = $response->json();
                return [
                    'secure_url' => $data['secure_url'],
                    'public_id' => $data['public_id'],
                ];
            }

            Log::error('Cloudinary upload error: ' . $response->body());
            return null;
        } catch (\Throwable $e) {
            Log::error('Cloudinary exception: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Delete an image from Cloudinary by its full URL or public_id
     *
     * @param string|null $urlOrPublicId
     * @return bool
     */
    public function delete(?string $urlOrPublicId): bool
    {
        if (empty($urlOrPublicId) || empty($this->cloudName) || empty($this->apiKey) || empty($this->apiSecret)) {
            return false;
        }

        try {
            $publicId = $this->extractPublicId($urlOrPublicId);
            if (!$publicId) {
                return false;
            }

            $timestamp = time();
            $params = [
                'public_id' => $publicId,
                'timestamp' => $timestamp,
            ];

            ksort($params);
            $sigString = "public_id={$publicId}&timestamp={$timestamp}" . $this->apiSecret;
            $signature = sha1($sigString);

            $endpoint = "https://api.cloudinary.com/v1_1/{$this->cloudName}/image/destroy";

            $response = Http::asForm()->post($endpoint, [
                'api_key' => $this->apiKey,
                'public_id' => $publicId,
                'timestamp' => $timestamp,
                'signature' => $signature,
            ]);

            return $response->successful();
        } catch (\Throwable $e) {
            Log::error('Cloudinary destroy exception: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Extract public_id from Cloudinary URL if a full URL was provided
     */
    public function extractPublicId(string $urlOrId): ?string
    {
        // If it's already a public_id (doesn't start with http)
        if (!str_starts_with($urlOrId, 'http')) {
            return $urlOrId;
        }

        // e.g. https://res.cloudinary.com/dsoiycpdn/image/upload/v1234567890/cowsmart/cows/abc.jpg
        if (preg_match('/\/upload\/(?:v\d+\/)?(.+?)(?:\.[a-zA-Z0-9]+)?$/', $urlOrId, $matches)) {
            return $matches[1];
        }

        return null;
    }
}
