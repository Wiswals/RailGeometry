# Prism Naming Convention for Sensly

## Naming Pattern
`{POSITION}_{RAIL}_{COORDINATE}`

### Position Codes (2 characters)
- **CL** = Central (current/closest to parent sensor)
- **BW** = Backward (half chord length behind central)
- **FW** = Forward (half chord length ahead of central)
- **ST** = Short Twist (short twist chord length)
- **LT** = Long Twist (long twist chord length)

### Rail Codes (2 characters)
- **LR** = Left Rail
- **RR** = Right Rail

### Coordinate Codes (1 character)
- **X** = X coordinate (Easting)
- **Y** = Y coordinate (Northing)  
- **Z** = Z coordinate (Elevation)

## Complete Parameter Set for All Computations

### Central Position (Cant, Gauge, Twist, Line, Top)
```
CL_LR_X, CL_LR_Y, CL_LR_Z
CL_RR_X, CL_RR_Y, CL_RR_Z
```

### Backward Position (Line, Top)
```
BW_LR_X, BW_LR_Y, BW_LR_Z
BW_RR_X, BW_RR_Y, BW_RR_Z
```

### Forward Position (Line, Top)
```
FW_LR_X, FW_LR_Y, FW_LR_Z
FW_RR_X, FW_RR_Y, FW_RR_Z
```

### Short Twist Position
```
ST_LR_X, ST_LR_Y, ST_LR_Z
ST_RR_X, ST_RR_Y, ST_RR_Z
```

### Long Twist Position
```
LT_LR_X, LT_LR_Y, LT_LR_Z
LT_RR_X, LT_RR_Y, LT_RR_Z
```

## Total Input Parameters Required
**30 unique coordinate inputs** (5 positions × 2 rails × 3 coordinates)

## Usage in Sensly
- Each parameter becomes a unique input variable in the parent sensor
- Child sensors provide the XYZ data for their respective prism locations
- Parent sensor uses these inputs to compute track geometry parameters