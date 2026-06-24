<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class HealthAppointment extends Model
{
    use HasFactory;
    protected $table = 'health_appointments';
    protected $primaryKey = 'health_appointment_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
