<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class BreedingRecord extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'breeding_records';
    protected $primaryKey = 'breeding_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'BR';
    protected int $idPadLength = 4;
}
