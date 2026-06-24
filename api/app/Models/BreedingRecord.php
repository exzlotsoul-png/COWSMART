<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BreedingRecord extends Model
{
    use HasFactory;
    protected $table = 'breeding_records';
    protected $primaryKey = 'breeding_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
