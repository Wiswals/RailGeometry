# Robust Logic Tests for Sensly

## Test 18: Check if BW exists safely
```javascript
(BW_LR_Z > -999) ? 1 : 0
```
Expected: Should return 1 if BW exists, 0 if undefined

## Test 19: Safe BW check in calculation
```javascript
(CALC_CH < CL_LR_CH && BW_LR_Z > -999) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z
```
Expected: Should use BW gradient if BW exists and behind CL, otherwise just CL elevation

## Test 20: Full robust cant calculation
```javascript
(((CALC_CH < CL_RR_CH && BW_RR_Z > -999) ? (CL_RR_Z + ((CL_RR_Z - BW_RR_Z) / (CL_RR_CH - BW_RR_CH)) * (CALC_CH - CL_RR_CH)) : CL_RR_Z) - ((CALC_CH < CL_LR_CH && BW_LR_Z > -999) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z)) * 1000
```
Expected: Should return -14.4 when BW exists, -15 when BW is undefined

This approach:
- Uses BW gradient when behind CL AND BW exists
- Falls back to CL elevation when BW doesn't exist or when ahead of CL
- Should handle all edge cases safely