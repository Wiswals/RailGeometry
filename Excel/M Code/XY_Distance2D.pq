/*
 * XY_Distance2D.pq
 * Calculates the 2D Euclidean distance between two points
 * 
 * Function Name: XY_Distance2D
 * Dependencies: None
 * Parameters: fromPointX (number) - X coordinate of starting point
 *            fromPointY (number) - Y coordinate of starting point
 *            toPointX (number) - X coordinate of ending point
 *            toPointY (number) - Y coordinate of ending point
 * Returns: 2D distance between the two points
 */

let
    XY_Distance2D = (fromPointX as number, fromPointY as number, toPointX as number, toPointY as number) as number =>
    let
        // Calculate coordinate differences
        deltaX = toPointX - fromPointX,
        deltaY = toPointY - fromPointY,
        // Apply Pythagorean theorem for 2D distance
        distance = Number.Sqrt(Number.Power(deltaX, 2) + Number.Power(deltaY, 2))
    in
        distance
in
    XY_Distance2D