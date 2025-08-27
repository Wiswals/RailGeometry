# Line Calculation Formula

## Overview
Calculate horizontal versine (line) at target chainage using interpolated prism positions and horizontal versine formula.

## Input Parameters
- **calc_chainage** - Target chainage for calculation (midpoint)
- **versine_chord** - Full versine chord length
- **central_LR_chainage, central_RR_chainage** - Central prism chainages
- **backward_LR_chainage, backward_RR_chainage** - Backward prism chainages
- **forward_LR_chainage, forward_RR_chainage** - Forward prism chainages
- **central_LR_x, central_LR_y** - Central left rail coordinates
- **central_RR_x, central_RR_y** - Central right rail coordinates
- **backward_LR_x, backward_LR_y** - Backward left rail coordinates
- **backward_RR_x, backward_RR_y** - Backward right rail coordinates
- **forward_LR_x, forward_LR_y** - Forward left rail coordinates
- **forward_RR_x, forward_RR_y** - Forward right rail coordinates
- **LR_line_baseline** - Baseline left rail line value for deviation calculation
- **LR_line_absolute** - Absolute reference left rail line value
- **RR_line_baseline** - Baseline right rail line value for deviation calculation
- **RR_line_absolute** - Absolute reference right rail line value

## Prism Location and Versine Chord Diagrams

### Versine Chord Setup

```
Direction of Travel →

                      BW                            CL                        FW
                      ↓                             ↓                         ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─[FW_LR]─ ─ ─ ─     ← Left Rail
                      │                             │                         │
                    │                                │                        │
─ ─ ─ ─ ─ ─ ─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ [FW_RR]─ ─ ─ ─     ← Right Rail
                    ↑                                ↑                        ↑
                    BW                               CL                       FW

Actual prism positions (may not align with ideal versine chord)
```

### Interpolated Versine Positions

```
Direction of Travel →

                       ◄ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ CALC_VR_CHORD ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ►
                       ◄ ─ ─ ─ ─ ─ HALF_CHORD ─ ─ ─ ► ◄ ─ ─ ─ HALF_CHORD ─ ─ ─ ─ ►
                      │                              │                            │
                   BW_TARGET                      CALC_CH                     FW_TARGET
                      ↓                              ↓                            ↓
─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LR_BCK]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LR_MID]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[LR_FWD]─ ─ ─ ─     ← Left Rail
                      │                              │                            │
                      │                              │                            │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─[RR_BCK]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[RR_MID]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[RR_FWD]─ ─ ─ ─     ← Right Rail
                      ↑                              ↑                            ↑
                   BW_TARGET                      CALC_CH                     FW_TARGET

Interpolated positions at ideal versine chord locations:
BW_TARGET_CH = CALC_CH - (CALC_VR_CHORD / 2)
FW_TARGET_CH = CALC_CH + (CALC_VR_CHORD / 2)
```

### Versine Calculation Concept

```
Top View - Single Rail Versine Calculation:

[LR_BCK] .   .   .   .   .   .   .   .   .   .   .   . [LR_PROJ] .   .   .   .   .   .   .   .   .   .   .   . [LR_FWD]
             .                                             |                                             .
                 .                                         |                                         .
                     .                                     |                                     .
                         .                          (Versine Value)                          .
                             .                     Horizontal Offset                     .
                                 .                         |                         .
                                     .                     |                     .
                                         .                 |                 .
                                             .             |             .
                                                 .         |         .
                                                     .     ▼     .
                                                        [LR_MID]

Chord Line: Straight line from LR_BCK to LR_FWD
Projected Point: LR_MID projected onto chord line
Horizontal Offset: Distance from LR_MID to projected point
Sign: Determined by cross product (right curve = +, left curve = -)
```

## Calculation Steps

### Step 1: Calculate Target Chainages
```
half_chord = versine_chord / 2
backward_target_chainage = calc_chainage - half_chord
forward_target_chainage = calc_chainage + half_chord
```

### Step 2: Interpolate Rail Positions at Target Chainages

#### Left Rail - Central Position (at calc_chainage)
```
if (calc_chainage < central_LR_chainage):
    LR_mid_x = central_LR_x + ((central_LR_x - backward_LR_x) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage)
    LR_mid_y = central_LR_y + ((central_LR_y - backward_LR_y) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage)
else:
    LR_mid_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage)
    LR_mid_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage)
```

