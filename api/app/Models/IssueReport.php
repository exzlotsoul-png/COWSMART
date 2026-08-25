<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\HasSequentialId;

class IssueReport extends Model
{
    use HasFactory, HasSequentialId;
    protected $table = 'issue_reports';
    protected $guarded = [];
    protected $keyType = 'string';
    public $incrementing = false;

    protected string $idPrefix = 'REP';
    protected int $idPadLength = 3;
}
