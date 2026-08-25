<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class Disease extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'diseases';
    protected $primaryKey = 'disease_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'DIS';
    protected int $idPadLength = 3;
}