#### Left Rail - Backward Position (at backward_target_chainage)
```
LR_backward_x = central_LR_x + ((backward_LR_x - central_LR_x) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage)
LR_backward_y = central_LR_y + ((backward_LR_y - central_LR_y) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage)
```

#### Left Rail - Forward Position (at forward_target_chainage)
```
LR_forward_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage)
LR_forward_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage)
```

#### Right Rail - Central Position (at calc_chainage)
```
if (calc_chainage < central_RR_chainage):
    RR_mid_x = central_RR_x + ((central_RR_x - backward_RR_x) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage)
    RR_mid_y = central_RR_y + ((central_RR_y - backward_RR_y) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage)
else:
    RR_mid_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage)
    RR_mid_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage)
```

#### Right Rail - Backward Position (at backward_target_chainage)
```
RR_backward_x = central_RR_x + ((backward_RR_x - central_RR_x) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage)
RR_backward_y = central_RR_y + ((backward_RR_y - central_RR_y) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage)
```

#### Right Rail - Forward Position (at forward_target_chainage)
```
RR_forward_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage)
RR_forward_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage)
```

### Step 3: Calculate Horizontal Versine for Each Rail

#### Left Rail Versine
```
// Chord vector
LR_chord_x = LR_forward_x - LR_backward_x
LR_chord_y = LR_forward_y - LR_backward_y

// Projection parameter
LR_t = ((LR_mid_x - LR_backward_x) * LR_chord_x + (LR_mid_y - LR_backward_y) * LR_chord_y) / (LR_chord_x * LR_chord_x + LR_chord_y * LR_chord_y)

// Projected point
LR_projected_x = LR_backward_x + LR_t * LR_chord_x
LR_projected_y = LR_backward_y + LR_t * LR_chord_y

// Horizontal offset
LR_offset = Math.sqrt((LR_mid_x - LR_projected_x) * (LR_mid_x - LR_projected_x) + (LR_mid_y - LR_projected_y) * (LR_mid_y - LR_projected_y))

// Cross product for sign
LR_cross = LR_chord_x * (LR_mid_y - LR_backward_y) - LR_chord_y * (LR_mid_x - LR_backward_x)

// Left rail versine
LR_line = (LR_cross > 0 ? LR_offset : -LR_offset) * 1000
```

#### Right Rail Versine
```
// Chord vector
RR_chord_x = RR_forward_x - RR_backward_x
RR_chord_y = RR_forward_y - RR_backward_y

// Projection parameter
RR_t = ((RR_mid_x - RR_backward_x) * RR_chord_x + (RR_mid_y - RR_backward_y) * RR_chord_y) / (RR_chord_x * RR_chord_x + RR_chord_y * RR_chord_y)

// Projected point
RR_projected_x = RR_backward_x + RR_t * RR_chord_x
RR_projected_y = RR_backward_y + RR_t * RR_chord_y

// Horizontal offset
RR_offset = Math.sqrt((RR_mid_x - RR_projected_x) * (RR_mid_x - RR_projected_x) + (RR_mid_y - RR_projected_y) * (RR_mid_y - RR_projected_y))

// Cross product for sign
RR_cross = RR_chord_x * (RR_mid_y - RR_backward_y) - RR_chord_y * (RR_mid_x - RR_backward_x)

// Right rail versine
RR_line = (RR_cross > 0 ? RR_offset : -RR_offset) * 1000
```

### Step 4: Calculate Individual and Average Line
```
LR_line = (LR_cross > 0 ? LR_offset : -LR_offset) * 1000
RR_line = (RR_cross > 0 ? RR_offset : -RR_offset) * 1000
line = (LR_line + RR_line) / 2
```

### Step 5: Calculate Deviation and Absolute Values
```
LR_line_deviation = LR_line - LR_line_baseline
LR_line_absolute_value = LR_line_absolute + LR_line_deviation
RR_line_deviation = RR_line - RR_line_baseline
RR_line_absolute_value = RR_line_absolute + RR_line_deviation
```

## Output
- **LR_line** (double) - Left rail horizontal versine in mm (positive = right curve, negative = left curve)
- **RR_line** (double) - Right rail horizontal versine in mm (positive = right curve, negative = left curve)
- **line** (double) - Average horizontal versine in mm (positive = right curve, negative = left curve)
- **LR_line_deviation** (double) - Left rail line deviation from baseline in mm
- **LR_line_absolute_value** (double) - Absolute left rail line value in mm
- **RR_line_deviation** (double) - Right rail line deviation from baseline in mm
- **RR_line_absolute_value** (double) - Absolute right rail line value in mm
- **Note**: Input coordinates assumed to be in meters, result scaled to millimeters

