/*
 * XY_Radius2D.pq
 * Calculates the radius of a circle passing through three 2D points
 * 
 * Function Name: XY_Radius2D
 * Dependencies: None
 * Uses the circumradius formula for a triangle formed by the three points
 * Parameters: x1, y1 (number) - Coordinates of first point
 *            x2, y2 (number) - Coordinates of second point
 *            x3, y3 (number) - Coordinates of third point
 * Returns: Radius of the circumscribed circle
 */

let
    XY_Radius2D = (x1 as number, y1 as number, x2 as number, y2 as number, x3 as number, y3 as number) as number =>
    let
        // Calculate side lengths of triangle formed by the three points
        sideA = Number.Sqrt(Number.Power((x2 - x1), 2) + Number.Power((y2 - y1), 2)),
        sideB = Number.Sqrt(Number.Power((x3 - x2), 2) + Number.Power((y3 - y2), 2)),
        sideC = Number.Sqrt(Number.Power((x1 - x3), 2) + Number.Power((y1 - y3), 2)),

        // Apply circumradius formula: R = (abc) / (4 * Area)
        // Area calculated using Heron's formula in denominator
        radius = (sideA * sideB * sideC) / Number.Sqrt((sideA + sideB + sideC) * (sideB + sideC - sideA) * (sideA + sideC - sideB) * (sideA + sideB - sideC))
    in
        radius
in
    XY_Radius2D