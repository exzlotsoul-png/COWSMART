<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReportTopic extends Model
{
    use HasFactory;
    protected $table = 'report_topics';
    protected $guarded = [];
    protected $keyType = 'string';
    public $incrementing = false;
}
