/*
 * XYZ_PointAlongLine3DX.pq
 * Calculates the X coordinate of a point along a 3D line at a specified slope distance
 * 
 * Function Name: XYZ_PointAlongLine3DX
 * Dependencies: XY_Bearing.pq (XY_Bearing), XYZ_VerticalAngle.pq (XYZ_VerticalAngle)
 * 
 * Parameters: FromPointX, FromPointY, FromPointZ (number) - Starting point coordinates
 *            ToPointX, ToPointY, ToPointZ (number) - Ending point coordinates
 *            SlopeDist (number) - Slope distance along the line
 * Returns: X coordinate of point at specified distance along line
 */

let
    XYZ_PointAlongLine3DX = (FromPointX as number, FromPointY as number, FromPointZ as number, ToPointX as number, ToPointY as number, ToPointZ as number, SlopeDist as number) as number =>
    let
        // Bearing calculation
        Bearing = XY_Bearing(FromPointX, FromPointY, ToPointX, ToPointY),

        // Vertical angle calculation
        Vangle = XYZ_VerticalAngle(FromPointX, FromPointY, FromPointZ, ToPointX, ToPointY, ToPointZ),

        // Horizontal distance
        HorizDist = SlopeDist * Number.Cos(Vangle * Number.PI / 180), // Convert Vangle to radians manually

        // X component
        ComponentX = Number.Sin(Bearing * Number.PI / 180) * HorizDist, // Convert Bearing to radians manually

        // Final result
        Result = ComponentX + FromPointX
    in
        Result
in
    XYZ_PointAlongLine3DX