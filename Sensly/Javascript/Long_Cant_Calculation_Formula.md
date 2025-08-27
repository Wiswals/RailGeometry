# Long Twist Calculation Formula

## Overview
Calculate Long Twist cant at target chainage (calc_chainage - long_twist_chord) using gradient-corrected prism data from Long Twist prism and Central prism positions.

## Input Parameters
- **calc_chainage** - Target chainage for calculation
- **long_twist_chord** - Long twist chord length
- **long_twist_LR_chainage, long_twist_RR_chainage** - Long twist prism chainages
- **central_LR_chainage, central_RR_chainage** - Central prism chainages
- **long_twist_LR_z, long_twist_RR_z** - Long twist prism elevations
- **central_LR_z, central_RR_z** - Central prism elevations
- **central_cant** - Central cant value (mm) for twist calculation
- **long_twist_baseline** - Baseline long twist value for deviation calculation
- **long_twist_absolute** - Absolute reference long twist value

## Prism Location Diagrams

### Target Chainage Behind Long Twist Position

```
Direction of Travel →

                        LT                                  CL
                        ↓                                   ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LT_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─     ← Left Rail
                 ▲      │                                   │
twist_calc_chainage     │                                 │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LT_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_RR]─ ─ ─ ─ ─     ← Right Rail
                        ↑                                 ↑
                        LT                                CL

twist_calc_chainage behind LT position (uses LT→CL gradient)
```

### Target Chainage Between Long Twist and Central Position

```
Direction of Travel →

                        LT                                  CL
                        ↓                                   ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LT_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─     ← Left Rail
                        │        ▲                          │
                        │    twist_calc_chainage          │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LT_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_RR]─ ─ ─ ─ ─     ← Right Rail
                        ↑                                 ↑
                        LT                                CL

twist_calc_chainage between LT and CL (uses LT→CL gradient)
```

### Position-Corrected Cant Locations (Target Chainage Behind Long Twist Position)

```
Direction of Travel →

─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LT_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─     ← Left Rail
                 │                                         │  
 long_twist_cant │                            central_cant │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LT_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_RR]─ ─ ─ ─ ─     ← Right Rail
                 ▲ . . . . . . . . . . . . . . . . . . . . ▲
                                   long_twist

long_twist_cant calculated at twist_calc_chainage
central_cant calculated at calc_chainage
long_twist = central_cant - long_twist_cant
```

## Calculation Steps

### Step 1: Calculate Long Twist Target Chainage
```
long_twist_calc_chainage = calc_chainage - long_twist_chord
```

### Step 2: Calculate Rail Gradients (Always LT→CL)

#### Left Rail Gradient
```
LR_gradient = (central_LR_z - long_twist_LR_z) / (central_LR_chainage - long_twist_LR_chainage)
```

#### Right Rail Gradient
```
RR_gradient = (central_RR_z - long_twist_RR_z) / (central_RR_chainage - long_twist_RR_chainage)
```

### Step 3: Calculate Elevations at Long Twist Target Chainage
```
LR_elevation_at_long_twist_calc_chainage = long_twist_LR_z + LR_gradient × (long_twist_calc_chainage - long_twist_LR_chainage)
RR_elevation_at_long_twist_calc_chainage = long_twist_RR_z + RR_gradient × (long_twist_calc_chainage - long_twist_RR_chainage)
```

### Step 4: Calculate Long Twist Cant
```
long_twist_cant = (RR_elevation_at_long_twist_calc_chainage - LR_elevation_at_long_twist_calc_chainage) * 1000
```

### Step 5: Calculate Long Twist
```
long_twist = central_cant - long_twist_cant
```

### Step 6: Calculate Deviation and Absolute Values
```
long_twist_deviation = long_twist - long_twist_baseline
long_twist_absolute_value = long_twist_absolute + long_twist_deviation
```

## Output
- **long_twist** (double) - Long twist in mm (central cant - long twist cant)
- **long_twist_deviation** (double) - Long twist deviation from baseline in mm
- **long_twist_absolute_value** (double) - Absolute long twist value in mm
- **Note**: Input coordinates assumed to be in meters, result scaled to millimeters

## JavaScript Implementation

### Long Twist Deviation Calculation
```javascript
// Calculate long twist target chainage
let long_twist_calc_chainage = calc_chainage - long_twist_chord;

// Calculate gradients (always LT→CL)
let LR_grad = (central_LR_z - long_twist_LR_z) / (central_LR_chainage - long_twist_LR_chainage);
let RR_grad = (central_RR_z - long_twist_RR_z) / (central_RR_chainage - long_twist_RR_chainage);

// Calculate elevations at long twist target chainage
let LR_elev = long_twist_LR_z + LR_grad * (long_twist_calc_chainage - long_twist_LR_chainage);
let RR_elev = long_twist_RR_z + RR_grad * (long_twist_calc_chainage - long_twist_RR_chainage);

// Long twist calculation and deviation from baseline
(central_cant - ((RR_elev - LR_elev) * 1000)) - long_twist_baseline;
```

### Long Twist Calculation
```javascript
// Absolute long twist value
long_twist_absolute + (long_twist_deviation)
```