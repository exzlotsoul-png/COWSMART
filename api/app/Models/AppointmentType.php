<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class AppointmentType extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'appointment_types';
    protected $guarded = [];

    protected string $idPrefix = 'AT';
    protected int $idPadLength = 2;
}
