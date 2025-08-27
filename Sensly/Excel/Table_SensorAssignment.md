# Power Query: Table_SensorAssignment

## Purpose
Assigns optimal prism selections to each virtual sensor based on chord geometry requirements and proximity to calculation chainage.

## Dependencies
- `Table_Virtual_Sensors` - Virtual sensor locations
- `Table_TrackData` - Available prism data
- Named ranges: `Cell_ST_Chord`, `Cell_LT_Chord`, `Cell_VR_Chord`, `Cell_Search_Threshold`

## Assignment Logic
1. **Central (CL)** - Closest to calculation chainage (no exclusions)
2. **Backward/Forward (BW/FW)** - ±½ versine chord from CL (exclude CL prisms)
3. **Short/Long Twist (ST/LT)** - Behind CL by twist chord lengths (exclude CL + FW prisms)

## Output Columns
- **Chainages**, **Sensor_ID** - From virtual sensors
- **Prism IDs** - CL_LR_ID, CL_RR_ID, BW_LR_ID, etc. (10 columns)
- **Coordinates** - All XYZ values for assigned prisms (30 columns)
- **Chainages** - Actual prism chainages for calibration (10 columns)

## M Code
```m
let
    // Load source data
    VirtualSensors = Table_Virtual_Sensors,
    TrackData = Table_TrackData,
    
    // Configuration parameters from named ranges
    ST_Chord = Excel.CurrentWorkbook(){[Name="Cell_ST_Chord"]}[Content]{0}[Column1],
    LT_Chord = Excel.CurrentWorkbook(){[Name="Cell_LT_Chord"]}[Content]{0}[Column1],
    VR_Chord = Excel.CurrentWorkbook(){[Name="Cell_VR_Chord"]}[Content]{0}[Column1],
    SearchThreshold = Excel.CurrentWorkbook(){[Name="Cell_Search_Threshold"]}[Content]{0}[Column1],
    
    // Prism selection function with exclusion logic
    FindClosestPrism = (TargetChainage as number, TrackSide as text, ExcludePrisms as list) as record =>
        let
            // Filter by rail side and exclude already assigned prisms
            FilteredPrisms = Table.SelectRows(TrackData, each 
                [Track Side] = TrackSide and 
                not List.Contains(ExcludePrisms, [Prism ID])
            ),
            
            // Calculate distances and apply search threshold
            AddDistance = Table.AddColumn(FilteredPrisms, "Distance", each 
                Number.Abs([Track Chainage] - TargetChainage)
            ),
            WithinThreshold = Table.SelectRows(AddDistance, each [Distance] <= SearchThreshold),
            
            // Return closest prism or null if none found
            SortedByDistance = Table.Sort(WithinThreshold, {{"Distance", Order.Ascending}}),
            ClosestPrism = if Table.RowCount(SortedByDistance) > 0 then 
                Table.First(SortedByDistance) else null
        in
            ClosestPrism,
    
    // Assign prisms to each virtual sensor
    AddPrismAssignments = Table.AddColumn(VirtualSensors, "Prism_Assignments", each
        let
            CALC_CH = [Chainages],
            
            // Calculate target chainages for each prism position
            CL_CH = CALC_CH,
            BW_CH = CALC_CH - (VR_Chord / 2),
            FW_CH = CALC_CH + (VR_Chord / 2),
            ST_CH = CALC_CH - ST_Chord,
            LT_CH = CALC_CH - LT_Chord,
            
            // Priority 1: Central prisms (highest priority, no exclusions)
            CL_LR = FindClosestPrism(CL_CH, "LR", {}),
            CL_RR = FindClosestPrism(CL_CH, "RR", {}),
            
            // Build exclusion list from central assignments
            CLExclusions = List.RemoveNulls({
                if CL_LR <> null then CL_LR[Prism ID] else null, 
                if CL_RR <> null then CL_RR[Prism ID] else null
            }),
            
            // Priority 2: Versine prisms (exclude central)
            BW_LR = FindClosestPrism(BW_CH, "LR", CLExclusions),
            BW_RR = FindClosestPrism(BW_CH, "RR", CLExclusions),
            FW_LR = FindClosestPrism(FW_CH, "LR", CLExclusions),
            FW_RR = FindClosestPrism(FW_CH, "RR", CLExclusions),
            
            // Priority 3: Twist prisms (exclude central + forward, can share with backward)
            FWExclusions = List.RemoveNulls({
                if FW_LR <> null then FW_LR[Prism ID] else null, 
                if FW_RR <> null then FW_RR[Prism ID] else null
            }),
            STLTExclusions = List.Combine({CLExclusions, FWExclusions}),
            
            ST_LR = FindClosestPrism(ST_CH, "LR", STLTExclusions),
            ST_RR = FindClosestPrism(ST_CH, "RR", STLTExclusions),
            LT_LR = FindClosestPrism(LT_CH, "LR", STLTExclusions),
            LT_RR = FindClosestPrism(LT_CH, "RR", STLTExclusions)
        in
            // Extract all required fields for each assigned prism
            [
                CL_LR_ID = if CL_LR <> null then CL_LR[Prism ID] else null, 
                CL_LR_X = if CL_LR <> null then CL_LR[X] else null, 
                CL_LR_Y = if CL_LR <> null then CL_LR[Y] else null, 
                CL_LR_Z = if CL_LR <> null then CL_LR[Z] else null, 
                CL_LR_CH = if CL_LR <> null then CL_LR[Track Chainage] else null,
                
                CL_RR_ID = if CL_RR <> null then CL_RR[Prism ID] else null, 
                CL_RR_X = if CL_RR <> null then CL_RR[X] else null, 
                CL_RR_Y = if CL_RR <> null then CL_RR[Y] else null, 
                CL_RR_Z = if CL_RR <> null then CL_RR[Z] else null, 
                CL_RR_CH = if CL_RR <> null then CL_RR[Track Chainage] else null,
                
                BW_LR_ID = if BW_LR <> null then BW_LR[Prism ID] else null, 
                BW_LR_X = if BW_LR <> null then BW_LR[X] else null, 
                BW_LR_Y = if BW_LR <> null then BW_LR[Y] else null, 
                BW_LR_Z = if BW_LR <> null then BW_LR[Z] else null, 
                BW_LR_CH = if BW_LR <> null then BW_LR[Track Chainage] else null,
                
                BW_RR_ID = if BW_RR <> null then BW_RR[Prism ID] else null, 
                BW_RR_X = if BW_RR <> null then BW_RR[X] else null, 
                BW_RR_Y = if BW_RR <> null then BW_RR[Y] else null, 
                BW_RR_Z = if BW_RR <> null then BW_RR[Z] else null, 
                BW_RR_CH = if BW_RR <> null then BW_RR[Track Chainage] else null,
                
                FW_LR_ID = if FW_LR <> null then FW_LR[Prism ID] else null, 
                FW_LR_X = if FW_LR <> null then FW_LR[X] else null, 
                FW_LR_Y = if FW_LR <> null then FW_LR[Y] else null, 
                FW_LR_Z = if FW_LR <> null then FW_LR[Z] else null, 
                FW_LR_CH = if FW_LR <> null then FW_LR[Track Chainage] else null,
                
                FW_RR_ID = if FW_RR <> null then FW_RR[Prism ID] else null, 
                FW_RR_X = if FW_RR <> null then FW_RR[X] else null, 
                FW_RR_Y = if FW_RR <> null then FW_RR[Y] else null, 
                FW_RR_Z = if FW_RR <> null then FW_RR[Z] else null, 
                FW_RR_CH = if FW_RR <> null then FW_RR[Track Chainage] else null,
                
                ST_LR_ID = if ST_LR <> null then ST_LR[Prism ID] else null, 
                ST_LR_X = if ST_LR <> null then ST_LR[X] else null, 
                ST_LR_Y = if ST_LR <> null then ST_LR[Y] else null, 
                ST_LR_Z = if ST_LR <> null then ST_LR[Z] else null, 
                ST_LR_CH = if ST_LR <> null then ST_LR[Track Chainage] else null,
                
                ST_RR_ID = if ST_RR <> null then ST_RR[Prism ID] else null, 
                ST_RR_X = if ST_RR <> null then ST_RR[X] else null, 
                ST_RR_Y = if ST_RR <> null then ST_RR[Y] else null, 
                ST_RR_Z = if ST_RR <> null then ST_RR[Z] else null, 
                ST_RR_CH = if ST_RR <> null then ST_RR[Track Chainage] else null,
                
                LT_LR_ID = if LT_LR <> null then LT_LR[Prism ID] else null, 
                LT_LR_X = if LT_LR <> null then LT_LR[X] else null, 
                LT_LR_Y = if LT_LR <> null then LT_LR[Y] else null, 
                LT_LR_Z = if LT_LR <> null then LT_LR[Z] else null, 
                LT_LR_CH = if LT_LR <> null then LT_LR[Track Chainage] else null,
                
                LT_RR_ID = if LT_RR <> null then LT_RR[Prism ID] else null, 
                LT_RR_X = if LT_RR <> null then LT_RR[X] else null, 
                LT_RR_Y = if LT_RR <> null then LT_RR[Y] else null, 
                LT_RR_Z = if LT_RR <> null then LT_RR[Z] else null, 
                LT_RR_CH = if LT_RR <> null then LT_RR[Track Chainage] else null
            ]
    ),
    
    // Expand record into individual columns (IDs first, then coordinates/chainages)
    ExpandPrismData = Table.ExpandRecordColumn(AddPrismAssignments, "Prism_Assignments", {
        // Prism ID columns
        "CL_LR_ID", "CL_RR_ID", "BW_LR_ID", "BW_RR_ID", "FW_LR_ID", "FW_RR_ID",
        "ST_LR_ID", "ST_RR_ID", "LT_LR_ID", "LT_RR_ID",
        
        // Coordinate and chainage columns
        "CL_LR_X", "CL_LR_Y", "CL_LR_Z", "CL_LR_CH",
        "CL_RR_X", "CL_RR_Y", "CL_RR_Z", "CL_RR_CH",
        "BW_LR_X", "BW_LR_Y", "BW_LR_Z", "BW_LR_CH",
        "BW_RR_X", "BW_RR_Y", "BW_RR_Z", "BW_RR_CH",
        "FW_LR_X", "FW_LR_Y", "FW_LR_Z", "FW_LR_CH",
        "FW_RR_X", "FW_RR_Y", "FW_RR_Z", "FW_RR_CH",
        "ST_LR_X", "ST_LR_Y", "ST_LR_Z", "ST_LR_CH",
        "ST_RR_X", "ST_RR_Y", "ST_RR_Z", "ST_RR_CH",
        "LT_LR_X", "LT_LR_Y", "LT_LR_Z", "LT_LR_CH",
        "LT_RR_X", "LT_RR_Y", "LT_RR_Z", "LT_RR_CH"
    }),
    
    // Handle any errors by replacing with null values
    CleanErrors = Table.ReplaceErrorValues(ExpandPrismData, 
        List.Transform(Table.ColumnNames(ExpandPrismData), each {_, null})
    ),
    
    // Add concatenated prism list for parent sensors (after error handling)
    AddPrismList = Table.AddColumn(CleanErrors, "Parent_Sensors", each 
        let
            ValidPrisms = List.RemoveNulls({
                [CL_LR_ID], [CL_RR_ID], [BW_LR_ID], [BW_RR_ID], [FW_LR_ID], [FW_RR_ID],
                [ST_LR_ID], [ST_RR_ID], [LT_LR_ID], [LT_RR_ID]
            }),
            UniquePrisms = List.Distinct(ValidPrisms)
        in
            if List.Count(UniquePrisms) = 0 then null else Text.Combine(UniquePrisms, "|")
    )
in
    AddPrismList
```

## Key Features
- **Smart exclusion logic** prevents prism conflicts between positions
- **Priority-based assignment** ensures critical positions get best prisms
- **Distance threshold filtering** prevents unrealistic assignments
- **Comprehensive output** includes all 44 parameters needed for Sensly