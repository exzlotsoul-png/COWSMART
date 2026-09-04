<?php

namespace App\Traits;

use Illuminate\Support\Facades\DB;

trait HasSequentialId
{
    protected static function bootHasSequentialId(): void
    {
        static::creating(function ($model) {
            $keyName = $model->getKeyName();
            $table = $model->getTable();
            if (empty($model->{$keyName}) || DB::table($table)->where($keyName, $model->{$keyName})->exists()) {
                $prefix = $model->idPrefix ?? 'ID';
                $padLength = $model->idPadLength ?? 3;

                $allIds = DB::table($table)->pluck($keyName);
                $maxNum = 0;
                foreach ($allIds as $id) {
                    if (preg_match('/(\d+)/', (string)$id, $matches)) {
                        $num = (int)$matches[1];
                        if ($num > $maxNum) {
                            $maxNum = $num;
                        }
                    }
                }

                $model->{$keyName} = $prefix . str_pad($maxNum + 1, $padLength, '0', STR_PAD_LEFT);
            }
        });
    }
}
