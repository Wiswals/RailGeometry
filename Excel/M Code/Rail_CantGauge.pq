/*
 * Rail_CantGauge.pq
 * Calculates cant (cross-level) and gauge measurements between two rail points
 * 
 * Function Name: Rail_CantGauge
 * Dependencies: XYZ_Distance3D.pq (XYZ_Distance3D)
 * Parameters: leftX, leftY, leftZ (number) - XYZ coordinates of left rail
 *            rightX, rightY, rightZ (number) - XYZ coordinates of right rail
 * Returns: Record with cant and gauge measurements
 */

let
    Rail_CantGauge = (leftX as number, leftY as number, leftZ as number, rightX as number, rightY as number, rightZ as number) as record =>
    let
        // Calculate cant (left rail Z - right rail Z)
        cant = leftZ - rightZ,
        
        // Calculate gauge using 3D distance between rail positions
        gauge = XYZ_Distance3D(leftX, leftY, leftZ, rightX, rightY, rightZ),
        
        // Return results as record
        result = [Cant = cant, Gauge = gauge]
    in
        result
in
    Rail_CantGauge