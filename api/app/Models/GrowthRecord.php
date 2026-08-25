<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class GrowthRecord extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'growth_records';
    protected $primaryKey = 'growth_records_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'G';
    protected int $idPadLength = 4;
}
