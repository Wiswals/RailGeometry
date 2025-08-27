/*
 * Rail_Twist.pq
 * Calculates twist (rate of change of cant) between two cant measurements
 * 
 * Function Name: Rail_Twist
 * Dependencies: None
 * Parameters: cantCurrent (number) - Cant value at current position
 *            cantReference (number) - Cant value at reference position
 * Returns: Twist value (difference between cant measurements)
 */

let
    Rail_Twist = (cantCurrent as number, cantReference as number) as number =>
    let
        // Calculate twist as difference between current and reference cant
        twist = cantCurrent - cantReference
    in
        twist
in
    Rail_Twist