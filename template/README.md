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
