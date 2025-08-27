# Gauge Calculation Formula

## Overview
Calculate gauge at target chainage (calc_chainage) as 3D distance between left and right rail positions using gradient-corrected prism data from Backward prism, Central prism, and Forward prism positions.

## Input Parameters
- **calc_chainage** - Target chainage for calculation
- **central_LR_chainage, central_RR_chainage** - Central prism chainages
- **backward_LR_chainage, backward_RR_chainage** - Backward prism chainages
- **forward_LR_chainage, forward_RR_chainage** - Forward prism chainages
- **central_LR_x, central_LR_y, central_LR_z** - Central left rail coordinates
- **central_RR_x, central_RR_y, central_RR_z** - Central right rail coordinates
- **backward_LR_x, backward_LR_y, backward_LR_z** - Backward left rail coordinates
- **backward_RR_x, backward_RR_y, backward_RR_z** - Backward right rail coordinates
- **forward_LR_x, forward_LR_y, forward_LR_z** - Forward left rail coordinates
- **forward_RR_x, forward_RR_y, forward_RR_z** - Forward right rail coordinates
- **gauge_baseline** - Baseline gauge value for deviation calculation
- **gauge_absolute** - Absolute reference gauge value

## Prism Location Diagrams

### Target Chainage Behind Central Position

```
Direction of Travel →

                    BW                             CL                         FW
                    ↓                              ↓                          ↓
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_LR]─ ─ ─ ─     ← Left Rail
                    │                       ▲      │                          │
                    │              calc_chainage     │                         │
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail
                    ↑                                ↑                        ↑
                    BW                               CL                       FW

calc_chainage between BW and CL (uses BW→CL gradient)
```

### Target Chainage Ahead of Central Position

```
Direction of Travel →

                    BW                             CL                         FW
                    ↓                              ↓                          ↓
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_LR]─ ─ ─ ─     ← Left Rail
                    │                              │        ▲                 │
                    │                                │    calc_chainage        │
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail
                    ↑                                ↑                        ↑
                    BW                               CL                       FW

calc_chainage between CL and FW (uses CL→FW gradient)
```

### Position-Corrected Gauge Location (Target chainage Behind Central Position)

```
Direction of Travel →

─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_LR]─ ─ ─ ─     ← Left Rail
                                            │                        
                                      gauge │                   
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail


gauge calculated at calc_chainage using interpolated rail positions
```

## Calculation Steps

### Step 1: Calculate Coordinates at Target Chainage

For each rail and coordinate (X, Y, Z), interpolate using appropriate gradient:

#### Left Rail Coordinates
```
if (calc_chainage < central_LR_chainage):
    LR_x = central_LR_x + ((central_LR_x - backward_LR_x) / (central_LR_chainage - backward_LR_chainage)) × (calc_chainage - central_LR_chainage)
    LR_y = central_LR_y + ((central_LR_y - backward_LR_y) / (central_LR_chainage - backward_LR_chainage)) × (calc_chainage - central_LR_chainage)
    LR_z = central_LR_z + ((central_LR_z - backward_LR_z) / (central_LR_chainage - backward_LR_chainage)) × (calc_chainage - central_LR_chainage)
else:
    LR_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) × (calc_chainage - central_LR_chainage)
    LR_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) × (calc_chainage - central_LR_chainage)
    LR_z = central_LR_z + ((forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)) × (calc_chainage - central_LR_chainage)
```

#### Right Rail Coordinates
```
if (calc_chainage < central_RR_chainage):
    RR_x = central_RR_x + ((central_RR_x - backward_RR_x) / (central_RR_chainage - backward_RR_chainage)) × (calc_chainage - central_RR_chainage)
    RR_y = central_RR_y + ((central_RR_y - backward_RR_y) / (central_RR_chainage - backward_RR_chainage)) × (calc_chainage - central_RR_chainage)
    RR_z = central_RR_z + ((central_RR_z - backward_RR_z) / (central_RR_chainage - backward_RR_chainage)) × (calc_chainage - central_RR_chainage)
else:
    RR_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) × (calc_chainage - central_RR_chainage)
    RR_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) × (calc_chainage - central_RR_chainage)
    RR_z = central_RR_z + ((forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)) × (calc_chainage - central_RR_chainage)
```

### Step 2: Calculate 3D Distance (Gauge)
```
gauge = √((LR_x - RR_x)² + (LR_y - RR_y)² + (LR_z - RR_z)²) × 1000
```

### Step 3: Calculate Deviation and Absolute Values
```
gauge_deviation = gauge - gauge_baseline
gauge_absolute_value = gauge_absolute + gauge_deviation
```

## Output
- **gauge** (double) - Track gauge in mm
- **gauge_deviation** (double) - Deviation from baseline in mm
- **gauge_absolute_value** (double) - Absolute gauge value in mm
- **Note**: Input coordinates assumed to be in meters, result scaled to millimeters

## JavaScript Implementation

### Gauge Deviation Calculation
```javascript
// Left Rail Coordinates
let LR_x, LR_y, LR_z;
if (calc_chainage < central_LR_chainage) {
    LR_x = central_LR_x + ((central_LR_x - backward_LR_x) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_y = central_LR_y + ((central_LR_y - backward_LR_y) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_z = central_LR_z + ((central_LR_z - backward_LR_z) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
} else {
    LR_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_z = central_LR_z + ((forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
}

// Right Rail Coordinates
let RR_x, RR_y, RR_z;
if (calc_chainage < central_RR_chainage) {
    RR_x = central_RR_x + ((central_RR_x - backward_RR_x) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_y = central_RR_y + ((central_RR_y - backward_RR_y) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_z = central_RR_z + ((central_RR_z - backward_RR_z) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
} else {
    RR_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_z = central_RR_z + ((forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
}

// Calculate 3D distance and deviation from baseline
(Math.sqrt(Math.pow(LR_x - RR_x, 2) + Math.pow(LR_y - RR_y, 2) + Math.pow(LR_z - RR_z, 2)) * 1000) - gauge_baseline;
```

### Gauge Calculation
```javascript
// Absolute gauge value
gauge_absolute + (gauge_deviation)
```