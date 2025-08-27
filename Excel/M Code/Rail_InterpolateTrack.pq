/*
 * Rail_InterpolateTrack.pq
 * Interpolates 3D track coordinates at specified chainages using linear interpolation between measured points
 * Finds the nearest measured points before and after each target chainage and calculates intermediate coordinates
 * 
 * Function Name: Rail_InterpolateTrack
 * Dependencies: XYZ_PointAlongLine3DX.pq (XYZ_PointAlongLine3DX), 
 *              XYZ_PointAlongLine3DY.pq (XYZ_PointAlongLine3DY), 
 *              XYZ_PointAlongLine3DZ.pq (XYZ_PointAlongLine3DZ),
 *              XYZ_Distance3D.pq (XYZ_Distance3D)
 * 
 * Parameters: ChainageList (table) - Table containing "Intp Chainage" column with target chainages
 *            TrackSide (text) - Track side identifier (e.g., "Left", "Right", "Center")
 *            PrismData (table) - Source data with columns: "Track Side", "Track Chainage", "Track X", "Track Y", "Track Z", "Epoch"
 * 
 * Returns: Table with original ChainageList data plus interpolated coordinates:
 *          - [TrackSide] Last CH - Chainage of nearest measured point before target
 *          - [TrackSide] Next CH - Chainage of nearest measured point after target
 *          - [TrackSide] Last/Next X/Y/Z/Epoch - Coordinates and metadata of bounding points
 *          - [TrackSide] Intp Dist - Distance from last point to interpolation point
 *          - [TrackSide] CH Span - Chainage span between bounding points
 *          - [TrackSide] Intp Ratio - Interpolation ratio (0-1)
 *          - [TrackSide] Slope Dist - 3D slope distance between bounding points
 *          - [TrackSide] Intp Slope Dist - Slope distance to interpolation point
 *          - [TrackSide] Intp X/Y/Z - Final interpolated 3D coordinates
 * 
 * Process: 1. Filters PrismData for specified TrackSide
 *         2. Finds bounding measured points for each target chainage
 *         3. Joins coordinate data for bounding points
 *         4. Calculates interpolation ratio based on chainage proportions
 *         5. Calculates 3D slope distance between bounding points
 *         6. Scales slope distance proportionally for interpolation
 *         7. Performs 3D linear interpolation using PointAlongLine3D functions
 */

