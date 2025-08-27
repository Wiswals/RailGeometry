# Power Query: Table_Virtual_Sensors

## Purpose
Generates virtual sensor locations at regular chainage intervals with properly formatted sensor IDs.

## Dependencies
Requires these named ranges in Excel:
- `Cell_CH_Start` - Starting chainage
- `Cell_CH_Finish` - Ending chainage  
- `Cell_CH_Step` - Chainage interval
- `Cell_Sensor_Naming` - Naming template (use * for chainage)

## Output Columns
- **Chainages** (number) - Calculation chainage for each sensor
- **Sensor_ID** (text) - Formatted sensor name with zero-padded chainage

## M Code
```m
let
    StartChainage = Excel.CurrentWorkbook(){[Name="Cell_CH_Start"]}[Content]{0}[Column1],
    FinishChainage = Excel.CurrentWorkbook(){[Name="Cell_CH_Finish"]}[Content]{0}[Column1],
    StepChainage = Excel.CurrentWorkbook(){[Name="Cell_CH_Step"]}[Content]{0}[Column1],
    
    ChainageList = List.Generate(
        () => StartChainage,
        each _ <= FinishChainage,
        each _ + StepChainage
    ),
    
    SensorNaming = Excel.CurrentWorkbook(){[Name="Cell_Sensor_Naming"]}[Content]{0}[Column1],
    MaxChainage = List.Max(ChainageList),
    
    // Determine decimal places needed
    HasDecimals = List.AnyTrue(List.Transform(ChainageList, each Number.Mod(_, 1) <> 0)),
    MaxDecimalPlaces = if HasDecimals then List.Max(List.Transform(ChainageList, each 
        let
            TextValue = Number.ToText(_),
            DecimalPos = Text.PositionOf(TextValue, "."),
            DecimalPlaces = if DecimalPos = -1 then 0 else Text.Length(TextValue) - DecimalPos - 1
        in
            DecimalPlaces
    )) else 0,
    
    // Format chainages with consistent decimal places
    FormattedChainages = List.Transform(ChainageList, each 
        if MaxDecimalPlaces = 0 then Number.ToText(_) 
        else Text.PadEnd(Number.ToText(_, "F" & Number.ToText(MaxDecimalPlaces)), 
            Text.Length(Number.ToText(_, "F" & Number.ToText(MaxDecimalPlaces))), "0")
    ),
    
    // Determine padding length for integer part only
    MaxIntegerLength = List.Max(List.Transform(ChainageList, each 
        let
            TextValue = Number.ToText(_),
            DecimalPos = Text.PositionOf(TextValue, "."),
            IntegerPart = if DecimalPos = -1 then TextValue else Text.Start(TextValue, DecimalPos)
        in
            Text.Length(IntegerPart)
    )),
    PaddingLength = List.Max({3, MaxIntegerLength}),
    
    ConvertToTable = Table.FromList(ChainageList, Splitter.SplitByNothing(), {"Chainages"}),
    AddSensorID = Table.AddColumn(ConvertToTable, "Sensor_ID", each 
        let
            FormattedChainage = if HasDecimals then 
                (if MaxDecimalPlaces = 0 then Number.ToText([Chainages], "F1") 
                 else Number.ToText([Chainages], "F" & Number.ToText(MaxDecimalPlaces)))
            else Number.ToText([Chainages]),
            
            PaddedChainage = if HasDecimals then
                let
                    DecimalPos = Text.PositionOf(FormattedChainage, "."),
                    IntegerPart = Text.Start(FormattedChainage, DecimalPos),
                    DecimalPart = Text.End(FormattedChainage, Text.Length(FormattedChainage) - DecimalPos),
                    PaddedInteger = Text.PadStart(IntegerPart, PaddingLength, "0")
                in
                    PaddedInteger & DecimalPart
            else
                Text.PadStart(FormattedChainage, PaddingLength, "0")
        in
            Text.Replace(SensorNaming, "*", PaddedChainage)
    ),
    ChangeType = Table.TransformColumnTypes(AddSensorID,{{"Chainages", type number}, {"Sensor_ID", type text}})
in
    ChangeType
```

## Features
- Handles decimal chainages with consistent formatting
- Zero-pads sensor IDs for proper sorting
- Configurable naming template with * placeholder
- Automatic decimal place detection and formatting