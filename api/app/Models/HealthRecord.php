<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class HealthRecord extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'health_records';
    protected $primaryKey = 'health_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'HR';
    protected int $idPadLength = 4;

    public function medicines()
    {
        return $this->belongsToMany(Medicine::class, 'health_record_medicines', 'health_record_id', 'medicine_id');
    }

    public function vaccines()
    {
        return $this->belongsToMany(Vaccine::class, 'health_record_vaccines', 'health_record_id', 'vaccine_id');
    }
}
