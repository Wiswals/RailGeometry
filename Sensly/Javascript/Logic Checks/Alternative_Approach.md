# Alternative Approach - Separate Formulas

Since Sensly can't handle references to undefined variables, you might need separate formulas for different scenarios:

## Formula 1: When you have BW data (your current case)
```javascript
(((CALC_CH < CL_RR_CH) ? (CL_RR_Z + ((CL_RR_Z - BW_RR_Z) / (CL_RR_CH - BW_RR_CH)) * (CALC_CH - CL_RR_CH)) : CL_RR_Z) - ((CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z)) * 1000
```

## Formula 2: When you have FW data (for end of track)
```javascript
(((CALC_CH >= CL_RR_CH) ? (CL_RR_Z + ((FW_RR_Z - CL_RR_Z) / (FW_RR_CH - CL_RR_CH)) * (CALC_CH - CL_RR_CH)) : CL_RR_Z) - ((CALC_CH >= CL_LR_CH) ? (CL_LR_Z + ((FW_LR_Z - CL_LR_Z) / (FW_LR_CH - CL_LR_CH)) * (CALC_CH - CL_LR_CH)) : CL_LR_Z)) * 1000
```

## Formula 3: Fallback when only CL data exists
```javascript
(CL_RR_Z - CL_LR_Z) * 1000
```

## Test 24: Check if this approach works
Try Formula 1 in your current setup - it should give -14.4 mm.

You might need to configure different sensors with different formulas based on what data is available, rather than trying to handle all cases in one formula.