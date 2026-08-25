<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class CullingRecord extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'culling_records';
    protected $primaryKey = 'culling_record_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'CUL';
    protected int $idPadLength = 4;

    public function cow()
    {
        return $this->belongsTo(Cow::class, 'cow_id', 'cow_id');
    }
}
