/*
 * XYZ_PointAlongLine3DZ.pq
 * Calculates the Z coordinate of a point along a 3D line at a specified slope distance
 * 
 * Function Name: XYZ_PointAlongLine3DZ
 * Dependencies: XYZ_VerticalAngle.pq (XYZ_VerticalAngle)
 * 
 * Parameters: FromPointX, FromPointY, FromPointZ (number) - Starting point coordinates
 *            ToPointX, ToPointY, ToPointZ (number) - Ending point coordinates
 *            SlopeDist (number) - Slope distance along the line
 * Returns: Z coordinate of point at specified distance along line
 */

let
    XYZ_PointAlongLine3DZ = (FromPointX as number, FromPointY as number, FromPointZ as number, ToPointX as number, ToPointY as number, ToPointZ as number, SlopeDist as number) as number =>
    let
        // Vertical angle calculation
        Vangle = XYZ_VerticalAngle(FromPointX, FromPointY, FromPointZ, ToPointX, ToPointY, ToPointZ),

        // Z component
        ComponentZ = Number.Sin(Vangle * Number.PI / 180) * SlopeDist, // Convert Vangle to radians manually

        // Final result
        Result = ComponentZ + FromPointZ
    in
        Result
in
    XYZ_PointAlongLine3DZ