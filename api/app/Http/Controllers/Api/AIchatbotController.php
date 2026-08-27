<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiChatbot;
use App\Models\ChatHistory;
use App\Models\Cow;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Carbon\Carbon;

class AIchatbotController extends Controller
{
    /**
     * Admin: List all knowledge base items from ai_chatbot table
     */
    public function index(Request $request)
    {
        $query = AiChatbot::query();

        if ($request->filled('category') && $request->category !== 'all') {
            $query->where('category', $request->category);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('keywords', 'like', "%{$search}%")
                  ->orWhere('prompt', 'like', "%{$search}%")
                  ->orWhere('answer', 'like', "%{$search}%");
            });
        }

        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->is_active, FILTER_VALIDATE_BOOLEAN));
        }

        $items = $query->orderBy('sort_order', 'asc')
                       ->orderBy('id', 'asc')
                       ->get();

        $categories = AiChatbot::distinct()->pluck('category')->filter()->values();

        return response()->json([
            'success' => true,
            'data' => $items,
            'categories' => $categories,
        ]);
    }

    /**
     * Admin: Create new knowledge base item in ai_chatbot table
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'category' => 'required|string|max:100',
            'title' => 'required|string|max:255',
            'keywords' => 'nullable|string',
            'prompt' => 'required|string',
            'answer' => 'required|string',
            'suggested_actions' => 'nullable|array',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ]);

        $item = AiChatbot::create($validated);

        return response()->json([
            'success' => true,
            'message' => 'บันทึกชุดข้อมูลคำถาม-คำตอบ AI สำเร็จ',
            'data' => $item,
        ], 201);
    }

    /**
     * Admin: Show a single knowledge item
     */
    public function show($id)
    {
        $item = AiChatbot::findOrFail($id);
        return response()->json([
            'success' => true,
            'data' => $item,
        ]);
    }

    /**
     * Admin: Update knowledge item
     */
    public function update(Request $request, $id)
    {
        $item = AiChatbot::findOrFail($id);

        $validated = $request->validate([
            'category' => 'sometimes|required|string|max:100',
            'title' => 'sometimes|required|string|max:255',
            'keywords' => 'nullable|string',
            'prompt' => 'sometimes|required|string',
            'answer' => 'sometimes|required|string',
            'suggested_actions' => 'nullable|array',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ]);

        $item->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'อัปเดตชุดข้อมูล AI สำเร็จ',
            'data' => $item,
        ]);
    }

    /**
     * Admin: Delete knowledge item
     */
    public function destroy($id)
    {
        $item = AiChatbot::findOrFail($id);
        $item->delete();

        return response()->json([
            'success' => true,
            'message' => 'ลบข้อมูลสำเร็จ',
        ]);
    }

    /**
     * Mobile / App: Get suggested topics dynamically from ai_chatbot Database table
     */
    public function getSuggestedTopics()
    {
        $knowledges = AiChatbot::where('is_active', true)
            ->orderBy('sort_order', 'asc')
            ->orderBy('id', 'asc')
            ->get();

        $grouped = $knowledges->groupBy('category');

        $result = [];
        foreach ($grouped as $category => $items) {
            $result[] = [
                'category' => $category,
                'items' => $items->map(function ($item) {
                    return [
                        'id' => $item->id,
                        'title' => $item->title,
                        'prompt' => $item->prompt,
                    ];
                })->values(),
            ];
        }

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
    }

    /**
     * Mobile / App: Consult AI Doctor with DB Knowledge Matching + Cow Context (No Emojis)
     */
    public function consult(Request $request)
    {
        $request->validate([
            'message' => 'required|string|max:1000',
            'cow_id' => 'nullable|string',
        ]);

        $userMessage = trim($request->input('message'));
        $cowId = $request->input('cow_id');
        $userEmail = $request->user() ? $request->user()->email : ($request->input('email') ?? 'farmer@cowsmart.com');

        $cowContextText = '';
        $cowInfo = null;

        if ($cowId) {
            $cow = Cow::with(['healthRecords' => function ($q) {
                $q->latest()->take(3);
            }])->find($cowId);

            if ($cow) {
                $cowIdVal = $cow->cow_id ?? $cow->id;
                $tagVal = $cow->tag_number ?? $cow->ear_tag ?? $cow->tag_id ?? $cowIdVal;
                $weightVal = $cow->latest_weight ?? $cow->weight;

                $cowInfo = [
                    'id' => $cowIdVal,
                    'tag_number' => $tagVal,
                    'name' => $cow->name ?? $tagVal,
                    'breed' => $cow->breed ?? 'ไม่ระบุ',
                    'sex' => ($cow->sex === 'male' || $cow->gender === 'male') ? 'เพศผู้' : 'เพศเมีย',
                    'weight' => $weightVal ? "{$weightVal} กก." : 'ไม่ระบุ',
                ];

                $cowContextText = "ข้อมูลวัวที่กำลังปรึกษา: ชื่อ {$cowInfo['name']} (รหัส {$cowInfo['tag_number']}), พันธุ์ {$cowInfo['breed']}, เพศ {$cowInfo['sex']}, น้ำหนัก {$cowInfo['weight']}";
                if ($cow->healthRecords && $cow->healthRecords->isNotEmpty()) {
                    $recentHealth = $cow->healthRecords->map(function ($r) {
                        $date = $r->record_date ?? $r->created_at;
                        $diag = $r->diagnosis ?? $r->notes ?? $r->note ?? $r->disease_id ?? 'ตรวจสุขภาพ';
                        return "{$date}: {$diag}";
                    })->implode(', ');
                    $cowContextText .= " | ประวัติการรักษาก่อนหน้า: {$recentHealth}";
                }
            }
        }

        // 1. Search ai_chatbot table in Database
        $matchedKnowledge = $this->matchKnowledgeFromDatabase($userMessage);
        $suggestedActions = [
            ['action' => 'create_appointment', 'label' => 'สร้างนัดหมายตรวจสุขภาพ'],
            ['action' => 'record_health', 'label' => 'บันทึกการรักษา'],
        ];

        $aiResponse = null;

        if ($matchedKnowledge) {
            $cowPrefix = $cowInfo ? "สำหรับ {$cowInfo['name']} (พันธุ์ {$cowInfo['breed']})\n\n" : "";
            $aiResponse = $cowPrefix . $matchedKnowledge->answer;
            if (!empty($matchedKnowledge->suggested_actions)) {
                $actionList = [];
                foreach ($matchedKnowledge->suggested_actions as $actKey) {
                    if ($actKey === 'create_appointment') {
                        $actionList[] = ['action' => 'create_appointment', 'label' => 'สร้างนัดหมายตรวจสุขภาพ'];
                    } elseif ($actKey === 'record_health') {
                        $actionList[] = ['action' => 'record_health', 'label' => 'บันทึกการรักษา'];
                    }
                }
                if (!empty($actionList)) {
                    $suggestedActions = $actionList;
                }
            }
        }

        // 2. Fallback to Gemini API if configured
        if (!$aiResponse) {
            $geminiApiKey = config('services.gemini.api_key') ?: env('GEMINI_API_KEY');
            if (!empty($geminiApiKey)) {
                $aiResponse = $this->callGeminiApi($userMessage, $cowContextText, $geminiApiKey);
            }
        }

        // 3. Fallback when no match found in database and no external AI
        if (!$aiResponse) {
            $cowPrefix = $cowInfo ? "สำหรับ {$cowInfo['name']} (พันธุ์ {$cowInfo['breed']})\n\n" : "";
            $aiResponse = $cowPrefix . "ขออภัยครับ ระบบยังไม่พบข้อมูลคำตอบสำหรับคำถามหรืออาการดังกล่าวในฐานข้อมูล\n\n"
                . "คำแนะนำ: กรุณาติดต่อปรึกษาสัตวแพทย์ในพื้นที่เพื่อตรวจดูอาการโดยตรง หรือเลือกแตะหัวข้ออาการที่แนะนำจากรายการด้านล่างครับ";
        }

        // Save into ChatHistory
        $chatRecord = null;
        try {
            $chatRecord = ChatHistory::create([
                'email' => $userEmail,
                'user_message' => $userMessage,
                'ai_response' => $aiResponse,
                'chat_datetime' => Carbon::now(),
            ]);
        } catch (\Exception $e) {
            Log::warning("Could not persist chat history: " . $e->getMessage());
        }

        $chatId = $chatRecord ? $chatRecord->id : 'CH0001';

        return response()->json([
            'success' => true,
            'chat_id' => $chatId,
            'user_message' => $userMessage,
            'ai_response' => $aiResponse,
            'cow' => $cowInfo,
            'timestamp' => Carbon::now()->toISOString(),
            'suggested_actions' => $suggestedActions,
        ]);
    }

    /**
     * Match user message against ai_chatbot Database table
     */
    private function matchKnowledgeFromDatabase(string $message): ?AiChatbot
    {
        $cleanMsg = mb_strtolower(trim($message));

        // Ignore DB match if user is specifically asking about other animals
        $otherAnimals = ['หมู', 'สุกร', 'ไก่', 'เป็ด', 'สุนัข', 'หมา', 'แมว', 'ม้า', 'แพะ', 'แกะ', 'ปลา', 'กุ้ง'];
        $cattleKeywords = ['วัว', 'ลูกวัว', 'แม่วัว'];
        
        $mentionsOtherAnimal = false;
        foreach ($otherAnimals as $animal) {
            if (str_contains($cleanMsg, $animal)) {
                $mentionsOtherAnimal = true;
                break;
            }
        }

        $mentionsCattle = false;
        foreach ($cattleKeywords as $cattle) {
            if (str_contains($cleanMsg, $cattle)) {
                $mentionsCattle = true;
                break;
            }
        }

        if ($mentionsOtherAnimal && !$mentionsCattle) {
            return null; // Skip DB match so guardrails can refuse
        }

        // 1. Direct prompt or title match
        $directMatch = AiChatbot::where('is_active', true)
            ->where(function ($q) use ($cleanMsg) {
                $q->whereRaw('LOWER(prompt) = ?', [$cleanMsg])
                  ->orWhereRaw('LOWER(title) = ?', [$cleanMsg]);
            })->first();

        if ($directMatch) {
            return $directMatch;
        }

        // 2. Keyword matching from all active records
        $allActive = AiChatbot::where('is_active', true)
            ->orderBy('sort_order', 'asc')
            ->get();

        foreach ($allActive as $item) {
            if (!empty($item->keywords)) {
                $kwList = array_map('trim', explode(',', mb_strtolower($item->keywords)));
                foreach ($kwList as $kw) {
                    if (!empty($kw) && str_contains($cleanMsg, $kw)) {
                        return $item;
                    }
                }
            }

            if (!empty($item->title) && str_contains($cleanMsg, mb_strtolower($item->title))) {
                return $item;
            }
        }

        return null;
    }

    /**
     * Call Google Gemini API without emojis
     */
    private function callGeminiApi(string $prompt, string $cowContext, string $apiKey): ?string
    {
        try {
            $systemInstruction = "คุณคือ 'หมอวัว CowSmart' สัตวแพทย์ผู้เชี่ยวชาญด้านสุขภาพและการดูแล 'วัว' ประจำฟาร์มเท่านั้น\n\n"
                . "กฎเหล็กและแนวทางการตอบ:\n"
                . "1. ให้ใช้คำว่า 'วัว' เสมอ ห้ามใช้คำว่า 'โค' หรือ 'กระบือ'\n"
                . "2. ตอบเฉพาะเรื่องที่เกี่ยวกับ 'วัว' เท่านั้น (สุขภาพ, อาการป่วย, การรักษา, วัคซีน/ยา, อาหาร, การจัดการฟาร์ม)\n"
                . "3. หากผู้ใช้ถามเรื่องสัตว์ชนิดอื่น (เช่น หมู, ไก่, เป็ด, สุนัข, แมว, ม้า, แพะ ฯลฯ) หรือเรื่องนอกเหนือจากวัว ให้ปฏิเสธอย่างสุภาพทันทีว่าตอบได้เฉพาะเรื่องวัวเท่านั้น\n"
                . "4. ห้ามใส่อีโมจิในคำตอบ\n"
                . "5. **ตอบแบบกระชับ ตรงประเด็น และรวดเร็ว**: ไม่ต้องเกริ่นยาว สรุปเนื้อหาสำคัญเป็นข้อๆ สั้นๆ ให้อ่านเข้าใจง่ายและนำไปปฏิบัติได้ทันที (ความยาวประมาณ 3-5 บรรทัดหรือข้อย่อยสั้นๆ ไม่เกิน 150-200 คำ)\n"
                . "6. หากเป็นอาการป่วยรุนแรง ให้แนะนำให้ติดต่อสัตวแพทย์ในพื้นที่ทันที";

            if (!empty($cowContext)) {
                $systemInstruction .= "\n\n[บริบทวัวที่กำลังปรึกษา: {$cowContext}]";
            }

            // Verified active high-speed models
            $models = ['gemini-3.5-flash', 'gemini-3.6-flash', 'gemini-3.7-flash'];

            foreach ($models as $model) {
                $response = Http::timeout(20)->post("https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}", [
                    'system_instruction' => [
                        'parts' => [['text' => $systemInstruction]]
                    ],
                    'contents' => [
                        [
                            'role' => 'user',
                            'parts' => [['text' => $prompt]]
                        ]
                    ],
                    'generationConfig' => [
                        'temperature' => 0.2,
                        'maxOutputTokens' => 1000,
                    ]
                ]);

                if ($response->successful()) {
                    $data = $response->json();
                    $text = $data['candidates'][0]['content']['parts'][0]['text'] ?? null;
                    if (!empty($text)) {
                        return trim($text);
                    }
                } else {
                    Log::warning("Gemini API ({$model}) failed with status {$response->status()}: " . $response->body());
                }
            }
        } catch (\Exception $e) {
            Log::error("Gemini API call exception: " . $e->getMessage());
        }
        return null;
    }
}
