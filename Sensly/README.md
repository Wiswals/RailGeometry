# Rail Geometry Sensly Implementation Project

This project contains the complete workflow for implementing rail track geometry calculations in the Sensly platform, from theoretical planning through to practical deployment.

## Project Structure

### 📁 Reference/
**Purpose**: Theoretical foundation and implementation planning documentation

Contains the core technical specifications and methodologies for rail geometry parameter calculations:

- **Chainage_Calibration_Approach.md** - Defines how to handle real-world prism positioning variations using fixed chainage calibration and scaling factors
- **Parameter_Computation_Requirements.md** - Complete specification of all 8 track geometry parameters (cant, gauge, twist, line, top) including prism requirements and calculation methods
- **Prism_Naming_Convention.md** - Standardized naming system for the 30 coordinate inputs required by Sensly (5 positions × 2 rails × 3 coordinates)
- **Rail_Interpolation_Blueprint.md** - High-level implementation blueprint for parent/child sensor relationships in Sensly
- **Sensly_Implementation_Guide.md** - Detailed Sensly configuration guide with all 30 input variables and 8 output parameters

**Key Concepts**:
- 5 prism positions: Central (CL), Backward (BW), Forward (FW), Short Twist (ST), Long Twist (LT)
- 2 rails: Left Rail (LR), Right Rail (RR)
- Chainage-based calibration for real-world installation flexibility
- Parent sensor computes parameters using child sensor XYZ inputs

### 📁 Javascript/
**Purpose**: Mathematical formulas ready for Sensly implementation

Contains the actual calculation formulas converted to JavaScript format for direct use in Sensly:

- **Cant_Calculation_Formula.md** - Detailed cant calculation methodology with gradient correction
- **Cant_JavaScript_Formula.md** - Ready-to-use JavaScript implementations including single-line format for Sensly math expressions

**Implementation Formats**:
- Full JavaScript functions for testing/validation
- Sensly math expression format (ternary operators)
- Single-line compact formulas for direct copy-paste into Sensly

**Status**: Currently contains cant calculation only - additional parameters (gauge, twist, line, top) to be added as formulas are developed.

### 📁 Excel/
**Purpose**: Data staging and Sensly configuration file generation

Working environment for processing prism survey data and generating Sensly setup files:

- **Excel_Data_Mapping_Tables.md** - Configuration parameter tables and Power Query code for generating virtual sensor locations
- **Prism_Assignment_Query.md** - Advanced Power Query logic for automatically assigning real prism data to virtual sensor positions
- **Testing/** subfolder - Contains test data files and calibration examples

**Key Functions**:
- Stages raw prism survey data (XYZ coordinates with chainages)
- Generates virtual sensor locations at regular intervals
- Automatically assigns closest real prisms to each virtual sensor position
- Creates complete Sensly configuration files with all 44 parameters (30 coordinates + 10 chainages + 4 configuration)
- Handles prism exclusion logic to prevent double-assignment

**Power Query Capabilities**:
- Configurable chainage ranges and intervals
- Automatic sensor naming with zero-padding
- Distance-based prism selection with threshold limits
- Smart exclusion logic to optimize prism usage across multiple sensors

## Workflow Overview

1. **Planning Phase** (Reference folder)
   - Define calculation requirements and prism positioning
   - Establish naming conventions and calibration approach
   - Plan Sensly sensor architecture

2. **Formula Development** (Javascript folder)
   - Convert mathematical formulas to JavaScript
   - Test and validate calculations
   - Format for Sensly implementation

3. **Data Processing** (Excel folder)
   - Import survey prism data
   - Generate virtual sensor grid
   - Assign prisms to sensors using optimization logic
   - Export Sensly configuration files

4. **Sensly Implementation**
   - Create child sensors for each prism
   - Configure parent sensors with 44 input parameters
   - Implement JavaScript formulas for parameter calculations
   - Deploy and validate system

## Current Status

- ✅ **Reference documentation**: Complete theoretical framework
- ✅ **Excel data processing**: Full Power Query automation for prism assignment
- 🔄 **JavaScript formulas**: Cant calculation complete, other parameters in development
- ⏳ **Sensly deployment**: Awaiting formula completion

## Next Steps

1. Complete remaining JavaScript formulas (gauge, twist, line, top)
2. Test formulas with real survey data
3. Generate Sensly configuration files from Excel
4. Deploy and validate in Sensly platform