let
    Rail_InterpolateTrack = (ChainageList as table, TrackSide as text, PrismData as table) as table =>
    let
        // Step 1: Extract chainages for the given track side
        chainages = Table.SelectRows(PrismData, each [Track Side] = TrackSide)[Track Chainage],
    
        // Step 2: Find the last chainage less than or equal to the interpolated chainage
        withLast = Table.AddColumn(ChainageList, TrackSide & " " & "Last CH", each 
            let matches = List.Select(chainages, (x) => x <= [Intp Chainage]) 
            in if List.IsEmpty(matches) then null else List.Max(matches), type number),
    
        // Step 3: Find the next chainage greater than or equal to the interpolated chainage
        withNext = Table.AddColumn(withLast, TrackSide & " " & "Next CH", each 
            let matches = List.Select(chainages, (x) => x >= [Intp Chainage]) 
            in if List.IsEmpty(matches) then null else List.Min(matches), type number),
    
        // Step 4: Join PrismData to get spatial data for the Last CH
        mergeLast = Table.NestedJoin(
            withNext, 
            {TrackSide & " " & "Last CH"}, 
            PrismData, 
            {"Track Chainage"}, 
            TrackSide & " " & "Last", 
            JoinKind.LeftOuter
        ),
        expandLast = Table.ExpandTableColumn(
            mergeLast, 
            TrackSide & " " & "Last", 
            {"Track X", "Track Y", "Track Z", "Epoch"}, 
            {
                TrackSide & " " & "Last X", 
                TrackSide & " " & "Last Y", 
                TrackSide & " " & "Last Z", 
                TrackSide & " " & "Last Epoch"
            }
        ),
    
        // Step 5: Join PrismData to get spatial data for the Next CH
        mergeNext = Table.NestedJoin(
            expandLast, 
            {TrackSide & " " & "Next CH"}, 
            PrismData, 
            {"Track Chainage"}, 
            TrackSide & " " & "Next", 
            JoinKind.LeftOuter
        ),
        expandNext = Table.ExpandTableColumn(
            mergeNext, 
            TrackSide & " " & "Next", 
            {"Track X", "Track Y", "Track Z", "Epoch"}, 
            {
                TrackSide & " " & "Next X", 
                TrackSide & " " & "Next Y", 
                TrackSide & " " & "Next Z", 
                TrackSide & " " & "Next Epoch"
            }
        ),
    
        // Step 6: Calculate chainage distance for interpolation
        withDist = Table.AddColumn(expandNext, TrackSide & " " & "Intp Dist", each 
            [Intp Chainage] - Record.Field(_, TrackSide & " " & "Last CH")),

        // Step 7: Calculate chainage span
        withSpan = Table.AddColumn(withDist, TrackSide & " " & "CH Span", each 
            Record.Field(_, TrackSide & " " & "Next CH") - Record.Field(_, TrackSide & " " & "Last CH")),

        // Step 8: Calculate interpolation ratio
        withRatio = Table.AddColumn(withSpan, TrackSide & " " & "Intp Ratio", each 
            if Record.Field(_, TrackSide & " " & "CH Span") = 0 then 0 
            else Record.Field(_, TrackSide & " " & "Intp Dist") / Record.Field(_, TrackSide & " " & "CH Span")),

        // Step 9: Calculate 3D slope distance between bounding points
        withSlopeDist = Table.AddColumn(withRatio, TrackSide & " " & "Slope Dist", each XYZ_Distance3D(
            Record.Field(_, TrackSide & " " & "Last X"), 
            Record.Field(_, TrackSide & " " & "Last Y"), 
            Record.Field(_, TrackSide & " " & "Last Z"),
            Record.Field(_, TrackSide & " " & "Next X"), 
            Record.Field(_, TrackSide & " " & "Next Y"), 
            Record.Field(_, TrackSide & " " & "Next Z")
        )),

        // Step 10: Calculate slope distance to interpolation point
        withIntpSlopeDist = Table.AddColumn(withSlopeDist, TrackSide & " " & "Intp Slope Dist", each 
            Record.Field(_, TrackSide & " " & "Intp Ratio") * Record.Field(_, TrackSide & " " & "Slope Dist")),

        // Step 11: Interpolate X
        withX = Table.AddColumn(withIntpSlopeDist, TrackSide & " " & "Intp X", each XYZ_PointAlongLine3DX(
            Record.Field(_, TrackSide & " " & "Last X"), 
            Record.Field(_, TrackSide & " " & "Last Y"), 
            Record.Field(_, TrackSide & " " & "Last Z"),
            Record.Field(_, TrackSide & " " & "Next X"), 
            Record.Field(_, TrackSide & " " & "Next Y"), 
            Record.Field(_, TrackSide & " " & "Next Z"),
            Record.Field(_, TrackSide & " " & "Intp Slope Dist")
        )),

        // Step 12: Interpolate Y
        withY = Table.AddColumn(withX, TrackSide & " " & "Intp Y", each XYZ_PointAlongLine3DY(
            Record.Field(_, TrackSide & " " & "Last X"), 
            Record.Field(_, TrackSide & " " & "Last Y"), 
            Record.Field(_, TrackSide & " " & "Last Z"),
            Record.Field(_, TrackSide & " " & "Next X"), 
            Record.Field(_, TrackSide & " " & "Next Y"), 
            Record.Field(_, TrackSide & " " & "Next Z"),
            Record.Field(_, TrackSide & " " & "Intp Slope Dist")
        )),

        // Step 13: Interpolate Z
        withZ = Table.AddColumn(withY, TrackSide & " " & "Intp Z", each XYZ_PointAlongLine3DZ(
            Record.Field(_, TrackSide & " " & "Last X"), 
            Record.Field(_, TrackSide & " " & "Last Y"), 
            Record.Field(_, TrackSide & " " & "Last Z"),
            Record.Field(_, TrackSide & " " & "Next X"), 
            Record.Field(_, TrackSide & " " & "Next Y"), 
            Record.Field(_, TrackSide & " " & "Next Z"),
            Record.Field(_, TrackSide & " " & "Intp Slope Dist")
        ))
    in
        withZ
in
    Rail_InterpolateTrack