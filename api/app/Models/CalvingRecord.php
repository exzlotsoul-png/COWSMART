<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CalvingRecord extends Model
{
    use HasFactory;
    protected $table = 'calving_records';
    protected $primaryKey = 'calving_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
