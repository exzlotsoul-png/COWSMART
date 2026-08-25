<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class Zone extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'zones';
    protected $primaryKey = 'zone_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'Z';
    protected int $idPadLength = 3;

    public function cows()
    {
        return $this->hasMany(Cow::class, 'zone_id', 'zone_id');
    }
}
