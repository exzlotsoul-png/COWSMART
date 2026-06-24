<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Medicine extends Model
{
    use HasFactory;
    protected $table = 'medicines';
    protected $primaryKey = 'medicine_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
