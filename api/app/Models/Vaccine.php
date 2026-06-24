<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Vaccine extends Model
{
    use HasFactory;
    protected $table = 'vaccines';
    protected $primaryKey = 'vaccine_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
