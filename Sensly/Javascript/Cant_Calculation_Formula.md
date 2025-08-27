# Cant Calculation Formula

## Overview
Calculate Cant at target chainage (calc_chainage) using gradient-corrected prism data from Backward prism, Central prism, and Forward prism positions.

## Input Parameters
- **calc_chainage** - Target chainage for calculation
- **central_LR_chainage, central_RR_chainage** - Central prism chainages
- **backward_LR_chainage, backward_RR_chainage** - Backward prism chainages
- **forward_LR_chainage, forward_RR_chainage** - Forward prism chainages
- **central_LR_z, central_RR_z** - Central prism elevations
- **backward_LR_z, backward_RR_z** - Backward prism elevations
- **forward_LR_z, forward_RR_z** - Forward prism elevations
- **cant_baseline** - Baseline cant value for deviation calculation
- **cant_absolute** - Absolute reference cant value

## Prism Location Diagrams

### Target chainage Behind Central Position

```
Direction of Travel →

                      BW                            CL                        FW
                      ↓                             ↓                         ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─[FW_LR]─ ─ ─ ─     ← Left Rail
                      │                      ▲      │                         │
                    │              calc_chainage     │                        │
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail
                    ↑                                ↑                        ↑
                    BW                               CL                       FW

calc_chainage between BW and CL (uses BW→CL gradient)
```

### Target chainage Ahead of Central Position

```
Direction of Travel →

                      BW                            CL                        FW
                      ↓                             ↓                         ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─[FW_LR]─ ─ ─ ─     ← Left Rail
                      │                             │     ▲                   │
                    │                                │    calc_chainage       │
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail
                    ↑                                ↑                        ↑
                    BW                               CL                       FW

calc_chainage between CL and FW (uses CL→FW gradient)
```

### Position-Corrected Cant Location (Target chainage Behind Central Position)

```
Direction of Travel →

─ ─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─[FW_LR]─ ─ ─ ─     ← Left Rail
                                            │                        
                               central_cant │                   
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail


central_cant calculated at calc_chainage using interpolated rail elevations
```

## Calculation Steps

### Step 1: Determine Gradient Direction
For each rail, determine if calc_chainage is before or after the central position:

```
if (calc_chainage < central_LR_chainage):
    Use backward_LR for gradient calculation
else:
    Use forward_LR for gradient calculation

if (calc_chainage < central_RR_chainage):
    Use backward_RR for gradient calculation
else:
    Use forward_RR for gradient calculation
```

### Step 2: Calculate Rail Gradients

#### Left Rail Gradient
```
if (calc_chainage < central_LR_chainage):
    LR_gradient = (central_LR_z - backward_LR_z) / (central_LR_chainage - backward_LR_chainage)
else:
    LR_gradient = (forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)
```

#### Right Rail Gradient
```
if (calc_chainage < central_RR_chainage):
    RR_gradient = (central_RR_z - backward_RR_z) / (central_RR_chainage - backward_RR_chainage)
else:
    RR_gradient = (forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)
```

### Step 3: Calculate Elevations at Target Chainage
```
LR_elevation_at_calc_chainage = central_LR_z + LR_gradient × (calc_chainage - central_LR_chainage)
RR_elevation_at_calc_chainage = central_RR_z + RR_gradient × (calc_chainage - central_RR_chainage)
```

### Step 4: Calculate Central Cant
```
central_cant = (RR_elevation_at_calc_chainage - LR_elevation_at_calc_chainage) * 1000
```

### Step 5: Calculate Deviation and Absolute Values
```
cant_deviation = central_cant - cant_baseline
cant_absolute_value = cant_absolute + cant_deviation
```

## Output
- **central_cant** (double) - Central cant in mm (positive = right rail higher)
- **cant_deviation** (double) - Deviation from baseline in mm
- **cant_absolute_value** (double) - Absolute cant value in mm
- **Note**: Input coordinates assumed to be in meters, result scaled to millimeters

## JavaScript Implementation

### Cant Deviation Calculation
```javascript
// Left Rail Gradient and Elevation
let LR_grad, LR_elev;
if (calc_chainage < central_LR_chainage) {
    LR_grad = (central_LR_z - backward_LR_z) / (central_LR_chainage - backward_LR_chainage);
} else {
    LR_grad = (forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage);
}
LR_elev = central_LR_z + LR_grad * (calc_chainage - central_LR_chainage);

// Right Rail Gradient and Elevation
let RR_grad, RR_elev;
if (calc_chainage < central_RR_chainage) {
    RR_grad = (central_RR_z - backward_RR_z) / (central_RR_chainage - backward_RR_chainage);
} else {
    RR_grad = (forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage);
}
RR_elev = central_RR_z + RR_grad * (calc_chainage - central_RR_chainage);

// Calculate Central Cant and Deviation from baseline
((RR_elev - LR_elev) * 1000) - cant_baseline;
```

### Cant Calculation
```javascript
// Absolute cant value
cant_absolute + (cant_deviation)
```