<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class CheckupType extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'checkup_types';
    protected $primaryKey = 'checkup_types_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'CT';
    protected int $idPadLength = 2;
}
