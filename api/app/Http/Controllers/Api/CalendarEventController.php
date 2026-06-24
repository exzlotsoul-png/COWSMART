<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CalendarEvent;
use Illuminate\Http\Request;

class CalendarEventController extends Controller
{
    public function index(Request $request)
    {
        $query = CalendarEvent::query();
        if ($request->has('farm_id')) {
            $query->where('farm_id', $request->farm_id);
        }
        return response()->json($query->orderBy('event_datetime')->get());
    }

    public function store(Request $request)
    {
        $data = $request->all();
        if (empty($data['calendar_event_id'])) {
            $data['calendar_event_id'] = 'CE-' . substr(md5(uniqid(mt_rand(), true)), 0, 7);
        }
        $event = CalendarEvent::create($data);
        return response()->json($event, 201);
    }

    public function show($id)
    {
        return response()->json(CalendarEvent::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = CalendarEvent::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        CalendarEvent::destroy($id);
        return response()->json(null, 204);
    }
}
