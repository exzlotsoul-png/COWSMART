<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class HealthAppointment extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'health_appointments';
    protected $primaryKey = 'health_appointment_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'HA';
    protected int $idPadLength = 4;
}
