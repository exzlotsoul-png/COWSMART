<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class CowType extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'cow_types';
    protected $primaryKey = 'cow_type_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'T';
    protected int $idPadLength = 3;
}
