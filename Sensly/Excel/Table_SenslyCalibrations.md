# Power Query: Table_SenslyCalibrations

## Purpose
Generates Sensly Calibrations import file with factor values for each virtual sensor.

## Dependencies
- `Table_SensorAssignment` - Virtual sensors with prism assignments
- Named ranges: `Cell_ST_Chord`, `Cell_LT_Chord`, `Cell_VR_Chord`

## Output Format
CSV file with Sensor, Datetime, Factor, Value columns for Sensly calibration import.

## M Code
```m
let
    // Load sensor assignments
    SensorAssignments = Table_SensorAssignment,
    
    // Get chord lengths from named ranges (same for all sensors)
    ST_Chord = Excel.CurrentWorkbook(){[Name="Cell_ST_Chord"]}[Content]{0}[Column1],
    LT_Chord = Excel.CurrentWorkbook(){[Name="Cell_LT_Chord"]}[Content]{0}[Column1],
    VR_Chord = Excel.CurrentWorkbook(){[Name="Cell_VR_Chord"]}[Content]{0}[Column1],
    
    // Create calibration factors for each sensor
    AddCalibrations = Table.AddColumn(SensorAssignments, "Calibrations", each
        let
            SensorName = [Sensor_ID],
            CalcCH = [Chainages]
        in
            {
                [Sensor = SensorName, Datetime = "Default", Factor = "BW_LR_CH", Value = [BW_LR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "BW_RR_CH", Value = [BW_RR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "CALC_CH", Value = CalcCH],
                [Sensor = SensorName, Datetime = "Default", Factor = "CALC_LT_CHORD", Value = LT_Chord],
                [Sensor = SensorName, Datetime = "Default", Factor = "CALC_ST_CHORD", Value = ST_Chord],
                [Sensor = SensorName, Datetime = "Default", Factor = "CALC_VR_CHORD", Value = VR_Chord],
                [Sensor = SensorName, Datetime = "Default", Factor = "CL_LR_CH", Value = [CL_LR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "CL_RR_CH", Value = [CL_RR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "FW_LR_CH", Value = [FW_LR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "FW_RR_CH", Value = [FW_RR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "LT_LR_CH", Value = [LT_LR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "LT_RR_CH", Value = [LT_RR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "ST_LR_CH", Value = [ST_LR_CH]],
                [Sensor = SensorName, Datetime = "Default", Factor = "ST_RR_CH", Value = [ST_RR_CH]]
            }
    ),
    
    // Expand calibrations to individual rows
    ExpandCalibrations = Table.ExpandListColumn(AddCalibrations, "Calibrations"),
    ExpandRecords = Table.ExpandRecordColumn(ExpandCalibrations, "Calibrations", 
        {"Sensor", "Datetime", "Factor", "Value"}),
    
    // Remove original columns, keep only calibration format
    SelectColumns = Table.SelectColumns(ExpandRecords, {"Sensor", "Datetime", "Factor", "Value"}),
    
    // Filter out null values
    FinalResult = Table.SelectRows(SelectColumns, each [Value] <> null)
in
    FinalResult
```

## Output Columns
- **Sensor** - Virtual sensor name (from Sensor_ID)
- **Datetime** - Always "Default" 
- **Factor** - Calibration factor name (BW_LR_CH, CALC_CH, etc.)
- **Value** - Factor value (chainage or chord length)

## Factor Sources
- **Chord lengths** (CALC_ST_CHORD, CALC_LT_CHORD, CALC_VR_CHORD) - From named ranges (same for all sensors)
- **Chainages** (CALC_CH, *_CH values) - From Table_SensorAssignment (sensor-specific)

## Usage
Export this table to CSV and import into Sensly Calibrations section to configure all virtual sensor calibration factors.