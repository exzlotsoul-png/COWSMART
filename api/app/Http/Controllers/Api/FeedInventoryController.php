<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FeedInventory;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class FeedInventoryController extends Controller
{
    public function index(Request $request)
    {
        $query = FeedInventory::query();
        
        if ($request->has('farm_id')) {
            $query->where('farm_id', $request->farm_id);
        }
        
        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $data = $request->all();
        // ID format: F-XXXXXX (1+1+6 = 8 chars, within 10 char limit)
        $data['feed_inventory_id'] = 'F-' . strtoupper(Str::random(6));
        
        $feedInventory = FeedInventory::create($data);
        return response()->json($feedInventory, 201);
    }

    public function show($id)
    {
        return response()->json(FeedInventory::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $feedInventory = FeedInventory::findOrFail($id);
        $feedInventory->update($request->all());
        return response()->json($feedInventory);
    }

    public function destroy($id)
    {
        FeedInventory::destroy($id);
        return response()->json(null, 204);
    }
}
