<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\IssueReport;
use Illuminate\Http\Request;

class IssueReportController extends Controller
{
    public function index()
    {
        return response()->json(IssueReport::all());
    }

    public function store(Request $request)
    {
        $data = IssueReport::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(IssueReport::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = IssueReport::findOrFail($id);
        $oldStatus = (int) $data->status;
        
        $data->update($request->all());
        
        $newStatus = (int) $data->status;

        if ($oldStatus !== 1 && $newStatus === 1 && !empty($data->email)) {
            \App\Models\Notification::create([
                'email' => $data->email,
                'title' => 'รายงานการใช้งานได้รับการแก้ไขแล้ว',
                'message' => 'ปัญหา/ข้อเสนอแนะเรื่อง "' . $data->topic . '" ของคุณได้รับการดำเนินการเรียบร้อยแล้ว ขอบคุณที่ร่วมพัฒนาแอปพลิเคชันของเรา',
                'notify_datetime' => now(),
                'is_read' => 0
            ]);
        }

        return response()->json($data);
    }

    public function destroy($id)
    {
        IssueReport::destroy($id);
        return response()->json(null, 204);
    }
}
