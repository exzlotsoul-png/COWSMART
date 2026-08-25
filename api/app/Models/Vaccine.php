<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class Vaccine extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'vaccines';
    protected $primaryKey = 'vaccine_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'VAC';
    protected int $idPadLength = 3;
}
