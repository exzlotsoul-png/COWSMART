<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class Unit extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'units';
    protected $primaryKey = 'unit_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'U';
    protected int $idPadLength = 3;
}
