# Power Query: Table_TrackData

## Purpose
Loads and formats raw prism survey data from Excel table for use in prism assignment calculations.

## Dependencies
Requires Excel table named `Table_TrackData` with these columns:
- **Prism ID** - Unique identifier for each prism
- **X** - Easting coordinate
- **Y** - Northing coordinate  
- **Z** - Elevation
- **Track Chainage** - Position along track alignment
- **Track Side** - Rail designation (LR/RR)
- **Offset X** - X adjustment from measured position
- **Offset Y** - Y adjustment from measured position
- **Offset Z** - Z adjustment from measured position

## Output
Clean typed table ready for prism selection algorithms.

## M Code
```m
let
    // Load prism data from Excel table
    Source = Excel.CurrentWorkbook(){[Name="Table_TrackData"]}[Content],
    
    // Apply proper data types for calculations
    TypedData = Table.TransformColumnTypes(Source, {
        {"Prism ID", type text}, 
        {"X", type number}, 
        {"Y", type number}, 
        {"Z", type number}, 
        {"Track Chainage", type number}, 
        {"Track Side", type text}, 
        {"Offset X", type number}, 
        {"Offset Y", type number}, 
        {"Offset Z", type number}
    })
in
    TypedData
```

## Notes
- Offsets can be used for prism position adjustments if needed
- Track Side should use "LR" for left rail, "RR" for right rail
- Prism ID must be unique across all prisms