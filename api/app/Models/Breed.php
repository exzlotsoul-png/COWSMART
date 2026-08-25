<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class Breed extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'breeds';
    protected $primaryKey = 'breed_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'B';
    protected int $idPadLength = 3;
}
