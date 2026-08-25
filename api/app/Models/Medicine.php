<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class Medicine extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'medicines';
    protected $primaryKey = 'medicine_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'MED';
    protected int $idPadLength = 3;
}
