/*
 * Rail_Versine.pq
 * Calculates the versine (vertical offset) for a railway curve at a specific point
 * 
 * Function Name: Rail_Versine
 * Dependencies: None
 * Parameters: radius (number) - Curve radius in meters
 *            chordLength (number) - Total chord length in meters
 *            offsetFromMidChord (number) - Distance from chord midpoint in meters
 * Returns: Versine value in meters, or null if calculation is invalid
 */

let
    Rail_Versine = (radius as number, chordLength as number, offsetFromMidChord as number) as number =>
    let
        // Calculate half-chord length for geometric calculations
        halfChord = chordLength / 2,
        radiusSquared = Number.Power(radius, 2),

        // Compute terms for versine calculation using Pythagorean theorem
        term1 = radiusSquared - Number.Power(offsetFromMidChord, 2),
        term2 = radiusSquared - Number.Power(halfChord, 2),

        // Validate terms and calculate versine
        result = if term1 < 0 or term2 < 0 then 
                    null // Invalid geometry - return null
                else 
                    Number.Sqrt(term1) - Number.Sqrt(term2)
    in
        result
in
    Rail_Versine