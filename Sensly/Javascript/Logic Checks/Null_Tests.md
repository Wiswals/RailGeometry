# Null Handling Tests for Sensly

## Test 6: Check if FW exists
```javascript
FW_LR_Z
```
Expected: Should show null, undefined, or blank

## Test 7: Null check in ternary
```javascript
(FW_LR_Z != null) ? 1 : 0
```
Expected: Should return 0

## Test 8: Alternative null check
```javascript
(typeof FW_LR_Z !== 'undefined') ? 1 : 0
```
Expected: Should return 0

## Test 9: Working ternary with null fallback
```javascript
(CALC_CH < CL_LR_CH && BW_LR_Z != null) ? (CL_LR_Z - BW_LR_Z) : 999
```
Expected: Should return 0.023

## Test 10: Full logic test
```javascript
(CALC_CH < CL_LR_CH && BW_LR_Z != null) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : (FW_LR_Z != null) ? (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH)) : 999
```
Expected: Should return approximately 18.8055

Test these to see how Sensly handles null values in ternary operators.