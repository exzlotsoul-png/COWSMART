<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class HealthRecord extends Model
{
    use HasFactory;
    protected $table = 'health_records';
    protected $primaryKey = 'health_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    public function medicines()
    {
        return $table = $this->belongsToMany(Medicine::class, 'health_record_medicines', 'health_record_id', 'medicine_id');
    }

    public function vaccines()
    {
        return $table = $this->belongsToMany(Vaccine::class, 'health_record_vaccines', 'health_record_id', 'vaccine_id');
    }
}
