<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FinancialRecord extends Model
{
    use HasFactory;
    protected $table = 'financial_records';
    protected $primaryKey = 'financial_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
