# Working Logic Tests for Sensly

## Test 11: Check if BW exists (should work)
```javascript
(BW_LR_Z > 0) ? 1 : 0
```
Expected: Should return 1

## Test 12: Check if FW exists (should fail gracefully)
```javascript
(FW_LR_Z > 0) ? 1 : 0
```
Expected: Should return 0 or blank

## Test 13: Combined logic using value checks
```javascript
(CALC_CH < CL_LR_CH && BW_LR_Z > 0) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : (FW_LR_Z > 0) ? (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z
```
Expected: Should return approximately 18.8055

## Test 14: Simple position-based logic (no null checks)
```javascript
(CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH))
```
Expected: Should fail because FW_LR_Z doesn't exist

Try Test 13 - using `> 0` instead of `!= null` for existence checks.