/*
 * Rail_VerticalVersine.pq
 * Calculates vertical versine from three XYZ points by projecting to vertical plane
 * 
 * Function Name: Rail_VerticalVersine
 * Dependencies: XY_Distance2D.pq (XY_Distance2D), XY_Radius2D.pq (XY_Radius2D), XY_RefLinePerpHzOffset.pq (XY_RefLinePerpHzOffset), Rail_Versine.pq (Rail_Versine)
 * Parameters: startX, startY, startZ (number) - XYZ coordinates of chord start point
 *            midX, midY, midZ (number) - XYZ coordinates of chord middle point
 *            endX, endY, endZ (number) - XYZ coordinates of chord end point
 *            chordLength (number) - Total chord length
 *            offsetFromMidChord (number) - Distance from chord midpoint
 * Returns: Vertical versine value
 */

let
    Rail_VerticalVersine = (startX as number, startY as number, startZ as number, midX as number, midY as number, midZ as number, endX as number, endY as number, endZ as number, chordLength as number, offsetFromMidChord as number) as number =>
    let
        // Calculate 2D distances from start point to create horizontal positions
        startHorizontal = 0,
        midHorizontal = XY_Distance2D(startX, startY, midX, midY),
        endHorizontal = XY_Distance2D(startX, startY, endX, endY),
        
        // Calculate radius using horizontal distance as X and Z as Y
        radius = XY_Radius2D(startHorizontal, startZ, midHorizontal, midZ, endHorizontal, endZ),
        
        // Calculate perpendicular offset from chord line to middle point
        perpOffset = XY_RefLinePerpHzOffset(startHorizontal, startZ, endHorizontal, endZ, midHorizontal, midZ),
        
        // Calculate versine using existing versine function
        versineRaw = Rail_Versine(radius, chordLength, offsetFromMidChord),
        
        // Apply sign based on which side of chord the point lies
        result = if versineRaw = null then 
                    0
                else if perpOffset < 0 then 
                    versineRaw * -1
                else 
                    versineRaw
    in
        result
in
    Rail_VerticalVersine