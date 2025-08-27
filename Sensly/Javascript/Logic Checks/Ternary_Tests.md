# Ternary Operator Tests for Sensly

## Test 1: Basic Ternary
```javascript
(CALC_CH < CL_LR_CH) ? 1 : 2
```
Expected: Should return 1 (since 49 < 49.6498)

## Test 2: Ternary with Variables
```javascript
(CALC_CH < CL_LR_CH) ? CL_LR_Z : BW_LR_Z
```
Expected: Should return 18.808 (CL_LR_Z value)

## Test 3: Ternary with Calculation
```javascript
(CALC_CH < CL_LR_CH) ? (CL_LR_Z * 1000) : (BW_LR_Z * 1000)
```
Expected: Should return 18808

## Test 4: Nested Ternary
```javascript
(CALC_CH < CL_LR_CH) ? (CL_LR_Z - BW_LR_Z) : (FW_LR_Z - CL_LR_Z)
```
Expected: Should return 0.023 (18.808 - 18.785)

## Test 5: Your Original Logic Structure
```javascript
(CALC_CH < CL_LR_CH) ? (CL_LR_Z + ((CL_LR_Z - BW_LR_Z) / (CL_LR_CH - BW_LR_CH)) * (CALC_CH - CL_LR_CH)) : 999
```
Expected: Should return approximately 18.8055

Try these one by one to see where the ternary operators break down in Sensly.