<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    use HasFactory;

    protected $table = 'settings';
    protected $primaryKey = 'setting_id';
    public $incrementing = true;
    protected $keyType = 'int';

    protected $fillable = [
        'setting_key',
        'setting_value',
        'description'
    ];
}
