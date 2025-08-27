# Power Query: Table_SenslySensors

## Purpose
Generates Sensly Sensors import file to create virtual sensors in Sensly platform with proper blueprint assignments and metadata.

## Dependencies
- `Table_Virtual_Sensors` - Virtual sensor locations and names
- `Table_TrackData` - Raw prism data for interpolation
- `Table_SensorAssignment` - For parent sensor prism list
- `Function_GridToGeographic` - Coordinate conversion function
- `Function_InterpolateRailPosition` - Track position interpolation
- Helper functions: `BearingDD`, `PointAlongLine3DX`, `PointAlongLine3DY`
- Named ranges: `Cell_Blueprint_Name`, `Cell_Track_Section`

## Output Format
CSV file ready for direct import into Sensly Sensors section.

## M Code
```m
let
    // Load source data
    VirtualSensors = Table_Virtual_Sensors,
    TrackData = Table_TrackData,
    SensorAssignments = Table_SensorAssignment,
    
    // Get configuration from named ranges
    BlueprintName = Excel.CurrentWorkbook(){[Name="Cell_Blueprint_Name"]}[Content]{0}[Column1],
    TrackSection = Excel.CurrentWorkbook(){[Name="Cell_Track_Section"]}[Content]{0}[Column1],
    
    // Coordinate system parameters (update these for your project)
    SemiMajorAxis = 6378137,                    // GRS80 semi-major axis
    FlatteningReciprocal = 298.257222101,       // GRS80 flattening reciprocal
    CentralMeridian = 117,                      // MGA Zone 50 central meridian
    FalseEasting = 500000,                      // MGA false easting
    FalseNorthing = 10000000,                   // MGA false northing
    ScaleFactor = 0.9996,                       // MGA scale factor
    
    // Interpolate left rail positions at virtual sensor chainages
    InterpolateLR = Function_InterpolateRailPosition(VirtualSensors, "LR", TrackData),
    
    // Interpolate right rail positions at virtual sensor chainages  
    InterpolateRR = Function_InterpolateRailPosition(InterpolateLR, "RR", TrackData),
    
    // Calculate average coordinates between left and right rails
    AddAvgEasting = Table.AddColumn(InterpolateRR, "AvgEasting", each 
        if [LR_Intp_X] <> null and [RR_Intp_X] <> null then ([LR_Intp_X] + [RR_Intp_X]) / 2
        else if [LR_Intp_X] <> null then [LR_Intp_X]
        else if [RR_Intp_X] <> null then [RR_Intp_X]
        else null
    ),
    AddAvgNorthing = Table.AddColumn(AddAvgEasting, "AvgNorthing", each 
        if [LR_Intp_Y] <> null and [RR_Intp_Y] <> null then ([LR_Intp_Y] + [RR_Intp_Y]) / 2
        else if [LR_Intp_Y] <> null then [LR_Intp_Y]
        else if [RR_Intp_Y] <> null then [RR_Intp_Y]
        else null
    ),
    
    // Convert coordinates using GridToGeographic function
    AddGeographicCoords = Table.AddColumn(AddAvgNorthing, "Geographic", each 
        if [AvgEasting] <> null and [AvgNorthing] <> null then
            Function_GridToGeographic([AvgEasting], [AvgNorthing], SemiMajorAxis, FlatteningReciprocal, CentralMeridian, FalseEasting, FalseNorthing, ScaleFactor)
        else null
    ),
    
    // Extract latitude and longitude
    AddLatitude = Table.AddColumn(AddGeographicCoords, "Latitude", each 
        if [Geographic] <> null then [Geographic][Latitude] else null
    ),
    AddLongitude = Table.AddColumn(AddLatitude, "Longitude", each 
        if [Geographic] <> null then [Geographic][Longitude] else null
    ),
    
    // Build Sensly Sensors table
    AddName = Table.AddColumn(AddLongitude, "Name", each [Sensor_ID]),
    AddBlueprint = Table.AddColumn(AddName, "Blueprint", each BlueprintName),
    AddSerialNumber = Table.AddColumn(AddBlueprint, "Serial number", each null, type text),
    AddVisibleOnMap = Table.AddColumn(AddSerialNumber, "Visible on map", each true, type logical),
    AddHideSensor = Table.AddColumn(AddVisibleOnMap, "Hide sensor", each false, type logical),
    AddDisableAlarms = Table.AddColumn(AddHideSensor, "Disable alarms", each false, type logical),
    // Merge with sensor assignments to get parent sensors list
    MergeAssignments = Table.NestedJoin(AddDisableAlarms, {"Name"}, SensorAssignments, {"Sensor_ID"}, "Assignment", JoinKind.LeftOuter),
    ExpandParentSensors = Table.ExpandTableColumn(MergeAssignments, "Assignment", {"Parent_Sensors"}, {"Field:Parent Sensors"}),
    AddTrackSection = Table.AddColumn(ExpandParentSensors, "Field:Track Section", each TrackSection),
    AddTrackChainage = Table.AddColumn(AddTrackSection, "Field:Track Chainage", each [Chainages]),
    
    // Remove interpolation columns, keep only Sensly format
    RemoveOriginalColumns = Table.RemoveColumns(AddTrackChainage, {
        "Sensor_ID", "Chainages", "AvgEasting", "AvgNorthing", "Geographic",
        "LR_Last_CH", "LR_Next_CH", "LR_Last_X", "LR_Last_Y", "LR_Last_Z",
        "LR_Next_X", "LR_Next_Y", "LR_Next_Z", "LR_Intp_Dist", "LR_Intp_X", "LR_Intp_Y",
        "RR_Last_CH", "RR_Next_CH", "RR_Last_X", "RR_Last_Y", "RR_Last_Z",
        "RR_Next_X", "RR_Next_Y", "RR_Next_Z", "RR_Intp_Dist", "RR_Intp_X", "RR_Intp_Y"
    }),
    
    // Ensure proper column order for Sensly import
    ReorderColumns = Table.ReorderColumns(RemoveOriginalColumns, {
        "Name", "Blueprint", "Latitude", "Longitude", "Serial number", 
        "Visible on map", "Hide sensor", "Disable alarms", 
        "Field:Parent Sensors", "Field:Track Section", "Field:Track Chainage"
    })
in
    ReorderColumns
```

