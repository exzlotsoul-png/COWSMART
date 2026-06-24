<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CullingRecord extends Model
{
    use HasFactory;
    protected $table = 'culling_records';
    protected $primaryKey = 'culling_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
