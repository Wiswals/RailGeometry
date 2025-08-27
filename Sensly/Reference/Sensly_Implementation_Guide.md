# Sensly Implementation Guide

## Parent Sensor Setup

### Input Variables Configuration
The parent sensor requires 30 input variables for complete track geometry computation:

#### Central Position Inputs (6 variables)
```
CL_LR_X (double) - Central Left Rail X coordinate
CL_LR_Y (double) - Central Left Rail Y coordinate  
CL_LR_Z (double) - Central Left Rail Z coordinate
CL_RR_X (double) - Central Right Rail X coordinate
CL_RR_Y (double) - Central Right Rail Y coordinate
CL_RR_Z (double) - Central Right Rail Z coordinate
```

#### Backward Position Inputs (6 variables)
```
BW_LR_X (double) - Backward Left Rail X coordinate
BW_LR_Y (double) - Backward Left Rail Y coordinate
BW_LR_Z (double) - Backward Left Rail Z coordinate
BW_RR_X (double) - Backward Right Rail X coordinate
BW_RR_Y (double) - Backward Right Rail Y coordinate
BW_RR_Z (double) - Backward Right Rail Z coordinate
```

#### Forward Position Inputs (6 variables)
```
FW_LR_X (double) - Forward Left Rail X coordinate
FW_LR_Y (double) - Forward Left Rail Y coordinate
FW_LR_Z (double) - Forward Left Rail Z coordinate
FW_RR_X (double) - Forward Right Rail X coordinate
FW_RR_Y (double) - Forward Right Rail Y coordinate
FW_RR_Z (double) - Forward Right Rail Z coordinate
```

#### Short Twist Position Inputs (6 variables)
```
ST_LR_X (double) - Short Twist Left Rail X coordinate
ST_LR_Y (double) - Short Twist Left Rail Y coordinate
ST_LR_Z (double) - Short Twist Left Rail Z coordinate
ST_RR_X (double) - Short Twist Right Rail X coordinate
ST_RR_Y (double) - Short Twist Right Rail Y coordinate
ST_RR_Z (double) - Short Twist Right Rail Z coordinate
```

#### Long Twist Position Inputs (6 variables)
```
LT_LR_X (double) - Long Twist Left Rail X coordinate
LT_LR_Y (double) - Long Twist Left Rail Y coordinate
LT_LR_Z (double) - Long Twist Left Rail Z coordinate
LT_RR_X (double) - Long Twist Right Rail X coordinate
LT_RR_Y (double) - Long Twist Right Rail Y coordinate
LT_RR_Z (double) - Long Twist Right Rail Z coordinate
```

### Output Variables Configuration
The parent sensor will output 8 track geometry parameters:

```
CANT (double) - Cross-level difference in mm
GAUGE (double) - Rail gauge in mm
TWIST_SHORT (double) - Short twist in mm/m
TWIST_LONG (double) - Long twist in mm/m
TOP_LEFT (double) - Left rail vertical alignment deviation in mm
TOP_RIGHT (double) - Right rail vertical alignment deviation in mm
LINE_LEFT (double) - Left rail horizontal alignment deviation in mm
LINE_RIGHT (double) - Right rail horizontal alignment deviation in mm
```

## Child Sensor Configuration
Each child sensor represents a prism location and provides XYZ coordinates:

### Child Sensor Outputs
```
X_COORD (double) - X coordinate of prism
Y_COORD (double) - Y coordinate of prism
Z_COORD (double) - Z coordinate of prism
```

## Sensor Relationships
- Child sensors feed their XYZ outputs to corresponding parent sensor inputs
- Parent sensor location represents the chainage for computed parameters
- Child sensors can be shared between multiple parent sensors if positioned appropriately

## Configuration Steps
1. Create child sensors for each prism location
2. Configure child sensor XYZ outputs
3. Create parent sensor with 30 input variables
4. Map child sensor outputs to parent sensor inputs
5. Implement computation logic in parent sensor
6. Configure parent sensor outputs for track geometry parameters