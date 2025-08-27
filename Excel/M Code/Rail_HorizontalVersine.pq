/*
 * Rail_HorizontalVersine.pq
 * Calculates horizontal versine from three XY points forming a chord
 * 
 * Function Name: Rail_HorizontalVersine
 * Dependencies: XY_Radius2D.pq (XY_Radius2D), XY_RefLinePerpHzOffset.pq (XY_RefLinePerpHzOffset), Rail_Versine.pq (Rail_Versine)
 * Parameters: startX, startY (number) - XY coordinates of chord start point
 *            midX, midY (number) - XY coordinates of chord middle point
 *            endX, endY (number) - XY coordinates of chord end point
 *            chordLength (number) - Total chord length
 *            offsetFromMidChord (number) - Distance from chord midpoint
 * Returns: Horizontal versine value
 */

let
    Rail_HorizontalVersine = (startX as number, startY as number, midX as number, midY as number, endX as number, endY as number, chordLength as number, offsetFromMidChord as number) as number =>
    let
        // Calculate radius from three points
        radius = XY_Radius2D(startX, startY, midX, midY, endX, endY),
        
        // Calculate perpendicular offset from chord line to middle point
        perpOffset = XY_RefLinePerpHzOffset(startX, startY, endX, endY, midX, midY),
        
        // Calculate versine using existing versine function
        versineRaw = Rail_Versine(radius, chordLength, offsetFromMidChord),
        
        // Apply sign based on which side of chord the point lies
        result = if versineRaw = null then 
                    0
                else if perpOffset > 0 then 
                    versineRaw * -1
                else 
                    versineRaw
    in
        result
in
    Rail_HorizontalVersine