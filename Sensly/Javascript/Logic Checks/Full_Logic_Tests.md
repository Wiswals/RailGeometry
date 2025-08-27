# Full BW/FW Logic Tests for Sensly

## Test 21: Check both BW and FW existence
```javascript
(BW_LR_Z > -999) ? 1 : (FW_LR_Z > -999) ? 2 : 0
```
Expected: Should return 1 (BW exists), 2 (only FW exists), or 0 (neither)

## Test 22: Smart gradient selection
```javascript
(CALC_CH < CL_LR_CH && BW_LR_Z > -999) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : (FW_LR_Z > -999) ? (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z
```
Expected: Should use BW when behind CL and BW exists, otherwise try FW, otherwise CL

## Test 23: Full cant with BW/FW logic
```javascript
(((CALC_CH < CL_RR_CH && BW_RR_Z > -999) ? (CL_RR_Z + ((CL_RR_Z - BW_RR_Z) / (CL_RR_CH - BW_RR_CH)) * (CALC_CH - CL_RR_CH)) : (FW_RR_Z > -999) ? (CL_RR_Z + ((FW_RR_Z - CL_RR_Z) / (FW_RR_CH - CL_RR_CH)) * (CALC_CH - CL_RR_CH)) : CL_RR_Z) - ((CALC_CH < CL_LR_CH && BW_LR_Z > -999) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : (FW_LR_Z > -999) ? (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z)) * 1000
```

This logic:
1. If behind CL and BW exists → use BW gradient
2. Else if FW exists → use FW gradient  
3. Else → use CL elevation (no gradient)

Try Test 23 - this should handle all your cases robustly.