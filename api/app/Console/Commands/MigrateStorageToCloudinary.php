<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\CloudinaryService;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\User;

class MigrateStorageToCloudinary extends Command
{
    protected $signature = 'storage:migrate-cloudinary';
    protected $description = 'Upload all local storage images to Cloudinary and update database records';

    public function handle(CloudinaryService $cloudinary)
    {
        $this->info('Starting migration to Cloudinary...');

        // 1. Farms
        $farms = Farm::whereNotNull('image_url')->where('image_url', 'not like', 'http%')->get();
        $this->info("Found {$farms->count()} farm records to check.");
        foreach ($farms as $farm) {
            $rawPath = preg_replace('/^storage\//', '', ltrim($farm->image_url, '/'));
            $localPath = storage_path('app/public/' . $rawPath);
            if (file_exists($localPath)) {
                $this->line("Uploading Farm [{$farm->farm_id}] image: {$rawPath}");
                $res = $cloudinary->upload($localPath, 'farms');
                if ($res && !empty($res['secure_url'])) {
                    $farm->image_url = $res['secure_url'];
                    $farm->save();
                    $this->info(" -> Success: {$res['secure_url']}");
                } else {
                    $this->error(" -> Failed to upload {$rawPath}");
                }
            } else {
                $this->warn("Local file not found: {$localPath}");
            }
        }

        // 2. Cows
        $cows = Cow::whereNotNull('image_url')->where('image_url', 'not like', 'http%')->get();
        $this->info("Found {$cows->count()} cow records to check.");
        foreach ($cows as $cow) {
            $rawPath = preg_replace('/^storage\//', '', ltrim($cow->image_url, '/'));
            $localPath = storage_path('app/public/' . $rawPath);
            if (file_exists($localPath)) {
                $this->line("Uploading Cow [{$cow->cow_id}] image: {$rawPath}");
                $res = $cloudinary->upload($localPath, 'cows');
                if ($res && !empty($res['secure_url'])) {
                    $cow->image_url = $res['secure_url'];
                    $cow->save();
                    $this->info(" -> Success: {$res['secure_url']}");
                } else {
                    $this->error(" -> Failed to upload {$rawPath}");
                }
            } else {
                $this->warn("Local file not found: {$localPath}");
            }
        }

        // 3. Users (avatars)
        $users = User::whereNotNull('profile_image')->where('profile_image', 'not like', 'http%')->get();
        $this->info("Found {$users->count()} user avatar records to check.");
        foreach ($users as $user) {
            $rawPath = preg_replace('/^storage\//', '', ltrim($user->profile_image, '/'));
            $localPath = storage_path('app/public/' . $rawPath);
            if (file_exists($localPath)) {
                $this->line("Uploading User [{$user->email}] avatar: {$rawPath}");
                $res = $cloudinary->upload($localPath, 'avatars');
                if ($res && !empty($res['secure_url'])) {
                    $user->profile_image = $res['secure_url'];
                    $user->save();
                    $this->info(" -> Success: {$res['secure_url']}");
                } else {
                    $this->error(" -> Failed to upload {$rawPath}");
                }
            } else {
                $this->warn("Local file not found: {$localPath}");
            }
        }

        $this->info('Migration to Cloudinary completed successfully!');
        return 0;
    }
}
