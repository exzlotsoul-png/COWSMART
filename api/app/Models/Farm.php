<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Farm extends Model
{
    use HasFactory;
    protected $table = 'farms';
    protected $primaryKey = 'farm_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected $appends = ['image_full_url'];

    public function getImageFullUrlAttribute(): ?string
    {
        if (!$this->image_url) {
            return null;
        }

        if (str_starts_with($this->image_url, 'http')) {
            return $this->image_url;
        }

        return url('api/storage/' . $this->image_url);
    }
}
