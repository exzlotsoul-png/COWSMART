<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ChatHistory;
use Illuminate\Http\Request;

class ChatHistoryController extends Controller
{
    public function index()
    {
        return response()->json(ChatHistory::all());
    }

    public function store(Request $request)
    {
        $data = ChatHistory::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(ChatHistory::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = ChatHistory::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        ChatHistory::destroy($id);
        return response()->json(null, 204);
    }
}
