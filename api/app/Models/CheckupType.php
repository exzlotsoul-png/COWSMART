<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CheckupType extends Model
{
    use HasFactory;
    protected $table = 'checkup_types';
    protected $primaryKey = 'checkup_types_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
