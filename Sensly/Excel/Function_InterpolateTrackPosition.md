# Power Query Functions: Track Position Interpolation

## Purpose
Interpolates X,Y coordinates along track alignment based on chainage for accurate sensor positioning.

## Required Helper Functions

### BearingDD Function
```m
let
    BearingDD = (FromPointX as number, FromPointY as number, ToPointX as number, ToPointY as number) as nullable number =>
    let
        DiffE = ToPointX - FromPointX,
        DiffN = ToPointY - FromPointY,
        // If the provided eastings and northings are equal, return null.
        BearingCalc = if DiffE = 0 and DiffN = 0 then null 
                      else Number.Atan2(DiffE, DiffN) * (180 / Number.PI),
        // Adjust the bearing using modulo arithmetic.
        BearingAdjusted = if BearingCalc = null then null 
                          else Number.Mod(BearingCalc + 360, 360)
    in
        BearingAdjusted
in
    BearingDD
```

### PointAlongLine3DX Function
```m
let
    PointAlongLine3DX = (FromPointX as number, FromPointY as number, FromPointZ as number, ToPointX as number, ToPointY as number, ToPointZ as number, SlopeDist as number) as number =>
    let
        // Bearing calculation
        Bearing = BearingDD(FromPointX, FromPointY, ToPointX, ToPointY),
        
        // For horizontal interpolation, use slope distance directly as horizontal distance
        HorizDist = SlopeDist,
        
        // X component
        ComponentX = Number.Sin(Bearing * Number.PI / 180) * HorizDist,
        
        // Final result
        Result = ComponentX + FromPointX
    in
        Result
in
    PointAlongLine3DX
```

### PointAlongLine3DY Function
```m
let
    PointAlongLine3DY = (FromPointX as number, FromPointY as number, FromPointZ as number, ToPointX as number, ToPointY as number, ToPointZ as number, SlopeDist as number) as number =>
    let
        // Bearing calculation
        Bearing = BearingDD(FromPointX, FromPointY, ToPointX, ToPointY),
        
        // For horizontal interpolation, use slope distance directly as horizontal distance
        HorizDist = SlopeDist,
        
        // Y component
        ComponentY = Number.Cos(Bearing * Number.PI / 180) * HorizDist,
        
        // Final result
        Result = ComponentY + FromPointY
    in
        Result
in
    PointAlongLine3DY
```

### InterpolateRailPosition Function
```m
let
    InterpolateRailPosition = (ChainageList as table, TrackSide as text, PrismData as table) as table =>
    let
        // Extract chainages for the given track side
        chainages = Table.SelectRows(PrismData, each [Track Side] = TrackSide)[Track Chainage],
        
        // Find last chainage <= interpolated chainage
        withLast = Table.AddColumn(ChainageList, TrackSide & "_Last_CH", each 
            let matches = List.Select(chainages, (x) => x <= [Chainages]) 
            in if List.IsEmpty(matches) then null else List.Max(matches), type number),
        
        // Find next chainage >= interpolated chainage
        withNext = Table.AddColumn(withLast, TrackSide & "_Next_CH", each 
            let matches = List.Select(chainages, (x) => x >= [Chainages]) 
            in if List.IsEmpty(matches) then null else List.Min(matches), type number),
        
        // Join to get Last prism data
        mergeLast = Table.NestedJoin(withNext, {TrackSide & "_Last_CH"}, 
            Table.SelectRows(PrismData, each [Track Side] = TrackSide), {"Track Chainage"}, 
            TrackSide & "_Last", JoinKind.LeftOuter),
        expandLast = Table.ExpandTableColumn(mergeLast, TrackSide & "_Last", 
            {"X", "Y", "Z"}, {TrackSide & "_Last_X", TrackSide & "_Last_Y", TrackSide & "_Last_Z"}),
        
        // Join to get Next prism data
        mergeNext = Table.NestedJoin(expandLast, {TrackSide & "_Next_CH"}, 
            Table.SelectRows(PrismData, each [Track Side] = TrackSide), {"Track Chainage"}, 
            TrackSide & "_Next", JoinKind.LeftOuter),
        expandNext = Table.ExpandTableColumn(mergeNext, TrackSide & "_Next", 
            {"X", "Y", "Z"}, {TrackSide & "_Next_X", TrackSide & "_Next_Y", TrackSide & "_Next_Z"}),
        
        // Calculate interpolation distance
        withDist = Table.AddColumn(expandNext, TrackSide & "_Intp_Dist", each 
            [Chainages] - Record.Field(_, TrackSide & "_Last_CH")),
        
        // Interpolate X coordinate
        withX = Table.AddColumn(withDist, TrackSide & "_Intp_X", each 
            if Record.Field(_, TrackSide & "_Last_X") <> null and Record.Field(_, TrackSide & "_Next_X") <> null then
                PointAlongLine3DX(
                    Record.Field(_, TrackSide & "_Last_X"), 
                    Record.Field(_, TrackSide & "_Last_Y"), 
                    Record.Field(_, TrackSide & "_Last_Z"),
                    Record.Field(_, TrackSide & "_Next_X"), 
                    Record.Field(_, TrackSide & "_Next_Y"), 
                    Record.Field(_, TrackSide & "_Next_Z"),
                    Record.Field(_, TrackSide & "_Intp_Dist")
                )
            else null
        ),
        
        // Interpolate Y coordinate
        withY = Table.AddColumn(withX, TrackSide & "_Intp_Y", each 
            if Record.Field(_, TrackSide & "_Last_Y") <> null and Record.Field(_, TrackSide & "_Next_Y") <> null then
                PointAlongLine3DY(
                    Record.Field(_, TrackSide & "_Last_X"), 
                    Record.Field(_, TrackSide & "_Last_Y"), 
                    Record.Field(_, TrackSide & "_Last_Z"),
                    Record.Field(_, TrackSide & "_Next_X"), 
                    Record.Field(_, TrackSide & "_Next_Y"), 
                    Record.Field(_, TrackSide & "_Next_Z"),
                    Record.Field(_, TrackSide & "_Intp_Dist")
                )
            else null
        )
    in
        withY
in
    InterpolateRailPosition
```

## Usage
Create these as custom functions in Power Query, then use InterpolateRailPosition to get accurate X,Y coordinates for any chainage along the track alignment.