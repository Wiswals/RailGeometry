/*
 * XY_RefLinePerpHzOffset.pq
 * Calculates the perpendicular horizontal offset from a point to a reference line
 * 
 * Function Name: XY_RefLinePerpHzOffset
 * Dependencies: None
 * Positive values indicate offset to the right of the line direction, negative to the left
 * Parameters: lineStartX, lineStartY (number) - Start coordinates of reference line
 *            lineEndX, lineEndY (number) - End coordinates of reference line
 *            pointX, pointY (number) - Coordinates of point to measure offset from
 * Returns: Signed perpendicular distance from point to line
 */

let
    XY_RefLinePerpHzOffset = (lineStartX as number, lineStartY as number, lineEndX as number, lineEndY as number, pointX as number, pointY as number) as number =>
    let
        // Calculate line slope and y-intercept for standard line equation
        lineSlope = (lineEndY - lineStartY) / (lineEndX - lineStartX),
        yIntercept = lineEndY - (lineEndX * lineSlope),
        
        // Determine offset direction using cross product
        offsetSign = (pointX - lineStartX) * (lineEndY - lineStartY) - (pointY - lineStartY) * (lineEndX - lineStartX),
        
        // Handle zero offset case to avoid division by zero
        effectiveSign = if offsetSign = 0 then 1 else offsetSign,
        
        // Calculate perpendicular distance using point-to-line formula
        offsetDistance = Number.Abs(lineSlope * pointX + (-1 * pointY) + yIntercept) / 
                        Number.Sqrt(lineSlope * lineSlope + 1),
 
        // Handle vertical line case separately
        perpHzOffset = 
        if lineEndX - lineStartX = 0 then
            // For vertical lines, offset is simply horizontal distance
            if lineEndY - lineStartY > 0 then
                pointX - lineStartX  // Line goes up, positive offset to right
            else
                lineStartX - pointX  // Line goes down, positive offset to left
        else
            // Apply sign to distance based on which side of line point is on
            offsetDistance * effectiveSign / Number.Abs(effectiveSign)
 
    in
        perpHzOffset
in
    XY_RefLinePerpHzOffset