<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MarketPrice extends Model
{
    use HasFactory;
    protected $table = 'market_prices';
    protected $guarded = [];

    protected $casts = [
        'effective_date' => 'date',
        'price_per_kg' => 'float',
    ];
}
