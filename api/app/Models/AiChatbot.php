<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AiChatbot extends Model
{
    use HasFactory;

    protected $table = 'ai_chatbot';

    protected $fillable = [
        'category',
        'title',
        'keywords',
        'prompt',
        'answer',
        'suggested_actions',
        'is_active',
        'sort_order',
    ];

    protected $casts = [
        'suggested_actions' => 'array',
        'is_active' => 'boolean',
        'sort_order' => 'integer',
    ];
}
