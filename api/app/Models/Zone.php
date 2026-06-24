<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Zone extends Model
{
    use HasFactory;
    protected $table = 'zones';
    protected $primaryKey = 'zone_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    public function cows()
    {
        return $this->hasMany(Cow::class, 'zone_id', 'zone_id');
    }
}
