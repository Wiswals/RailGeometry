# Sensly Support Request: Conditional Logic with Undefined Variables

## Issue Summary
When using ternary operators in Sensly math expressions, any reference to undefined/null input variables causes the entire formula to return blank, even when the conditional logic should prevent those variables from being evaluated.

## Business Case
We need robust conditional formulas for rail geometry calculations that can handle missing sensor data gracefully. Our calculations require different gradient references (backward/forward prisms) depending on sensor position and data availability.

## Test Results Conducted

### ✅ Working Tests
- **Basic ternary**: `(CALC_CH < CL_LR_CH) ? 1 : 2` → Returns 1 ✓
- **Ternary with existing variables**: `(CALC_CH < CL_LR_CH) ? CL_LR_Z : BW_LR_Z` → Returns 18.808 ✓
- **Ternary with calculations**: `(CALC_CH < CL_LR_CH) ? (CL_LR_Z * 1000) : (BW_LR_Z * 1000)` → Returns 18808 ✓
- **Complex calculation in ternary**: `(CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : 999` → Returns 18.805 ✓

### ❌ Failing Tests
- **Ternary with undefined variable**: `(CALC_CH < CL_LR_CH) ? (CL_LR_Z - BW_LR_Z) : (FW_LR_Z - CL_LR_Z)` → Returns blank ❌
- **Null checks**: `(FW_LR_Z != null) ? 1 : 0` → Returns blank ❌
- **Conditional with undefined fallback**: Any formula referencing FW_LR_Z (which doesn't exist) → Returns blank ❌

### Key Findings
1. **Ternary operators work** when all referenced variables exist
2. **Undefined variable references** cause entire formula failure, even in conditional branches that shouldn't execute
3. **Null checks fail** when variables are truly undefined/missing
4. **No safe existence checking** method found for undefined input variables

## Required Formula Logic
```javascript
// Desired logic that currently fails:
(CALC_CH < CL_LR_CH && BW_LR_Z exists) ? 
    // Use backward gradient
    (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) :
(FW_LR_Z exists) ?
    // Use forward gradient  
    (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH)) :
    // Fallback to no gradient
    CL_LR_Z
```

## Current Workaround Limitations
- Must use separate formulas for different data scenarios
- Cannot create robust single formula handling all edge cases
- Requires complex sensor configuration management

## Requested Solutions
1. **Fix**: Allow conditional logic to prevent evaluation of undefined variable branches
2. **Enhancement**: Provide safe existence checking functions (e.g., `ISDEFINED(variable)`, `HASVALUE(variable)`)
3. **Alternative**: Suggest Sensly-compatible approach for handling optional input variables in math expressions

## Impact
This limitation prevents implementation of robust rail geometry monitoring systems that must handle varying sensor coverage and occasional sensor failures gracefully.