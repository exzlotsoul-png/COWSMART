<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ReportTopic;
use Illuminate\Http\Request;

class ReportTopicController extends Controller
{
    public function index()
    {
        return response()->json(ReportTopic::orderBy('id')->get());
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $id = $request->input('id');
        if (!$id) {
            $last = ReportTopic::orderBy('id', 'desc')->first();
            if ($last && preg_match('/TOPIC(\d+)/i', $last->id, $matches)) {
                $nextNum = intval($matches[1]) + 1;
                $id = 'TOPIC' . str_pad($nextNum, 3, '0', STR_PAD_LEFT);
            } else {
                $id = 'TOPIC001';
            }
        }

        $topic = ReportTopic::create([
            'id' => $id,
            'name' => $request->input('name'),
        ]);

        return response()->json($topic, 201);
    }

    public function show($id)
    {
        return response()->json(ReportTopic::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $topic = ReportTopic::findOrFail($id);
        $topic->update($request->only('name'));

        return response()->json($topic);
    }

    public function destroy($id)
    {
        ReportTopic::destroy($id);
        return response()->json(null, 204);
    }
}
