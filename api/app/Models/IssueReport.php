<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class IssueReport extends Model
{
    use HasFactory;
    protected $table = 'issue_reports';
    protected $guarded = [];
    protected $keyType = 'string';
    public $incrementing = false;
}
