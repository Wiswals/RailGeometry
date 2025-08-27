# Track Geometry Parameter Computation Requirements

## Prism Location Diagram

```
Direction of Travel →

          LT          BW                    ST        CL                        FW
          ↓           ↓                     ↓         ↓                         ↓
─ ─ ─ ─[LT_LR]─ ─ ─[BW_LR]─ ─ ─ ─ ─ ─ ─ ─[ST_LR]─ ─[CL_LR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─[FW_LR]─ ─ ─ ─     ← Left Rail
          │           │                     │         │                         │
          │           │                     │         │                         │
─ ─ ─ ─[LT_RR]─ ─ ─[BW_RR]─ ─ ─ ─ ─ ─ ─ ─[ST_RR]─ ─[CL_RR]─ ─ ─ ─ ─ ─ ─ ─ ─ ─[FW_RR]─ ─ ─ ─     ← Right Rail
          ↑           ↑                     ↑         ↑                         ↑
          LT          BW                    ST        CL                        FW

Legend:
CL = Central (parent sensor location)
BW = Backward (½ chord behind CL)
FW = Forward (½ chord ahead of CL)
ST = Short Twist (short chord behind CL)
LT = Long Twist (long chord behind CL)
```

### Important Notes

**Chord Length Variability**: This diagram represents a generic setup. Depending on actual chord and twist lengths configured for each project, the positioning and arrangement of LT, BW, and ST may change significantly. The actual spacing between prism positions will vary based on the specific measurement requirements and rail standards being applied.

**Prism Alignment**: The diagram depicts an idealized situation where left rail and right rail prisms are perfectly aligned with each other across the track. In reality, prisms are likely to be staggered along the track alignment due to practical installation constraints, existing infrastructure, and site-specific conditions.

## Parameter-Specific Prism Usage

| Parameter | Prisms Used | Diagram Reference |
|-----------|-------------|-------------------|
| Cant | CL only | CL_LR, CL_RR |
| Gauge | CL only | CL_LR, CL_RR |
| Short Twist | CL + ST | CL_LR/RR + ST_LR/RR |
| Long Twist | CL + LT | CL_LR/RR + LT_LR/RR |
| Top Left | BW + CL + FW | BW_LR + CL_LR + FW_LR |
| Top Right | BW + CL + FW | BW_RR + CL_RR + FW_RR |
| Line Left | BW + CL + FW | BW_LR + CL_LR + FW_LR |
| Line Right | BW + CL + FW | BW_RR + CL_RR + FW_RR |

## Detailed Parameter Requirements

### 1. Cant Computation
**Required Prisms**: Central position only
- `central_LR_x`, `central_LR_y`, `central_LR_z`
- `central_RR_x`, `central_RR_y`, `central_RR_z`

**Computation**: Cross-level difference between left and right rail at current position
**Outputs**: `central_cant`, `cant_deviation`, `cant_absolute_value`

### 2. Gauge Computation  
**Required Prisms**: Central position only
- `central_LR_x`, `central_LR_y`, `central_LR_z`
- `central_RR_x`, `central_RR_y`, `central_RR_z`

**Computation**: 3D distance between rail heads at current position
**Outputs**: `gauge`, `gauge_deviation`, `gauge_absolute_value`

### 3. Short Twist Computation
**Required Prisms**: Central + Short chord positions
- Central: `central_LR_x`, `central_LR_y`, `central_LR_z`, `central_RR_x`, `central_RR_y`, `central_RR_z`
- Short: `short_twist_LR_x`, `short_twist_LR_y`, `short_twist_LR_z`, `short_twist_RR_x`, `short_twist_RR_y`, `short_twist_RR_z`

**Computation**: Difference between central cant and short twist cant
**Outputs**: `short_twist`, `short_twist_deviation`, `short_twist_absolute_value`

### 4. Long Twist Computation
**Required Prisms**: Central + Long chord positions  
- Central: `central_LR_x`, `central_LR_y`, `central_LR_z`, `central_RR_x`, `central_RR_y`, `central_RR_z`
- Long: `long_twist_LR_x`, `long_twist_LR_y`, `long_twist_LR_z`, `long_twist_RR_x`, `long_twist_RR_y`, `long_twist_RR_z`

**Computation**: Difference between central cant and long twist cant
**Outputs**: `long_twist`, `long_twist_deviation`, `long_twist_absolute_value`

### 5. Top (Vertical Alignment) Computation
**Required Prisms**: Backward + Central + Forward positions (calculated separately for each rail)
- Left Rail: `backward_LR_x`, `backward_LR_y`, `backward_LR_z`, `central_LR_x`, `central_LR_y`, `central_LR_z`, `forward_LR_x`, `forward_LR_y`, `forward_LR_z`
- Right Rail: `backward_RR_x`, `backward_RR_y`, `backward_RR_z`, `central_RR_x`, `central_RR_y`, `central_RR_z`, `forward_RR_x`, `forward_RR_y`, `forward_RR_z`

**Computation**: Vertical versine deviation from grade line over chord length (separate calculation for left and right rails)
**Outputs**: `LR_top`, `LR_top_deviation`, `LR_top_absolute_value`, `RR_top`, `RR_top_deviation`, `RR_top_absolute_value`

### 6. Line (Horizontal Alignment) Computation
**Required Prisms**: Backward + Central + Forward positions (calculated separately for each rail)
- Left Rail: `backward_LR_x`, `backward_LR_y`, `backward_LR_z`, `central_LR_x`, `central_LR_y`, `central_LR_z`, `forward_LR_x`, `forward_LR_y`, `forward_LR_z`
- Right Rail: `backward_RR_x`, `backward_RR_y`, `backward_RR_z`, `central_RR_x`, `central_RR_y`, `central_RR_z`, `forward_RR_x`, `forward_RR_y`, `forward_RR_z`

**Computation**: Horizontal versine deviation from chord line over chord length (separate calculation for left and right rails)
**Outputs**: `LR_line`, `LR_line_deviation`, `LR_line_absolute_value`, `RR_line`, `RR_line_deviation`, `RR_line_absolute_value`

## Chord Length Definitions
- **Short Twist Chord**: Typically 3-5 meters
- **Long Twist Chord**: Typically 10-20 meters  
- **Line/Top Chord**: Configurable, commonly 10-20 meters
- **Half Chord**: Line/Top chord length ÷ 2

## Implementation Priority
1. **Phase 1**: Cant & Gauge (simplest - only central prisms)
2. **Phase 2**: Short & Long Twist (add twist chord positions)
3. **Phase 3**: Line & Top (add backward + forward positions)