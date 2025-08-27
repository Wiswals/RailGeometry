# Power Query: Table_SenslyDataMapping

## Purpose
Transforms prism assignments into Sensly-compliant data mapping format for import into Sensly platform.

## Dependencies
- `Table_SensorAssignment` - Assigned prisms with coordinates

## Transformation Process
1. **Remove coordinate data** - Keep only Sensor_ID and prism ID columns
2. **Unpivot to long format** - Convert wide prism assignments to rows
3. **Expand for XYZ axes** - Create separate rows for X, Y, Z coordinates
4. **Format for Sensly import** - Structure as Input/Sensor/Source mapping

## Output Format
| Input | Sensor | Source | Source Type | Source output |
|-------|--------|--------|-------------|---------------|
| CL_LR_X | RAIL_001 | P001 | Sensor | X |
| CL_LR_Y | RAIL_001 | P001 | Sensor | Y |
| CL_LR_Z | RAIL_001 | P001 | Sensor | Z |

## M Code
```m
let
    // Load prism assignments (coordinates not needed for mapping)
    Source = Table_SensorAssignment,

    // Remove coordinate/chainage columns - keep only IDs for mapping
    RemoveCoordinates = Table.RemoveColumns(Source, {
        "CL_LR_X", "CL_LR_Y", "CL_LR_Z", "CL_LR_CH", 
        "CL_RR_X", "CL_RR_Y", "CL_RR_Z", "CL_RR_CH",
        "BW_LR_X", "BW_LR_Y", "BW_LR_Z", "BW_LR_CH", 
        "BW_RR_X", "BW_RR_Y", "BW_RR_Z", "BW_RR_CH",
        "FW_LR_X", "FW_LR_Y", "FW_LR_Z", "FW_LR_CH", 
        "FW_RR_X", "FW_RR_Y", "FW_RR_Z", "FW_RR_CH",
        "ST_LR_X", "ST_LR_Y", "ST_LR_Z", "ST_LR_CH", 
        "ST_RR_X", "ST_RR_Y", "ST_RR_Z", "ST_RR_CH",
        "LT_LR_X", "LT_LR_Y", "LT_LR_Z", "LT_LR_CH", 
        "LT_RR_X", "LT_RR_Y", "LT_RR_Z", "LT_RR_CH",
        "Chainages"
    }),

    // Convert from wide format (columns per prism) to long format (rows per prism)
    UnpivotPrismIDs = Table.UnpivotOtherColumns(RemoveCoordinates, {"Sensor_ID"}, "Attribute", "Value"),

    // Rename to Sensly mapping column names
    RenameMappingColumns = Table.RenameColumns(UnpivotPrismIDs, {
        {"Attribute", "Input"}, 
        {"Sensor_ID", "Sensor"}, 
        {"Value", "Source"}
    }),

    // Add source type column (all mappings are from sensors)
    AddSourceType = Table.AddColumn(RenameMappingColumns, "Source Type", each "Sensor", type text),

    // Clean prism position names (remove "_ID" suffix)
    CleanInputNames = Table.ReplaceValue(AddSourceType, "_ID", "", Replacer.ReplaceText, {"Input"}),

    // Create XYZ coordinate mappings for each prism assignment
    AddAxisList = Table.AddColumn(CleanInputNames, "AxisSuffix", each {"X", "Y", "Z"}, type list),
    ExpandToXYZ = Table.ExpandListColumn(AddAxisList, "AxisSuffix"),

    // Build final input names with coordinate suffixes (e.g., CL_LR_X, CL_LR_Y, CL_LR_Z)
    BuildFinalInputs = Table.AddColumn(ExpandToXYZ, "Input_Final", each 
        [Input] & "_" & [AxisSuffix], type text
    ),

    // Add source output column (coordinate axis only)
    AddSourceOutput = Table.AddColumn(BuildFinalInputs, "Source output", each [AxisSuffix], type text),

    // Clean up temporary columns
    RemoveTempColumns = Table.RemoveColumns(AddSourceOutput, {"Input", "AxisSuffix"}),
    
    // Finalize column structure
    FinalizeColumns = Table.RenameColumns(RemoveTempColumns, {{"Input_Final", "Input"}})
in
    FinalizeColumns
```

## Key Features
- **Sensly-compliant format** - Ready for direct import into Sensly platform
- **XYZ expansion** - Each prism assignment becomes 3 coordinate mappings
- **Clean naming** - Removes technical suffixes for cleaner Sensly inputs
- **Source tracking** - Maintains link between virtual sensors and physical prisms

## Usage
Export this table to CSV and import into Sensly to automatically configure all sensor input mappings.