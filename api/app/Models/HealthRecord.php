<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class HealthRecord extends Model
{
    use HasFactory;
    protected $table = 'health_records';
    protected $primaryKey = 'health_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
