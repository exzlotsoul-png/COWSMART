<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Cow extends Model
{
    use HasFactory;
    protected $table = 'cows';
    protected $primaryKey = 'cow_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected $appends = ['image_full_url', 'latest_disease_name'];

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

    public function getLatestDiseaseNameAttribute(): ?string
    {
        $latestRecord = \Illuminate\Support\Facades\DB::table('health_records')
            ->join('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
            ->where('health_records.cow_id', $this->cow_id)
            ->whereNotNull('health_records.disease_id')
            ->orderBy('health_records.record_date', 'desc')
            ->orderBy('health_records.created_at', 'desc')
            ->select('diseases.name')
            ->first();

        return $latestRecord ? $latestRecord->name : null;
    }

    public function farm()
    {
        return $this->belongsTo(Farm::class, 'farm_id', 'farm_id');
    }

    public function healthRecords()
    {
        return $this->hasMany(HealthRecord::class, 'cow_id', 'cow_id');
    }

    public function growthRecords()
    {
        return $this->hasMany(GrowthRecord::class, 'cow_id', 'cow_id');
    }

    public function breedingRecords()
    {
        return $this->hasMany(BreedingRecord::class, 'cow_id', 'cow_id');
    }

    public function cullingRecord()
    {
        return $this->hasOne(CullingRecord::class, 'cow_id', 'cow_id');
    }

    public function feedingRecords()
    {
        return $this->hasMany(FeedingRecord::class, 'cow_id', 'cow_id');
    }
}
