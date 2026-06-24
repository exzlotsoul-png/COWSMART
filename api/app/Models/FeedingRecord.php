<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FeedingRecord extends Model
{
    use HasFactory;
    protected $table = 'feeding_records';
    protected $primaryKey = 'feeding_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
