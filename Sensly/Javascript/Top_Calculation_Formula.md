# Top Calculation Formula

## Overview
Calculate vertical versine (top) at target chainage using interpolated prism positions and vertical versine formula.

## Input Parameters
- **calc_chainage** - Target chainage for calculation (midpoint)
- **versine_chord** - Full versine chord length
- **central_LR_chainage, central_RR_chainage** - Central prism chainages
- **backward_LR_chainage, backward_RR_chainage** - Backward prism chainages
- **forward_LR_chainage, forward_RR_chainage** - Forward prism chainages
- **central_LR_x, central_LR_y, central_LR_z** - Central left rail coordinates
- **central_RR_x, central_RR_y, central_RR_z** - Central right rail coordinates
- **backward_LR_x, backward_LR_y, backward_LR_z** - Backward left rail coordinates
- **backward_RR_x, backward_RR_y, backward_RR_z** - Backward right rail coordinates
- **forward_LR_x, forward_LR_y, forward_LR_z** - Forward left rail coordinates
- **forward_RR_x, forward_RR_y, forward_RR_z** - Forward right rail coordinates
- **LR_top_baseline** - Baseline left rail top value for deviation calculation
- **LR_top_absolute** - Absolute reference left rail top value
- **RR_top_baseline** - Baseline right rail top value for deviation calculation
- **RR_top_absolute** - Absolute reference right rail top value

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

### Vertical Versine Calculation Concept

```
Side View - Single Rail Vertical Versine Calculation:

[LR_BCK] .   .   .   .   .   .   .   .   .   .   .   . [LR_GRADE] .   .   .   .   .   .   .   .   .   .   .   . [LR_FWD]
             .                                             |                                             .
                 .                                         |                                         .
                     .                                     |                                     .
                         .                          (Versine Value)                          .
                             .                      Vertical Offset                      .
                                 .                         |                         .
                                     .                     |                     .
                                         .                 |                 .
                                             .             |             .
                                                 .         |         .
                                                     .     ▼     .
                                                        [LR_MID]

Grade Line: Straight line from LR_BCK to LR_FWD
Grade Point: Elevation on grade line at midpoint
Vertical Offset: Distance from LR_MID to grade line
Sign: Positive = sag curve, Negative = crest curve
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
    LR_mid_z = central_LR_z + ((central_LR_z - backward_LR_z) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage)
else:
    LR_mid_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage)
    LR_mid_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage)
    LR_mid_z = central_LR_z + ((forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage)
```

#### Left Rail - Backward Position (at backward_target_chainage)
```
LR_backward_x = central_LR_x + ((backward_LR_x - central_LR_x) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage)
LR_backward_y = central_LR_y + ((backward_LR_y - central_LR_y) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage)
LR_backward_z = central_LR_z + ((backward_LR_z - central_LR_z) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage)
```

#### Left Rail - Forward Position (at forward_target_chainage)
```
LR_forward_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage)
LR_forward_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage)
LR_forward_z = central_LR_z + ((forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage)
```

#### Right Rail - Central Position (at calc_chainage)
```
if (calc_chainage < central_RR_chainage):
    RR_mid_x = central_RR_x + ((central_RR_x - backward_RR_x) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage)
    RR_mid_y = central_RR_y + ((central_RR_y - backward_RR_y) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage)
    RR_mid_z = central_RR_z + ((central_RR_z - backward_RR_z) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage)
else:
    RR_mid_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage)
    RR_mid_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage)
    RR_mid_z = central_RR_z + ((forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage)
```

#### Right Rail - Backward Position (at backward_target_chainage)
```
RR_backward_x = central_RR_x + ((backward_RR_x - central_RR_x) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage)
RR_backward_y = central_RR_y + ((backward_RR_y - central_RR_y) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage)
RR_backward_z = central_RR_z + ((backward_RR_z - central_RR_z) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage)
```

