# Excel Configuration Setup Guide

## Purpose
Defines the named ranges required for all Power Query operations. These parameters control virtual sensor generation, prism assignment logic, and chord geometry calculations.

## Required Named Ranges

| Item | Parameter | Value | Units | Description | Named Range |
|------|-----------|-------|-------|-------------|-------------|
| Chainage Start | CALC_CH_START |  | m | Starting chainage for sensor placement | Cell_CH_Start |
| Chainage Finish | CALC_CH_FINISH |  | m | Ending chainage for sensor placement | Cell_CH_Finish |
| Chainage Step | CALC_CH_STEP |  | m | Chainage interval for sensor placement | Cell_CH_Step |
| Sensor Naming | SENSOR_PREFIX |  | text | Sensor naming template (use * for chainage position) | Cell_Sensor_Naming |
| Search Threshold | SEARCH_THRESHOLD |  | m | Maximum chainage difference for prism selection | Cell_Search_Threshold |
| Short Twist Chord | CALC_ST_CHORD |  | m | Standard short twist chord length | Cell_ST_Chord |
| Long Twist Chord | CALC_LT_CHORD |  | m | Standard long twist chord length | Cell_LT_Chord |
| Versine Chord | CALC_VR_CHORD |  | m | Standard versine (line/top) chord length | Cell_VR_Chord |
| Blueprint Name | BLUEPRINT_NAME |  | text | Sensly blueprint for track geometry sensors | Cell_Blueprint_Name |
| Track Section | TRACK_SECTION |  | text | Track section identifier for metadata | Cell_Track_Section |

## Setup Instructions

### 1. Create Parameter Table
Copy this table structure into Excel:

```
Item,Parameter,Value,Units,Description,Named Range
Chainage Step,CALC_CH_STEP,,m,Chainage interval for sensor placement,Cell_CH_Step
Chainage Start,CALC_CH_START,,m,Starting chainage for sensor placement,Cell_CH_Start
Chainage Finish,CALC_CH_FINISH,,m,Ending chainage for sensor placement,Cell_CH_Finish
Search Threshold,SEARCH_THRESHOLD,,m,Maximum chainage difference for prism selection,Cell_Search_Threshold
Sensor Naming,SENSOR_PREFIX,,text,Sensor naming template (use * for chainage position),Cell_Sensor_Naming
Short Twist Chord,CALC_ST_CHORD,,m,Standard short twist chord length,Cell_ST_Chord
Long Twist Chord,CALC_LT_CHORD,,m,Standard long twist chord length,Cell_LT_Chord
Versine Chord,CALC_VR_CHORD,,m,Standard versine (line/top) chord length,Cell_VR_Chord
Blueprint Name,BLUEPRINT_NAME,,text,Sensly blueprint for track geometry sensors,Cell_Blueprint_Name
Track Section,TRACK_SECTION,,text,Track section identifier for metadata,Cell_Track_Section
```

### 2. Define Named Ranges
For each parameter:
1. Select the cell containing the value
2. Go to Formulas > Define Name
3. Use the exact name from "Named Range" column
4. Ensure scope is set to "Workbook"

### 3. Required Excel Tables
Create these tables for Power Query dependencies:
- **Table_TrackData** - Raw prism survey data with columns: Prism ID, X, Y, Z, Track Chainage, Track Side, Offset X, Offset Y, Offset Z

## Parameter Guidelines

| Parameter | Typical Range | Common Values | Notes |
|-----------|---------------|---------------|-------|
| CALC_CH_START | Project specific | 0.0, 1000.0 | Align with survey data range |
| CALC_CH_FINISH | Project specific | 500.0, 2000.0 | Must not exceed available prisms |
| CALC_CH_STEP | 1-10 m | 2.0, 5.0, 10.0 | Smaller = more sensors, denser coverage |
| SEARCH_THRESHOLD | 1-5 m | 2.0, 3.0 | Larger = more flexible assignments |
| CALC_ST_CHORD | 3-5 m | 3.0, 4.0 | Per rail geometry standards |
| CALC_LT_CHORD | 10-20 m | 14.0, 20.0 | Per rail geometry standards |
| CALC_VR_CHORD | 10-20 m | 10.0, 20.0 | Half-chord used for BW/FW positioning |
| BLUEPRINT_NAME | Project specific | "Track Geometry (Relative)" | Must match available Sensly blueprints |
| TRACK_SECTION | Project specific | "Main Line", "Branch A" | Descriptive track section name |

## Power Query Execution Order

1. **Table_Virtual_Sensors** - Generates sensor grid from parameters
2. **Table_TrackData** - Loads prism survey data
3. **Table_SensorAssignment** - Assigns prisms to sensors using chord parameters
4. **Table_SenslyDataMapping** - Formats data mapping for Sensly import
5. **Table_SenslySensors** - Generates sensor definitions for Sensly import

## Validation Checklist

- [ ] All 10 named ranges defined with correct names
- [ ] Parameter values appropriate for project geometry
- [ ] Table_TrackData contains prism survey data
- [ ] Track Side column uses "LR"/"RR" format
- [ ] Sensor naming template includes * placeholder
- [ ] Chord lengths match rail geometry standards