## Required Named Ranges
Add these to your Excel configuration:

| Parameter | Description | Named Range | Example Value |
|-----------|-------------|-------------|---------------|
| Blueprint Name | Sensly blueprint for track geometry sensors | Cell_Blueprint_Name | "Track Geometry (Relative)" |
| Track Section | Track section identifier | Cell_Track_Section | "Main Line" |

## Coordinate System Configuration
Update these hardcoded values in the M code for your coordinate system:

| Parameter | MGA Zone 50 | MGA Zone 55 | PCG2020 |
|-----------|-------------|-------------|----------|
| SemiMajorAxis | 6378137 | 6378137 | 6378137 |
| FlatteningReciprocal | 298.257222101 | 298.257222101 | 298.257222101 |
| CentralMeridian | 117 | 147 | 115.883333333 |
| FalseEasting | 500000 | 500000 | 50000 |
| FalseNorthing | 10000000 | 10000000 | 3800000 |
| ScaleFactor | 0.9996 | 0.9996 | 1.0000054 |

## Output Columns
- **Name** - Sensor identifier (from Sensor_ID)
- **Blueprint** - Sensly blueprint name
- **Latitude/Longitude** - Converted from average CL prism coordinates
- **Serial number** - Empty (populated by Sensly)
- **Visible on map** - True (show on map)
- **Hide sensor** - False (sensor visible)
- **Disable alarms** - False (alarms enabled)
- **Field:Parent Sensors** - Empty (no parent sensors)
- **Field:Track Section** - Track section name
- **Field:Track Chainage** - Calculation chainage

## Setup Requirements
1. Create all interpolation functions as custom functions in Power Query:
   - `BearingDD`
   - `PointAlongLine3DX` 
   - `PointAlongLine3DY`
   - `Function_InterpolateRailPosition`
2. Create `Function_GridToGeographic` as custom function
3. Update coordinate system parameters in M code (lines 8-13)
4. Ensure `Table_TrackData` contains prism survey data

## Usage
Export this table to CSV and import into Sensly Sensors section to create all virtual track geometry sensors with accurate GPS coordinates.