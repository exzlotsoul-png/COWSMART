<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FeedInventory extends Model
{
    use HasFactory;
    protected $table = 'feed_inventories';
    protected $primaryKey = 'feed_inventory_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];
}
