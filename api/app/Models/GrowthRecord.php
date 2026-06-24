<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class GrowthRecord extends Model
{
    use HasFactory;
    protected $table = 'growth_records';
    protected $primaryKey = 'growth_records_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
