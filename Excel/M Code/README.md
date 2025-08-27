# Rail Geometry M Code Functions

This folder contains Power Query M functions for railway geometry calculations and analysis.

## Base Utility Functions

### Excel_GetCellValue.pq
- **Function**: `Excel_GetCellValue`
- **Purpose**: Retrieves single cell value from Excel named range
- **Dependencies**: None

### XY_Distance2D.pq
- **Function**: `XY_Distance2D`
- **Purpose**: Calculates 2D Euclidean distance between two points
- **Dependencies**: None

### XYZ_Distance3D.pq
- **Function**: `XYZ_Distance3D`
- **Purpose**: Calculates 3D Euclidean distance between two points
- **Dependencies**: None

### XY_Bearing.pq
- **Function**: `XY_Bearing`
- **Purpose**: Calculates horizontal bearing between two points (0-360°)
- **Dependencies**: None

### XYZ_VerticalAngle.pq
- **Function**: `XYZ_VerticalAngle`
- **Purpose**: Calculates vertical angle between two 3D points
- **Dependencies**: XY_Distance2D.pq

### XY_Radius2D.pq
- **Function**: `XY_Radius2D`
- **Purpose**: Calculates radius of circle through three 2D points
- **Dependencies**: None

### XY_RefLinePerpHzOffset.pq
- **Function**: `XY_RefLinePerpHzOffset`
- **Purpose**: Calculates perpendicular offset from point to reference line
- **Dependencies**: None

## 3D Point Calculation Functions

### XYZ_PointAlongLine3DX.pq
- **Function**: `XYZ_PointAlongLine3DX`
- **Purpose**: Calculates X coordinate of point along 3D line at specified distance
- **Dependencies**: XY_Bearing.pq, XYZ_VerticalAngle.pq

### XYZ_PointAlongLine3DY.pq
- **Function**: `XYZ_PointAlongLine3DY`
- **Purpose**: Calculates Y coordinate of point along 3D line at specified distance
- **Dependencies**: XY_Bearing.pq, XYZ_VerticalAngle.pq

### XYZ_PointAlongLine3DZ.pq
- **Function**: `XYZ_PointAlongLine3DZ`
- **Purpose**: Calculates Z coordinate of point along 3D line at specified distance
- **Dependencies**: XYZ_VerticalAngle.pq

## Railway Geometry Functions

### Rail_Versine.pq
- **Function**: `Rail_Versine`
- **Purpose**: Calculates versine (vertical offset) for railway curve
- **Dependencies**: None

### Rail_CantGauge.pq
- **Function**: `Rail_CantGauge`
- **Purpose**: Calculates cant (cross-level) and gauge measurements between rail points
- **Dependencies**: XYZ_Distance3D.pq

### Rail_Twist.pq
- **Function**: `Rail_Twist`
- **Purpose**: Calculates twist (rate of change of cant) between two cant measurements
- **Dependencies**: None

### Rail_HorizontalVersine.pq
- **Function**: `Rail_HorizontalVersine`
- **Purpose**: Calculates horizontal versine from three XY points
- **Dependencies**: XY_Radius2D.pq, XY_RefLinePerpHzOffset.pq, Rail_Versine.pq

### Rail_VerticalVersine.pq
- **Function**: `Rail_VerticalVersine`
- **Purpose**: Calculates vertical versine from three XYZ points
- **Dependencies**: XY_Distance2D.pq, XY_Radius2D.pq, XY_RefLinePerpHzOffset.pq, Rail_Versine.pq

### Rail_InterpolateTrack.pq
- **Function**: `Rail_InterpolateTrack`
- **Purpose**: Interpolates 3D track coordinates at specified chainages
- **Dependencies**: XYZ_PointAlongLine3DX.pq, XYZ_PointAlongLine3DY.pq, XYZ_PointAlongLine3DZ.pq

## Usage Notes

- All functions use consistent naming: function names match their .pq file names
- Functions are unit-agnostic (work with any consistent unit system)
- Dependencies must be loaded in Power Query before using composite functions
- Each .pq file contains detailed header documentation with parameters and usage information

## Function Hierarchy

```
Base Functions (No Dependencies)
├── Excel_GetCellValue
├── XY_Distance2D
├── XYZ_Distance3D
├── XY_Bearing
├── XY_Radius2D
├── XY_RefLinePerpHzOffset
├── Rail_Versine
└── Rail_Twist

Level 1 Dependencies
├── XYZ_VerticalAngle (→ XY_Distance2D)
├── Rail_CantGauge (→ XYZ_Distance3D)
└── Rail_HorizontalVersine (→ XY_Radius2D, XY_RefLinePerpHzOffset, Rail_Versine)

Level 2 Dependencies
├── XYZ_PointAlongLine3DX (→ XY_Bearing, XYZ_VerticalAngle)
├── XYZ_PointAlongLine3DY (→ XY_Bearing, XYZ_VerticalAngle)
├── XYZ_PointAlongLine3DZ (→ XYZ_VerticalAngle)
└── Rail_VerticalVersine (→ XY_Distance2D, XY_Radius2D, XY_RefLinePerpHzOffset, Rail_Versine)

Level 3 Dependencies
└── Rail_InterpolateTrack (→ XYZ_PointAlongLine3DX, XYZ_PointAlongLine3DY, XYZ_PointAlongLine3DZ)
```