#### Right Rail - Forward Position (at forward_target_chainage)
```
RR_forward_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage)
RR_forward_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage)
RR_forward_z = central_RR_z + ((forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage)
```

### Step 3: Calculate Vertical Versine for Each Rail

#### Left Rail Versine
```
// Horizontal distance between backward and forward points
LR_horizontal_distance = Math.sqrt((LR_forward_x - LR_backward_x) * (LR_forward_x - LR_backward_x) + (LR_forward_y - LR_backward_y) * (LR_forward_y - LR_backward_y))

// Grade between backward and forward points
LR_grade = (LR_forward_z - LR_backward_z) / LR_horizontal_distance

// Elevation on grade line at midpoint
LR_z_grade = LR_backward_z + LR_grade * (LR_horizontal_distance / 2)

// Vertical offset (versine)
LR_vertical_offset = LR_mid_z - LR_z_grade

// Left rail versine
LR_top = LR_vertical_offset * 1000
```

#### Right Rail Versine
```
// Horizontal distance between backward and forward points
RR_horizontal_distance = Math.sqrt((RR_forward_x - RR_backward_x) * (RR_forward_x - RR_backward_x) + (RR_forward_y - RR_backward_y) * (RR_forward_y - RR_backward_y))

// Grade between backward and forward points
RR_grade = (RR_forward_z - RR_backward_z) / RR_horizontal_distance

// Elevation on grade line at midpoint
RR_z_grade = RR_backward_z + RR_grade * (RR_horizontal_distance / 2)

// Vertical offset (versine)
RR_vertical_offset = RR_mid_z - RR_z_grade

// Right rail versine
RR_top = RR_vertical_offset * 1000
```

### Step 4: Calculate Individual and Average Top
```
LR_top = LR_vertical_offset * 1000
RR_top = RR_vertical_offset * 1000
top = (LR_top + RR_top) / 2
```

### Step 5: Calculate Deviation and Absolute Values
```
LR_top_deviation = LR_top - LR_top_baseline
LR_top_absolute_value = LR_top_absolute + LR_top_deviation
RR_top_deviation = RR_top - RR_top_baseline
RR_top_absolute_value = RR_top_absolute + RR_top_deviation
```

## Output
- **LR_top** (double) - Left rail vertical versine in mm (positive = sag curve, negative = crest curve)
- **RR_top** (double) - Right rail vertical versine in mm (positive = sag curve, negative = crest curve)
- **top** (double) - Average vertical versine in mm (positive = sag curve, negative = crest curve)
- **LR_top_deviation** (double) - Left rail top deviation from baseline in mm
- **LR_top_absolute_value** (double) - Absolute left rail top value in mm
- **RR_top_deviation** (double) - Right rail top deviation from baseline in mm
- **RR_top_absolute_value** (double) - Absolute right rail top value in mm
- **Note**: Input coordinates assumed to be in meters, result scaled to millimeters

## JavaScript Implementation

