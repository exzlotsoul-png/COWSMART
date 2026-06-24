<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CalendarEvent extends Model
{
    use HasFactory;
    protected $table = 'calendar_events';
    protected $primaryKey = 'calendar_event_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