## JavaScript Implementation

### Left Rail Line Deviation Calculation
```javascript
// Calculate target chainages
let half_chord = versine_chord / 2;
let backward_target_chainage = calc_chainage - half_chord;
let forward_target_chainage = calc_chainage + half_chord;

// Interpolate left rail central position
let LR_mid_x, LR_mid_y;
if (calc_chainage < central_LR_chainage) {
    LR_mid_x = central_LR_x + ((central_LR_x - backward_LR_x) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_mid_y = central_LR_y + ((central_LR_y - backward_LR_y) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
} else {
    LR_mid_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_mid_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
}

// Interpolate left rail versine positions
let LR_backward_x = central_LR_x + ((backward_LR_x - central_LR_x) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage);
let LR_backward_y = central_LR_y + ((backward_LR_y - central_LR_y) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage);
let LR_forward_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage);
let LR_forward_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage);

// Left rail versine calculation and deviation from baseline
let LR_chord_x = LR_forward_x - LR_backward_x;
let LR_chord_y = LR_forward_y - LR_backward_y;
let LR_t = ((LR_mid_x - LR_backward_x) * LR_chord_x + (LR_mid_y - LR_backward_y) * LR_chord_y) / (LR_chord_x * LR_chord_x + LR_chord_y * LR_chord_y);
let LR_projected_x = LR_backward_x + LR_t * LR_chord_x;
let LR_projected_y = LR_backward_y + LR_t * LR_chord_y;
let LR_offset = Math.sqrt((LR_mid_x - LR_projected_x) * (LR_mid_x - LR_projected_x) + (LR_mid_y - LR_projected_y) * (LR_mid_y - LR_projected_y));
let LR_cross = LR_chord_x * (LR_mid_y - LR_backward_y) - LR_chord_y * (LR_mid_x - LR_backward_x);

// Left rail line deviation result
((LR_cross > 0 ? LR_offset : -LR_offset) * 1000) - LR_line_baseline;
```

### Right Rail Line Deviation Calculation
```javascript
// Calculate target chainages
let half_chord = versine_chord / 2;
let backward_target_chainage = calc_chainage - half_chord;
let forward_target_chainage = calc_chainage + half_chord;

// Interpolate right rail central position
let RR_mid_x, RR_mid_y;
if (calc_chainage < central_RR_chainage) {
    RR_mid_x = central_RR_x + ((central_RR_x - backward_RR_x) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_mid_y = central_RR_y + ((central_RR_y - backward_RR_y) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
} else {
    RR_mid_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_mid_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
}

// Interpolate right rail versine positions
let RR_backward_x = central_RR_x + ((backward_RR_x - central_RR_x) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage);
let RR_backward_y = central_RR_y + ((backward_RR_y - central_RR_y) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage);
let RR_forward_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage);
let RR_forward_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage);

// Right rail versine calculation and deviation from baseline
let RR_chord_x = RR_forward_x - RR_backward_x;
let RR_chord_y = RR_forward_y - RR_backward_y;
let RR_t = ((RR_mid_x - RR_backward_x) * RR_chord_x + (RR_mid_y - RR_backward_y) * RR_chord_y) / (RR_chord_x * RR_chord_x + RR_chord_y * RR_chord_y);
let RR_projected_x = RR_backward_x + RR_t * RR_chord_x;
let RR_projected_y = RR_backward_y + RR_t * RR_chord_y;
let RR_offset = Math.sqrt((RR_mid_x - RR_projected_x) * (RR_mid_x - RR_projected_x) + (RR_mid_y - RR_projected_y) * (RR_mid_y - RR_projected_y));
let RR_cross = RR_chord_x * (RR_mid_y - RR_backward_y) - RR_chord_y * (RR_mid_x - RR_backward_x);

// Right rail line deviation result
((RR_cross > 0 ? RR_offset : -RR_offset) * 1000) - RR_line_baseline;
```

### Left Rail Line Calculation
```javascript
// Absolute left rail line value
LR_line_absolute + (LR_line_deviation)
```

### Right Rail Line Calculation
```javascript
// Absolute right rail line value
RR_line_absolute + (RR_line_deviation)
```