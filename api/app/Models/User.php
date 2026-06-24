<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $table = 'users';
    protected $primaryKey = 'email';
    protected $keyType = 'string';
    public $incrementing = false;
    protected $guarded = [];

    protected $appends = ['avatar_full_url'];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    public function getAvatarUrlAttribute(): ?string
    {
        return $this->profile_image;
    }

    public function getAvatarFullUrlAttribute(): ?string
    {
        if (!$this->profile_image) {
            return null;
        }

        if (str_starts_with($this->profile_image, 'http')) {
            return $this->profile_image;
        }

        return url('api/storage/' . $this->profile_image);
    }
}
