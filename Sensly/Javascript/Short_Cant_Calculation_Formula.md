# Short Twist Calculation Formula

## Overview
Calculate Short Twist cant at target chainage (calc_chainage - short_twist_chord) using gradient-corrected prism data from Short Twist prism and Central prism positions.

## Input Parameters
- **calc_chainage** - Target chainage for calculation
- **short_twist_chord** - Short twist chord length
- **short_twist_LR_chainage, short_twist_RR_chainage** - Short twist prism chainages
- **central_LR_chainage, central_RR_chainage** - Central prism chainages
- **short_twist_LR_z, short_twist_RR_z** - Short twist prism elevations
- **central_LR_z, central_RR_z** - Central prism elevations
- **central_cant** - Central cant value (mm) for twist calculation
- **short_twist_baseline** - Baseline short twist value for deviation calculation
- **short_twist_absolute** - Absolute reference short twist value

## Prism Location Diagrams

### Target Chainage Behind Short Twist Position

```
Direction of Travel →

                                 ST                      CL
                                 ↓                       ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [ST_LR]─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─    ← Left Rail
                        ▲        │                       │
         twist_calc_chainage    │                       │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[ST_RR]─ ─ ─ ─ ─ ─ ─ ─ ─[CL_RR] ─ ─ ─ ─    ← Right Rail
                                ↑                       ↑
                                ST                      CL

twist_calc_chainage behind ST position (uses ST→CL gradient)
```

### Target Chainage Between Short Twist and Central Position

```
Direction of Travel →

                                 ST                      CL
                                 ↓                       ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [ST_LR]─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─    ← Left Rail
                                 │      ▲                │
                                │ twist_calc_chainage   │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[ST_RR]─ ─ ─ ─ ─ ─ ─ ─ ─[CL_RR] ─ ─ ─ ─    ← Right Rail
                                ↑                       ↑
                                ST                      CL

twist_calc_chainage between ST and CL (uses ST→CL gradient)
```

### Position-Corrected Cant Locations (Target Chainage Behind Short Twist Position)

```
Direction of Travel →

─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [ST_LR]─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─    ← Left Rail
                        │                             │  
       short_twist_cant │                central_cant │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[ST_RR]─ ─ ─ ─ ─ ─ ─ ─ ─[CL_RR] ─ ─ ─ ─    ← Right Rail
                        ▲ . . . . . . . . . . . . . . ▲
                                  short_twist

short_twist_cant calculated at twist_calc_chainage
central_cant calculated at calc_chainage
short_twist = central_cant - short_twist_cant
```

## Calculation Steps

### Step 1: Calculate Short Twist Target Chainage
```
short_twist_calc_chainage = calc_chainage - short_twist_chord
```

### Step 2: Calculate Rail Gradients (Always ST→CL)

#### Left Rail Gradient
```
LR_gradient = (central_LR_z - short_twist_LR_z) / (central_LR_chainage - short_twist_LR_chainage)
```

#### Right Rail Gradient
```
RR_gradient = (central_RR_z - short_twist_RR_z) / (central_RR_chainage - short_twist_RR_chainage)
```

### Step 3: Calculate Elevations at Short Twist Target Chainage
```
LR_elevation_at_short_twist_calc_chainage = short_twist_LR_z + LR_gradient × (short_twist_calc_chainage - short_twist_LR_chainage)
RR_elevation_at_short_twist_calc_chainage = short_twist_RR_z + RR_gradient × (short_twist_calc_chainage - short_twist_RR_chainage)
```

### Step 4: Calculate Short Twist Cant
```
short_twist_cant = (RR_elevation_at_short_twist_calc_chainage - LR_elevation_at_short_twist_calc_chainage) * 1000
```

### Step 5: Calculate Short Twist
```
short_twist = central_cant - short_twist_cant
```

### Step 6: Calculate Deviation and Absolute Values
```
short_twist_deviation = short_twist - short_twist_baseline
short_twist_absolute_value = short_twist_absolute + short_twist_deviation
```

## Output
- **short_twist** (double) - Short twist in mm (central cant - short twist cant)
- **short_twist_deviation** (double) - Short twist deviation from baseline in mm
- **short_twist_absolute_value** (double) - Absolute short twist value in mm
- **Note**: Input coordinates assumed to be in meters, result scaled to millimeters

## JavaScript Implementation

### Short Twist Deviation Calculation
```javascript
// Calculate short twist target chainage
let short_twist_calc_chainage = calc_chainage - short_twist_chord;

// Calculate gradients (always ST→CL)
let LR_grad = (central_LR_z - short_twist_LR_z) / (central_LR_chainage - short_twist_LR_chainage);
let RR_grad = (central_RR_z - short_twist_RR_z) / (central_RR_chainage - short_twist_RR_chainage);

// Calculate elevations at short twist target chainage
let LR_elev = short_twist_LR_z + LR_grad * (short_twist_calc_chainage - short_twist_LR_chainage);
let RR_elev = short_twist_RR_z + RR_grad * (short_twist_calc_chainage - short_twist_RR_chainage);

// Short twist calculation and deviation from baseline
(central_cant - ((RR_elev - LR_elev) * 1000)) - short_twist_baseline;
```

### Short Twist Calculation
```javascript
// Absolute short twist value
short_twist_absolute + (short_twist_deviation)
```