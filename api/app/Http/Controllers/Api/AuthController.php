<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
            ], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'เข้าสู่ระบบสำเร็จ',
            'user' => $user,
            'token' => $token,
            'access_token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    public function me(Request $request)
    {
        return response()->json([
            'user' => $request->user(),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'ออกจากระบบสำเร็จ',
        ]);
    }

    public function register(Request $request)
    {
        $request->validate([
            'first_name' => 'required|string|max:50',
            'last_name' => 'required|string|max:50',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::create([
            'first_name' => $request->first_name,
            'last_name' => $request->last_name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => '1', // Default role
            'created_at' => now(),
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => $user,
        ], 201);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'name' => 'required|string|max:255',
            'phone' => 'nullable|string|max:20',
            'avatar' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
        ]);

        $user->name = $request->name;

        if ($request->has('phone')) {
            $user->phone = $request->phone;
        }

        if ($request->hasFile('avatar')) {
            if ($user->avatar && Storage::disk('public')->exists($user->avatar)) {
                Storage::disk('public')->delete($user->avatar);
            }
            $path = $request->file('avatar')->store('avatars', 'public');
            $user->avatar = $path;
        }

        $user->save();

        return response()->json([
            'message' => 'อัปเดตข้อมูลส่วนตัวสำเร็จ',
            'user' => $user,
        ]);
    }

    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:6|confirmed',
        ]);

        $user = $request->user();

        // Check current password
        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'message' => 'รหัสผ่านปัจจุบันไม่ถูกต้อง',
                'errors' => ['current_password' => ['รหัสผ่านปัจจุบันไม่ถูกต้อง']],
            ], 422);
        }

        // Check if new password is the same as current password
        if (Hash::check($request->new_password, $user->password)) {
            return response()->json([
                'message' => 'รหัสผ่านใหม่ต้องไม่ตรงกับรหัสผ่านเดิม',
                'errors' => ['new_password' => ['รหัสผ่านใหม่ต้องไม่ตรงกับรหัสผ่านเดิม']],
            ], 422);
        }

        // Update password
        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'message' => 'เปลี่ยนรหัสผ่านสำเร็จ',
        ]);
    }

    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'message' => 'ไม่พบผู้ใช้นี้ในระบบ',
            ], 404);
        }

        // Generate 6-digit OTP
        $otp = (string) rand(100000, 999999);
        Cache::put('otp_' . $request->email, $otp, now()->addMinutes(10));

        $mailSent = false;
        $errorMessage = '';
        try {
            Mail::send([], [], function ($message) use ($request, $otp) {
                $message->to($request->email)
                    ->subject('รหัส OTP สำหรับรีเซ็ตรหัสผ่าน - COWSMART')
                    ->html("
                        <div style='font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;'>
                            <div style='text-align: center; margin-bottom: 24px;'>
                                <h2 style='color: #2E7D32; margin: 0; font-size: 26px; font-weight: bold;'>COWSMART</h2>
                                <p style='color: #666; font-size: 14px; margin-top: 4px;'>ระบบบริหารจัดการฟาร์มวัว</p>
                            </div>
                            <div style='background-color: #F1F8E9; padding: 20px; border-radius: 10px; text-align: center; margin-bottom: 24px; border: 1px solid #C8E6C9;'>
                                <p style='margin: 0 0 10px 0; color: #2E7D32; font-size: 16px; font-weight: 500;'>รหัส OTP สำหรับรีเซ็ตรหัสผ่านของคุณคือ:</p>
                                <h1 style='color: #1B5E20; font-size: 40px; letter-spacing: 6px; margin: 12px 0; font-family: monospace;'>{$otp}</h1>
                                <p style='margin: 0; color: #558B2F; font-size: 13px;'>⏱️ รหัสนี้มีอายุใช้งาน 10 นาที</p>
                            </div>
                            <p style='color: #666; font-size: 14px; line-height: 1.6;'>หากคุณไม่ได้เป็นผู้ร้องขอการรีเซ็ตรหัสผ่าน โปรดข้ามอีเมลฉบับนี้</p>
                            <hr style='border: none; border-top: 1px solid #eee; margin: 24px 0;'>
                            <p style='color: #aaa; font-size: 12px; text-align: center; margin: 0;'>© COWSMART Farm Management System</p>
                        </div>
                    ");
            });
            $mailSent = true;
        } catch (\Throwable $e) {
            Log::error('Failed to send OTP email to ' . $request->email . ': ' . $e->getMessage());
            $errorMessage = $e->getMessage();
        }

        $res = [
            'message' => $mailSent
                ? 'ส่งรหัส OTP ไปยังอีเมล ' . $request->email . ' เรียบร้อยแล้ว'
                : 'สร้างรหัส OTP เรียบร้อยแล้ว (ไม่สามารถส่งอีเมลได้: ' . $errorMessage . ')',
        ];

        if (!$mailSent) {
            $res['otp'] = $otp;
        }

        return response()->json($res);
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'required|string|size:6',
        ]);

        $cachedOtp = Cache::get('otp_' . $request->email);

        if (!$cachedOtp || $cachedOtp !== $request->otp) {
            return response()->json([
                'message' => 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ',
            ], 422);
        }

        return response()->json([
            'message' => 'ยืนยันรหัส OTP สำเร็จ',
        ]);
    }

    public function resetPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'required|string|size:6',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $cachedOtp = Cache::get('otp_' . $request->email);

        if (!$cachedOtp || $cachedOtp !== $request->otp) {
            return response()->json([
                'message' => 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ',
            ], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'message' => 'ไม่พบผู้ใช้นี้ในระบบ',
            ], 404);
        }

        // Check if new password is the same as current password
        if (Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'รหัสผ่านใหม่ต้องไม่ตรงกับรหัสผ่านเดิม',
                'errors' => ['password' => ['รหัสผ่านใหม่ต้องไม่ตรงกับรหัสผ่านเดิม']],
            ], 422);
        }

        $user->password = Hash::make($request->password);
        $user->save();

        Cache::forget('otp_' . $request->email);

        return response()->json([
            'message' => 'รีเซ็ตรหัสผ่านสำเร็จ',
        ]);
    }
}
