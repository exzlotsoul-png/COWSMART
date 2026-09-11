<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FirebaseService
{
    /**
     * Send push notification to one or multiple FCM tokens
     * Supports both FCM v1 (if service account credentials exist)
     * and direct HTTP payload dispatch.
     *
     * @param array|string $tokens
     * @param string $title
     * @param string $body
     * @param array $data
     * @return array
     */
    public static function sendPushNotification($tokens, string $title, string $body, array $data = []): array
    {
        $tokenList = is_array($tokens) ? array_filter($tokens) : array_filter([$tokens]);

        if (empty($tokenList)) {
            return ['success' => false, 'sent' => 0, 'message' => 'No valid FCM tokens provided'];
        }

        $serviceAccountPath = config('services.firebase.credentials') 
            ?? storage_path('app/firebase/service-account.json');

        // Check if Firebase Service Account JSON is provided for FCM HTTP v1
        if (file_exists($serviceAccountPath)) {
            return self::sendViaV1($serviceAccountPath, $tokenList, $title, $body, $data);
        }

        // Check if legacy server key is provided in .env
        $serverKey = config('services.firebase.server_key') ?? env('FCM_SERVER_KEY');
        if ($serverKey) {
            return self::sendViaLegacy($serverKey, $tokenList, $title, $body, $data);
        }

        Log::info('[FCM Service] Simulation mode: Notifications logged (Add service-account.json to storage/app/firebase/ to enable live push).', [
            'tokens_count' => count($tokenList),
            'title' => $title,
            'body' => $body,
        ]);

        return [
            'success' => true,
            'sent' => count($tokenList),
            'mode' => 'simulated',
            'message' => 'FCM credentials pending; push notification simulated.',
        ];
    }

    /**
     * Send using Firebase Cloud Messaging HTTP v1 API
     */
    protected static function sendViaV1(string $serviceAccountPath, array $tokens, string $title, string $body, array $data = []): array
    {
        try {
            $json = json_decode(file_get_contents($serviceAccountPath), true);
            if (!$json || empty($json['project_id']) || empty($json['private_key']) || empty($json['client_email'])) {
                throw new \Exception('Invalid Firebase service account JSON structure.');
            }

            $projectId = $json['project_id'];
            $accessToken = self::getGoogleAccessToken($json);

            $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
            $successCount = 0;
            $failedCount = 0;

            foreach ($tokens as $token) {
                $payload = [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        'data' => array_map('strval', $data),
                        'android' => [
                            'priority' => 'high',
                            'notification' => [
                                'sound' => 'default',
                                'channel_id' => 'cowsmart_push_channel',
                            ],
                        ],
                    ],
                ];

                $response = Http::withHeaders([
                    'Authorization' => "Bearer {$accessToken}",
                    'Content-Type' => 'application/json; UTF-8',
                ])->post($url, $payload);

                if ($response->successful()) {
                    $successCount++;
                } else {
                    $failedCount++;
                    Log::warning('[FCM v1 Send Failed]', [
                        'token' => substr($token, 0, 15) . '...',
                        'status' => $response->status(),
                        'response' => $response->json(),
                    ]);
                }
            }

            return [
                'success' => true,
                'sent' => $successCount,
                'failed' => $failedCount,
                'mode' => 'fcm_v1',
            ];
        } catch (\Exception $e) {
            Log::error('[FCM v1 Error]: ' . $e->getMessage());
            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Send using Firebase Cloud Messaging Legacy API (if key available)
     */
    protected static function sendViaLegacy(string $serverKey, array $tokens, string $title, string $body, array $data = []): array
    {
        $url = 'https://fcm.googleapis.com/fcm/send';
        $payload = [
            'registration_ids' => array_values($tokens),
            'notification' => [
                'title' => $title,
                'body' => $body,
                'sound' => 'default',
            ],
            'data' => $data,
            'priority' => 'high',
        ];

        try {
            $response = Http::withHeaders([
                'Authorization' => "key={$serverKey}",
                'Content-Type' => 'application/json',
            ])->post($url, $payload);

            return [
                'success' => $response->successful(),
                'response' => $response->json(),
                'mode' => 'legacy',
            ];
        } catch (\Exception $e) {
            Log::error('[FCM Legacy Error]: ' . $e->getMessage());
            return ['success' => false, 'message' => $e->getMessage()];
        }
    }

    /**
     * Generate OAuth2 Access Token using Service Account (Pure PHP JWT)
     */
    protected static function getGoogleAccessToken(array $json): string
    {
        $now = time();
        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $claim = [
            'iss' => $json['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ];

        $base64UrlHeader = self::base64UrlEncode(json_encode($header));
        $base64UrlClaim = self::base64UrlEncode(json_encode($claim));
        $signaturePayload = "{$base64UrlHeader}.{$base64UrlClaim}";

        $binarySignature = '';
        $privateKey = openssl_pkey_get_private($json['private_key']);
        if (!$privateKey) {
            throw new \Exception('Failed to load private key from Firebase Service Account.');
        }

        openssl_sign($signaturePayload, $binarySignature, $privateKey, OPENSSL_ALGO_SHA256);
        $jwt = "{$signaturePayload}." . self::base64UrlEncode($binarySignature);

        $response = Http::asForm()->post('https://oauth2.googleapis.com/token', [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]);

        if ($response->successful() && !empty($response->json('access_token'))) {
            return $response->json('access_token');
        }

        throw new \Exception('Failed to retrieve Google OAuth2 access token: ' . $response->body());
    }

    private static function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
