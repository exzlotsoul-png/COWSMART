<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class FinancialRecord extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'financial_records';
    protected $primaryKey = 'financial_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'FR';
    protected int $idPadLength = 4;
}
