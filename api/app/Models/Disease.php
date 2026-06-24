<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Disease extends Model
{
    use HasFactory;
    protected $table = 'diseases';
    protected $primaryKey = 'disease_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
