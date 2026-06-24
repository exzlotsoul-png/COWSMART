<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FarmController extends Controller
{
    public function index()
    {
        $user = Auth::user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        return response()->json(Farm::where('email', $user->email)->get());
    }

    public function store(Request $request)
    {
        $user = Auth::user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        
        $data = $request->all();
        $data['email'] = $user->email;
        
        // Generate unique farm_id (max 10 chars)
        $data['farm_id'] = 'F-' . substr(md5(uniqid(mt_rand(), true)), 0, 8);
        
        $farm = Farm::create($data);
        return response()->json($farm, 201);
    }

    public function show($id)
    {
        $user = Auth::user();
        $farm = Farm::where('farm_id', $id)
                    ->where('email', $user->email)
                    ->firstOrFail();
                    
        return response()->json($farm);
    }

    public function update(Request $request, $id)
    {
        $user = Auth::user();
        $farm = Farm::where('farm_id', $id)
                    ->where('email', $user->email)
                    ->firstOrFail();
                    
        $farm->update($request->all());
        return response()->json($farm);
    }

    public function destroy($id)
    {
        $user = Auth::user();
        $farm = Farm::where('farm_id', $id)
                    ->where('email', $user->email)
                    ->firstOrFail();
                    
        $farm->delete();
        return response()->json(null, 204);
    }
}
