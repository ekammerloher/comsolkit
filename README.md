![comsolkit](/doc/logo.png?raw=true)
Wrapper around the LiveLink™ for MATLAB® Interface of COMSOL Multiphysics®, tailored for gate layout optimisation in heterostructures.

# Requirements
- (optinal, for gds-import) Configured https://github.com/ulfgri/gdsii-toolbox (requires mex-file compilation, ask me)
- COMSOL Multiphysics® LiveLink™ for MATLAB® (tested with Version **5.0**)
- At least MATLAB® **2014b**

# Installation
1. Clone the repository or download and extract the zip-file version.
2. Rename `comsolkit/` to `+comsolkit/` and put the parent folder on the Matlab PATH (this is a Matlab package).
3. From the gdsii-toolbox put only the `Basic/` folder (with subfolders) on the Matlab PATH (rest of the toolbox is not required).
4. Enshure Comsol LiveLink files are on the Matlab path (`installdir/COMSOL/COMSOLxx/Multiphysics/mli`)

# Usage
- Ensure a Comsol server is running (`comsolmphserver.exe` locally or a remote server, see `help comsolkit.GateLayoutModel.server_connect` for connection options)
- comsolkit syncs changes both ways. Change features in Comsol or properties in Matlab, it will stay in sync
- Check out the [workflow.m](workflow.m) script. It contains one possible workflow.
- All classes, constructors and methods are fully documented. Try `help <functionname>` to understand their behaviour
- For an overview of classes try, e.g. `doc comsolkit.GateLayoutModel` or `doc comsolkit.Gate`
- Calling the objects without semicolon reveals the porperties, which gives a good overview as well
- It is recomended to start out from a template Comsol model and use comsolkit to work on it. templates are provided in [tempate/](template/). See the [README](template/README.md) of the template folder.
- See [Troubleshooting](https://github.com/ekammerloher/comsolkit/wiki/Troubleshooting) for common issues.

# Structure
comsolkit is tag driven. Properties are internally accessed by tag from the corresponding Comsol features. All features created by comsolkit in Comsol have a tag prefix `'layer_'`.

A base class [comsolkit.ComsolModel](ComsolModel.m) handles saving/loading and model management tasks.

[comsolkit.LayeredModel](LayeredModel.m) inherits from `comsolkit.ComsolModel` and adds the property `layerArray` and functionality to mange this array.

Objects of the class [comsolkit.Layer](Layer.m) populate `layerArray`. They bundle a workplane and extrude feature in Comsol together and have functionallity to mange their geometric aspects.

[comsolkit.GateLayoutModel](GateLayoutModel.m) inherits from `comsolkit.LayeredModel` and adds functions to work with electrostatic problems and import gds-files to generate a gate layout by populating `layerArray` with `comsolkit.Gate` objects.

The [comsolkit.Gate](Gate.m) class inherits from `comsolkit.Layer` and adds funcionality to mangage electric potentials.

# Philosophy
This project aims to supplement your workflow in Comsol from Matlab. It is not intended to replicate the exelent LiveLink for Matlab. Just streamline the specific process of gate layout creation, manipulation and optimization. For this reasons other important aspects of a general Comsol workflow like meshing, etc. should be done using the default LiveLink from Matlab or the Comsol GUI.

# Coding Conventions
The code is written in a style based on http://www.ee.columbia.edu/~marios/matlab/MatlabStyle1p5.pdf

Briefly: properties (camel case starting with a lower case letter), constants (upper case seperated by underscore), functions (lower case seperated by underscore), classes ( camel case starting with an upper case letter).



*MATLAB, COMSOL Multiphysics are registered trademark of The MathWorks, Inc and COMSOL Inc. respectively. All other trademarks are the property of their respective owners.*
