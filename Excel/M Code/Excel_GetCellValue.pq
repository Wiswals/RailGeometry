/*
 * Get_CellValue.pq
 * Retrieves a single cell value from a named range in the current Excel workbook
 * 
 * Function Name: Get_CellValue
 * Dependencies: None
 * 
 * Parameters: namedRange (text) - The name of the Excel named range
 * Returns: The first cell value from the specified named range
 */

let
    Get_CellValue = (namedRange as text) => 
    let
        // Get the content from the named range in current workbook
        sourceTable = Excel.CurrentWorkbook(){[Name = namedRange]}[Content],
        // Extract the first cell value from the table
        cellValue = Table.ToList(sourceTable){0}
    in
        cellValue
in
    Get_CellValue