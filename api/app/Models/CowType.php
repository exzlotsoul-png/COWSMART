<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CowType extends Model
{
    use HasFactory;
    protected $table = 'cow_types';
    protected $primaryKey = 'cow_type_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
