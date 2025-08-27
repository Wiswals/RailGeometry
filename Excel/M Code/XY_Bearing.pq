/*
 * XY_Bearing.pq
 * Calculates the horizontal bearing between two points in degrees
 * 
 * Function Name: XY_Bearing
 * Dependencies: None
 * 
 * Parameters: FromPointX, FromPointY (number) - Starting point coordinates
 *            ToPointX, ToPointY (number) - Ending point coordinates
 * Returns: Horizontal bearing in degrees (0-360), or null if points are identical
 */

let
    XY_Bearing = (FromPointX as number, FromPointY as number, ToPointX as number, ToPointY as number) as nullable number =>
    let
        DiffE = ToPointX - FromPointX,
        DiffN = ToPointY - FromPointY,
        // If the provided eastings and northings are equal, return null.
        BearingCalc = if DiffE = 0 and DiffN = 0 then null 
                      else Number.Atan2(DiffE, DiffN) * (180 / Number.PI),
        // Adjust the bearing using modulo arithmetic.
        BearingAdjusted = if BearingCalc = null then null 
                          else Number.Mod(BearingCalc + 360, 360)
    in
        BearingAdjusted
in
    XY_Bearing