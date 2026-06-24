<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Unit extends Model
{
    use HasFactory;

    protected $table = 'units';
    protected $primaryKey = 'unit_id';
    public $incrementing = true;
    protected $keyType = 'int';

    protected $fillable = [
        'name',
        'type',
        'abbreviation'
    ];
}