### Left Rail Top Deviation Calculation
```javascript
// Calculate target chainages
let half_chord = versine_chord / 2;
let backward_target_chainage = calc_chainage - half_chord;
let forward_target_chainage = calc_chainage + half_chord;

// Interpolate left rail central position
let LR_mid_x, LR_mid_y, LR_mid_z;
if (calc_chainage < central_LR_chainage) {
    LR_mid_x = central_LR_x + ((central_LR_x - backward_LR_x) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_mid_y = central_LR_y + ((central_LR_y - backward_LR_y) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_mid_z = central_LR_z + ((central_LR_z - backward_LR_z) / (central_LR_chainage - backward_LR_chainage)) * (calc_chainage - central_LR_chainage);
} else {
    LR_mid_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_mid_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
    LR_mid_z = central_LR_z + ((forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)) * (calc_chainage - central_LR_chainage);
}

// Interpolate left rail versine positions
let LR_backward_x = central_LR_x + ((backward_LR_x - central_LR_x) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage);
let LR_backward_y = central_LR_y + ((backward_LR_y - central_LR_y) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage);
let LR_backward_z = central_LR_z + ((backward_LR_z - central_LR_z) / (backward_LR_chainage - central_LR_chainage)) * (backward_target_chainage - central_LR_chainage);
let LR_forward_x = central_LR_x + ((forward_LR_x - central_LR_x) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage);
let LR_forward_y = central_LR_y + ((forward_LR_y - central_LR_y) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage);
let LR_forward_z = central_LR_z + ((forward_LR_z - central_LR_z) / (forward_LR_chainage - central_LR_chainage)) * (forward_target_chainage - central_LR_chainage);

// Left rail vertical versine calculation and deviation from baseline
let LR_horizontal_distance = Math.sqrt((LR_forward_x - LR_backward_x) * (LR_forward_x - LR_backward_x) + (LR_forward_y - LR_backward_y) * (LR_forward_y - LR_backward_y));
let LR_grade = (LR_forward_z - LR_backward_z) / LR_horizontal_distance;
let LR_z_grade = LR_backward_z + LR_grade * (LR_horizontal_distance / 2);
let LR_vertical_offset = LR_mid_z - LR_z_grade;

// Left rail top deviation result
(LR_vertical_offset * 1000) - LR_top_baseline;
```

### Right Rail Top Deviation Calculation
```javascript
// Calculate target chainages
let half_chord = versine_chord / 2;
let backward_target_chainage = calc_chainage - half_chord;
let forward_target_chainage = calc_chainage + half_chord;

// Interpolate right rail central position
let RR_mid_x, RR_mid_y, RR_mid_z;
if (calc_chainage < central_RR_chainage) {
    RR_mid_x = central_RR_x + ((central_RR_x - backward_RR_x) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_mid_y = central_RR_y + ((central_RR_y - backward_RR_y) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_mid_z = central_RR_z + ((central_RR_z - backward_RR_z) / (central_RR_chainage - backward_RR_chainage)) * (calc_chainage - central_RR_chainage);
} else {
    RR_mid_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_mid_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
    RR_mid_z = central_RR_z + ((forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)) * (calc_chainage - central_RR_chainage);
}

// Interpolate right rail versine positions
let RR_backward_x = central_RR_x + ((backward_RR_x - central_RR_x) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage);
let RR_backward_y = central_RR_y + ((backward_RR_y - central_RR_y) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage);
let RR_backward_z = central_RR_z + ((backward_RR_z - central_RR_z) / (backward_RR_chainage - central_RR_chainage)) * (backward_target_chainage - central_RR_chainage);
let RR_forward_x = central_RR_x + ((forward_RR_x - central_RR_x) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage);
let RR_forward_y = central_RR_y + ((forward_RR_y - central_RR_y) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage);
let RR_forward_z = central_RR_z + ((forward_RR_z - central_RR_z) / (forward_RR_chainage - central_RR_chainage)) * (forward_target_chainage - central_RR_chainage);

// Right rail vertical versine calculation and deviation from baseline
let RR_horizontal_distance = Math.sqrt((RR_forward_x - RR_backward_x) * (RR_forward_x - RR_backward_x) + (RR_forward_y - RR_backward_y) * (RR_forward_y - RR_backward_y));
let RR_grade = (RR_forward_z - RR_backward_z) / RR_horizontal_distance;
let RR_z_grade = RR_backward_z + RR_grade * (RR_horizontal_distance / 2);
let RR_vertical_offset = RR_mid_z - RR_z_grade;

// Right rail top deviation result
(RR_vertical_offset * 1000) - RR_top_baseline;
```

### Left Rail Top Calculation
```javascript
// Absolute left rail top value
LR_top_absolute + (LR_top_deviation)
```

### Right Rail Top Calculation
```javascript
// Absolute right rail top value
RR_top_absolute + (RR_top_deviation)
```