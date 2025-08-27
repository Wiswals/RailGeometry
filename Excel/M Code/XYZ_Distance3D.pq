/*
 * XYZ_Distance3D.pq
 * Calculates the 3D Euclidean distance between two points
 * 
 * Function Name: XYZ_Distance3D
 * Dependencies: None
 * Parameters: fromPointX (number) - X coordinate of starting point
 *            fromPointY (number) - Y coordinate of starting point
 *            fromPointZ (number) - Z coordinate of starting point
 *            toPointX (number) - X coordinate of ending point
 *            toPointY (number) - Y coordinate of ending point
 *            toPointZ (number) - Z coordinate of ending point
 * Returns: 3D distance between the two points
 */

let
    XYZ_Distance3D = (fromPointX as number, fromPointY as number, fromPointZ as number, 
                  toPointX as number, toPointY as number, toPointZ as number) as number =>
    let
        // Calculate coordinate differences
        deltaX = toPointX - fromPointX,
        deltaY = toPointY - fromPointY,
        deltaZ = toPointZ - fromPointZ, // Fixed: was using fromPointZ twice
        // Apply Pythagorean theorem for 3D distance
        distance = Number.Sqrt(Number.Power(deltaX, 2) + Number.Power(deltaY, 2) + Number.Power(deltaZ, 2))
    in
        distance
in
    XYZ_Distance3D