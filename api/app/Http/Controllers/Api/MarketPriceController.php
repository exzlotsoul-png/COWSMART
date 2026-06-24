<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketPrice;
use Illuminate\Http\Request;

class MarketPriceController extends Controller
{
    public function index(Request $request)
    {
        $animalType = $request->query('animal_type', 'cattle');

        // Return latest price per category
        $prices = MarketPrice::where('animal_type', $animalType)
            ->orderByDesc('effective_date')
            ->get()
            ->unique('category')
            ->values();

        // Also return the single latest overall price for convenience
        $latest = MarketPrice::where('animal_type', $animalType)
            ->orderByDesc('effective_date')
            ->first();

        return response()->json([
            'latest' => $latest,
            'by_category' => $prices,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'price_per_kg' => 'required|numeric|min:0',
            'effective_date' => 'required|date',
        ]);

        $data = $request->all();
        if (empty($data['animal_type'])) {
            $data['animal_type'] = 'cattle';
        }

        $price = MarketPrice::create($data);
        return response()->json($price, 201);
    }

    public function show($id)
    {
        return response()->json(MarketPrice::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $price = MarketPrice::findOrFail($id);
        $price->update($request->all());
        return response()->json($price);
    }

    public function destroy($id)
    {
        MarketPrice::destroy($id);
        return response()->json(null, 204);
    }
}
