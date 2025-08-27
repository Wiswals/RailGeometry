# Safe Logic Tests for Sensly

## Test 15: Avoid undefined variables entirely
```javascript
(CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z
```
Expected: Should return approximately 18.8055 (uses BW when behind, CL when ahead)

## Test 16: Full cant calculation with safe fallback
```javascript
((CALC_CH < CL_RR_CH) ? (CL_RR_Z + ((CL_RR_Z - BW_RR_Z) / (CL_RR_CH - BW_RR_CH)) * (CALC_CH - CL_RR_CH)) : CL_RR_Z) - ((CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z)
```
Expected: Should return approximately -0.0144 (before *1000)

## Test 17: With mm conversion
```javascript
(((CALC_CH < CL_RR_CH) ? (CL_RR_Z + ((CL_RR_Z - BW_RR_Z) / (CL_RR_CH - BW_RR_CH)) * (CALC_CH - CL_RR_CH)) : CL_RR_Z) - ((CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z)) * 1000
```
Expected: Should return approximately -14.4

This approach uses BW when behind CL, and falls back to CL elevation when ahead (avoiding undefined FW variables).