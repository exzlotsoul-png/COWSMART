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
        $feedInventory = new FeedInventory($data);
        if ($request->has('created_at')) {
            $feedInventory->created_at = $request->created_at;
        }
        $feedInventory->save();

        return response()->json($feedInventory, 201);
    }

    public function show($id)
    {
        return response()->json(FeedInventory::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $feedInventory = FeedInventory::findOrFail($id);
        $feedInventory->fill($request->all());
        if ($request->has('created_at')) {
            $feedInventory->created_at = $request->created_at;
        }
        $feedInventory->save();

        return response()->json($feedInventory);
    }

    public function destroy($id)
    {
        FeedInventory::destroy($id);
        return response()->json(null, 204);
    }
}
