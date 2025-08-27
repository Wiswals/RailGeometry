/*
 * XYZ_VerticalAngle.pq
 * Calculates the vertical angle between two 3D points in degrees
 * 
 * Function Name: XYZ_VerticalAngle
 * Dependencies: XY_Distance2D.pq (XY_Distance2D)
 * 
 * Parameters: FromPointX, FromPointY, FromPointZ (number) - Starting point coordinates
 *            ToPointX, ToPointY, ToPointZ (number) - Ending point coordinates
 * Returns: Vertical angle in degrees, or null if points are identical
 */

let
    XYZ_VerticalAngle = (FromPointX as number, FromPointY as number, FromPointZ as number, ToPointX as number, ToPointY as number, ToPointZ as number) as nullable number =>
    let
        // Calculate the easting, northing, and height coordinate differences
        DiffE = ToPointX - FromPointX,
        DiffN = ToPointY - FromPointY,
        DiffH = ToPointZ - FromPointZ,

        // Calculate the horizontal distance (2D distance) between the points
        HzDist = XY_Distance2D(FromPointX, FromPointY, ToPointX, ToPointY),

        // Check if the distance is valid (i.e., non-zero)
        Vangle = 
            if HzDist = 0 then 
                if ToPointZ = FromPointZ then 
                    null 
                else if ToPointZ > FromPointZ then 
                    0
                else 
                    180
            else
                let
                    // Calculate the vertical angle using atan2 (in radians)
                    VangleCalc = Number.Atan2(DiffH, HzDist),

                    // Convert the result from radians to degrees
                    VangleInDegrees = VangleCalc * (180 / Number.PI)
                in
                    VangleInDegrees
    in
        Vangle
in
    XYZ_VerticalAngle