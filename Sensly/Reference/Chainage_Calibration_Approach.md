# Chainage Calibration Approach

## Problem Statement
In real-world rail geometry monitoring, prisms cannot be positioned at exact theoretical locations. Each prism has an actual chainage that differs from the ideal calculation positions, and left/right rail prisms at the same "position" will have different chainages.

## Solution: Fixed Chainage Calibration

### Concept
- Each prism has a **fixed chainage location** stored as a calibration parameter (not an input)
- The parent sensor calculates at a **target chainage** (close to CL position)
- Scaling factors are applied to normalize measurements to standard chord lengths
- This allows consistent parameter calculations regardless of actual prism positioning

### Enhanced Input Structure

#### Coordinate Inputs (30 parameters - unchanged)
```
central_LR_x, central_LR_y, central_LR_z, central_RR_x, central_RR_y, central_RR_z,
backward_LR_x, backward_LR_y, backward_LR_z, backward_RR_x, backward_RR_y, backward_RR_z,
forward_LR_x, forward_LR_y, forward_LR_z, forward_RR_x, forward_RR_y, forward_RR_z,
short_twist_LR_x, short_twist_LR_y, short_twist_LR_z, short_twist_RR_x, short_twist_RR_y, short_twist_RR_z,
long_twist_LR_x, long_twist_LR_y, long_twist_LR_z, long_twist_RR_x, long_twist_RR_y, long_twist_RR_z
```

#### Chainage Calibration Parameters (10 parameters - fixed values)
```
central_LR_chainage, central_RR_chainage,
backward_LR_chainage, backward_RR_chainage,
forward_LR_chainage, forward_RR_chainage,
short_twist_LR_chainage, short_twist_RR_chainage,
long_twist_LR_chainage, long_twist_RR_chainage
```

#### Target Calculation Parameters (4 parameters - configuration)
```
calc_chainage (double) - Chainage where parameters are calculated
short_twist_chord (double) - Standard short twist chord length
long_twist_chord (double) - Standard long twist chord length
versine_chord (double) - Standard versine (line/top) chord length
```

## Calculation Methodology

### 1. Chainage-Based Scaling
For each parameter calculation:
1. Determine actual chord lengths from chainage differences
2. Calculate scaling factors to normalize to standard chord lengths
3. Apply scaling to measurement results

### 2. Example: Short Twist Calculation
```
actual_short_twist_chord = |calc_chainage - short_twist_LR_chainage|
scaling_factor = short_twist_chord / actual_short_twist_chord
scaled_twist = raw_twist_calculation × scaling_factor
```

### 3. Interpolation for Target Chainage
When prisms don't align exactly with target chainage:
- Use linear interpolation between adjacent measurements
- Weight measurements based on chainage proximity
- Ensure consistent parameter reporting location

## Benefits
- **Standardized Output**: All parameters calculated at consistent chord lengths
- **Flexible Installation**: Prisms can be positioned based on site constraints
- **Accurate Scaling**: Real chord lengths accounted for in calculations
- **Consistent Reporting**: All parameters referenced to target chainage location

## Implementation Impact
- **Total Inputs**: 44 parameters (30 coordinates + 10 chainages + 4 configuration)
- **Baseline Calibration**: Additional baseline and absolute reference values for each output parameter
- **Calibration Process**: One-time setup of chainage parameters per installation
- **Calculation Complexity**: Moderate increase due to scaling and interpolation
- **Output Consistency**: Standardized parameter values with deviation tracking from baseline