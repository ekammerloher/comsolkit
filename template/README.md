# Template
This folder contains template Comsol files to work with comsolkit.

## General
A template file defines domains and materials, etc.

Since comsolkit is tag driven, some tags should be consistent in the template file (They are usually consitant anyway):

- The electrostatic physics feature should have the tag `'es'`
- The study feature used for comsolkit should have the tag `'std'`
- The stationary study feature should have the tag `'stat'`
- The potential is obtained by evaluating the expression `'mod1.V'`

When there are more then one geometry features (root feature containing the whole geometry tree), the first in the list is used.

## Parameter driven template
It is a good idea to define parts of a template, that might change depending on the situation using parameters (accessed by `set_param()` or `get_param()` in comsolkit).

There are particularly four parameters that are recommended: `origin_x`, `origin_y`, `l_domain`, `w_domain`. The function `comsolkit.GateLayoutModel.choose_domain_region()` prints commands you can use to set them. They define the domain region, where the model is typically solved. See template_GaAs.mph section for more details.

### template_GaAs.mph
A simple two block template, suspended in a infinite elements elepsoid.

#### Parameters
- `l_domain`: Length of domains
- `w_domain`: Width of domains
- `t_vac`: Thickness of upper domain (default: 500)
- `t_hetero`: Thickness of lower domain (default: 500)
- `origin_x`, `origin_y`: Coordinates of lower left point of domains (x,y)
- `epsilon_vac`: Dielectric constant of upper domain (default: 1)
- `epsilon_hetero`: Dielectric constant of lower domain (default: 13)
- `t_2DEG`: Depth of the 2DEG (default: -100)
- `charge_density`: Surface charge density at the 2DEG (default: 0)

#### Schematic
 ```
           (side view)
      ---------------------   /\
     |                     |  ||
     |     epsilon_vac     | t_vac     (upper domain)
     |                     |  ||
      ---------------------   \/ /\    (boundary at z=0)
     |                     |     ||
     |                     |     ||
      ---------------------      ||    (t_2DEG depth)
     |                     |     ||
     |    epsilon_hetero   |  t_hetero (lower domain)
     |                     |     ||
      ---------------------      \/

           (top view)
      ---------------------     /\
     |                     |    ||
     |                     |    ||
     |                     | w_domain
     |                     |    ||
     |                     |    ||
   x,+---------------------     \/
     y origin
      <------l_domain----->
```

### template_GaAs_basic_comsol44.mph
Same as `template_GaAs.mph` but can be opened with comsol 4.4. It does not contain an infinite elements ellipsoid surrounding the two blocks.

### Create template from scratch
It is possible to create a template just with LiveLink commands. The code below will recreate `template_GaAs.mph` (but without an infinite elements ellipsoid surrounding the two blocks).

```matlab
%% Import/create
import com.comsol.model.*
import com.comsol.model.util.*

model = ModelUtil.create('Model');
geom1 = model.geom.create('geom1', 3);
geom1.lengthUnit('nm');

%% Parameters
model.param.set('t_2DEG', '-100', 'zPosition of the 2DEG');
model.param.set('chargeDensity', '0', 'Surface charge density of 2DEG');
model.param.set('epsilon_hetero', '13', 'Dielectric constant of lower domain');
model.param.set('epsilon_vac', '1', 'Dielectric constant of upper domain');
model.param.set('l_domain', '3000', 'Length of domain');
model.param.set('origin_x', '30000', 'Origin of domain corner');
model.param.set('origin_y', '23400', 'Origin of domain corner');
model.param.set('t_hetero', '500', 'Height of lower domain');
model.param.set('t_vac', '500', 'Height of upper domain');
model.param.set('w_domain', '1200', 'Width of domain');
model.param.set('infinit_thickness', '100', 'Thickness of the infinite element layers');

%% Geometry
blk1 = geom1.feature.create('blk1', 'Block');
blk1.set('size', {'l_domain', 'w_domain', 't_vac'});
blk1.set('pos', {'origin_x', 'origin_y', '0'});
%blk1.set('createselection', 'on');
blk1.name('Vacuum');
blk2 = geom1.feature.create('blk2', 'Block');
blk2.set('size', {'l_domain', 'w_domain', 't_hetero'});
blk2.set('pos', {'origin_x', 'origin_y', '-t_hetero'});
%blk2.set('createselection', 'on');
blk2.setIndex('layer', 't_hetero+t_2DEG', 0);
blk2.name('Hetero');
geom1.run;

%% Selections
box1 = model.selection.create('box1', 'Box');
box1.set('zmin', 't_2DEG');
box1.set('zmax', 't_2DEG');
box1.set('entitydim', '2');
box1.set('condition', 'inside');
box1.name('2DEG');

box2 = model.selection.create('box2', 'Box');
box2.set('zmin', '0');
box2.set('condition', 'inside');
box2.name('Vacuum');

box3 = model.selection.create('box3', 'Box');
box3.set('zmax', '0');
box3.set('condition', 'inside');
box3.name('Hetero');

%% Materials
mat1 = model.material.create('mat1');
mat1.materialModel('def').set('relpermittivity', {'epsilon_hetero'});
mat1.selection.named('box3');
mat1.name('Heterostruct');
mat2 = model.material.create('mat2');
mat2.materialModel('def').set('relpermittivity', {'epsilon_vac'});
mat2.selection.named('box2');
mat2.name('Vacuum');

%% Physics
es = model.physics.create('es', 'Electrostatics', 'geom1');
es.feature.create('sfcd1', 'SurfaceChargeDensity', 2);
es.feature('sfcd1').set('rhoqs', 'chargeDensity');
es.feature('sfcd1').selection.named('box1');

%% Mesh
mesh1 = model.mesh.create('mesh1', 'geom1');
mesh1.feature.create('ftet', 'FreeTet');
mesh1.feature('size').set('hauto', 3);
mesh1.run;

%% Study
std = model.study.create('std');
std.feature.create('stat', 'Stationary');
```
