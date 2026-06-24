<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Breed extends Model
{
    use HasFactory;
    protected $table = 'breeds';
    protected $primaryKey = 'breed_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
