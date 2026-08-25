<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class FeedInventory extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'feed_inventories';
    protected $primaryKey = 'feed_inventory_id';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected string $idPrefix = 'FD';
    protected int $idPadLength = 4;
}
