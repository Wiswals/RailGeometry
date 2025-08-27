# Power Query Function: GridToGeographic

## Purpose
Converts grid coordinates (Easting/Northing) to geographic coordinates (Latitude/Longitude) using Transverse Mercator projection parameters.

## Parameters
- **Easting** (number) - Grid easting coordinate
- **Northing** (number) - Grid northing coordinate  
- **SemiMajorAxis** (number) - Ellipsoid semi-major axis (e.g., 6378137 for GRS80)
- **FlatteningReciprocal** (number) - Flattening reciprocal (e.g., 298.257222101 for GRS80)
- **CentralMeridian** (number) - Central meridian in degrees
- **FalseEasting** (number) - False easting offset
- **FalseNorthing** (number) - False northing offset
- **ScaleFactor** (number) - Scale factor at central meridian

## Returns
Record with Latitude and Longitude in decimal degrees.

## M Code
```m
let
    Source = (Easting as number, Northing as number, SemiMajorAxis as number, FlatteningReciprocal as number, CentralMeridian as number, FalseEasting as number, FalseNorthing as number, ScaleFactor as number) =>
let
    // Calculate Flattening from Reciprocal
    Flattening = 1 / FlatteningReciprocal,

    // Calculate the Eccentricity
    e = Number.Sqrt(1 - Number.Power(1 - Flattening, 2)),
    
    // Square of Eccentricity
    e1sq = e * e / (1 - e * e),

    // Adjust Northing based on FalseNorthing
    NorthingAdjusted = Northing - FalseNorthing,
    
    // Calculate M from the adjusted Northing
    M = NorthingAdjusted / ScaleFactor,
    
    mu = M / (SemiMajorAxis * (1 - Number.Power(e, 2) / 4 - 3 * Number.Power(e, 4) / 64 - 5 * Number.Power(e, 6) / 256)),
    
    e1 = (1 - Number.Sqrt(1 - Number.Power(e, 2))) / (1 + Number.Sqrt(1 - Number.Power(e, 2))),
    
    J1 = 3 * e1 / 2 - 27 * Number.Power(e1, 3) / 32,
    J2 = 21 * Number.Power(e1, 2) / 16 - 55 * Number.Power(e1, 4) / 32,
    J3 = 151 * Number.Power(e1, 3) / 96,
    J4 = 1097 * Number.Power(e1, 4) / 512,
    
    fp = mu + J1 * Number.Sin(2 * mu) + J2 * Number.Sin(4 * mu) + J3 * Number.Sin(6 * mu) + J4 * Number.Sin(8 * mu),
    
    C1 = e1sq * Number.Power(Number.Cos(fp), 2),
    T1 = Number.Power(Number.Tan(fp), 2),
    R1 = SemiMajorAxis * (1 - Number.Power(e, 2)) / Number.Power(1 - Number.Power(e, 2) * Number.Power(Number.Sin(fp), 2), 1.5),
    N = SemiMajorAxis / Number.Sqrt(1 - Number.Power(e, 2) * Number.Power(Number.Sin(fp), 2)),
    
    D = (Easting - FalseEasting) / (N * ScaleFactor),
    
    // Calculate Latitude and Longitude
    Latitude0 = fp - (N * Number.Tan(fp) / R1) * (Number.Power(D, 2) / 2 - (5 + 3 * T1 + 10 * C1 - 4 * Number.Power(C1, 2) - 9 * e1sq) * Number.Power(D, 4) / 24 + (61 + 90 * T1 + 298 * C1 + 45 * Number.Power(T1, 2) - 252 * e1sq - 3 * Number.Power(C1, 2)) * Number.Power(D, 6) / 720),
    Latitude = Latitude0 * (180 / Number.PI),
    
    Longitude0 = (D - (1 + 2 * T1 + C1) * Number.Power(D, 3) / 6 + (5 - 2 * C1 + 28 * T1 - 3 * Number.Power(C1, 2) + 8 * e1sq + 24 * Number.Power(T1, 2)) * Number.Power(D, 5) / 120) / Number.Cos(fp),
    Longitude = CentralMeridian + Longitude0 * (180 / Number.PI)
in
    [Latitude = Latitude, Longitude = Longitude]
in
    Source
```

## Common Australian Coordinate Systems

### MGA (Map Grid of Australia) - GRS80 Ellipsoid

#### MGA Zone 49 (Western Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 111
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 50 (Western Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 117
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 51 (Northern Territory/South Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 123
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 52 (Northern Territory/South Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 129
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 53 (Northern Territory/Queensland)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 135
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 54 (Queensland/New South Wales)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 141
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 55 (Eastern Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 147
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### MGA Zone 56 (Tasmania/Victoria)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 153
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

### PCG94 (Perth Coastal Grid 1994) - GRS80 Ellipsoid
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 115.816666667
FalseEasting: 50000
FalseNorthing: 3800000
ScaleFactor: 0.99999906
```

### PCG2020 (Perth Coastal Grid 2020) - GRS80 Ellipsoid
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 115.883333333
FalseEasting: 50000
FalseNorthing: 3800000
ScaleFactor: 1.0000054
```

### ISG (Infrastructure Survey Grid) - GRS80 Ellipsoid
#### ISG Zone 1 (Perth Metro)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 115.975
FalseEasting: 50000
FalseNorthing: 3800000
ScaleFactor: 1.000013
```

#### ISG Zone 2 (Bunbury)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257222101
CentralMeridian: 115.638888889
FalseEasting: 50000
FalseNorthing: 3700000
ScaleFactor: 1.0000175
```

### WGS84 UTM (Global)
#### UTM Zone 50S (Western Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257223563
CentralMeridian: 117
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### UTM Zone 55S (Eastern Australia)
```
SemiMajorAxis: 6378137
FlatteningReciprocal: 298.257223563
CentralMeridian: 147
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

### Legacy AGD84 (Australian Geodetic Datum 1984) - ANS Ellipsoid
#### AMG Zone 50 (Western Australia)
```
SemiMajorAxis: 6378160
FlatteningReciprocal: 298.25
CentralMeridian: 117
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

#### AMG Zone 55 (Eastern Australia)
```
SemiMajorAxis: 6378160
FlatteningReciprocal: 298.25
CentralMeridian: 147
FalseEasting: 500000
FalseNorthing: 10000000
ScaleFactor: 0.9996
```

## Ellipsoid Reference

| Ellipsoid | Semi-Major Axis | Flattening Reciprocal | Usage |
|-----------|-----------------|----------------------|-------|
| GRS80 | 6378137 | 298.257222101 | MGA, PCG94, PCG2020, ISG |
| WGS84 | 6378137 | 298.257223563 | GPS, UTM |
| ANS (Australian National Spheroid) | 6378160 | 298.25 | Legacy AGD84/AMG |

## Usage
Create this as a custom function in Power Query, then call it with your coordinate system parameters to convert grid coordinates to latitude/longitude.