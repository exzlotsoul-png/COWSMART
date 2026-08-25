<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class ChatHistory extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'chat_histories';
    protected $primaryKey = 'id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'CH';
    protected int $idPadLength = 4;
}
