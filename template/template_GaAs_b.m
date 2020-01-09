%% Import and create.
import com.comsol.model.*
import com.comsol.model.util.*

model = ModelUtil.create('Model1');
mod1 = model.component.create('mod1', false);
geom1 = mod1.geom.create('geom1', 3);
geom1.lengthUnit('nm');
%% Define parameters.
% Geometric constants.
model.param.set('z_2DEG', '-90', 'zPosition of the 2DEG');
model.param.set('x_origin', '2.92e6', 'Origin of domain');
model.param.set('y_origin', '2.7456e6', 'Origin of domain');
model.param.set('h_hetero', '500', 'Height of lower domain');
model.param.set('h_vac', '500', 'Height of upper domain');
model.param.set('h_sweep', '20e3', 'Height of swept domain');
model.param.set('r_domain', '3000', 'Radius of domain');
model.param.set('r_cut', '22e3', 'Radius of boolean cut');

% Material properties.
model.param.set('epsilon_hetero', '13', 'Dielectric constant bottom');
model.param.set('epsilon_vac', '1', 'Dielectric constant top');

% Physical constants.
model.param.set('n0', '1.82e15 [1/m^2]', 'Chargedensity of 2DEG');
model.param.set('m_star', 'me_const*0.067', 'Effective mass');
model.param.set('dos', 'm_star/(hbar_const^2*pi)', 'Density of states');
model.param.set('E_f', 'hbar_const^2*pi*n0/m_star', 'Fermi energy');
model.param.set('V_D', '-10e-3 [V]', 'Drain bias voltage');

% Mesh parameters.
model.param.set('M_SZ_MAX', '150', 'Main max mesh size');
model.param.set('M_SZ_MIN', '1', 'Main min mesh size');
model.param.set('M_GROW', '1.4', 'Main growth rate');
model.param.set('M_2DEG_SZ_MAX', '40', '2DEG max mesh size');
%% Define geometry.
csel1 = geom1.selection.create('csel1', 'CumulativeSelection');
csel1.name('Gates');
% on comsolkit extrude feature do: .set('contributeto', 'csel1');
cyl1 = geom1.feature.create('cyl1', 'Cylinder');
cyl1.name('Domain');
cyl1.set('pos', {'x_origin' 'y_origin' '-h_hetero'});
cyl1.set('r', 'r_domain'); % Radius.
cyl1.set('h', 'h_hetero+h_vac'); % Height.
cyl1.set('layerside', false); % Per default enabled side layers.
cyl1.set('layerbottom', true); % Layers starting from the bottom.
cyl1.set('layer', {'h_hetero-abs(z_2DEG)' 'abs(z_2DEG)'});

% Create geometry mask for gates.
cyl2 = geom1.create('cyl2', 'Cylinder');
cyl2.name('DomainMaskOuter');
cyl2.set('pos', {'x_origin' 'y_origin' '-h_hetero'});
cyl2.set('r', 'r_cut');
cyl2.set('h', 'h_hetero+h_vac');
cyl3 = geom1.create('cyl3', 'Cylinder');
cyl3.name('DomainMaskInner');
cyl3.set('pos', {'x_origin' 'y_origin' '-h_hetero'});
cyl3.set('r', 'r_domain');
cyl3.set('h', 'h_hetero+h_vac');
dif1 = geom1.create('dif1', 'Difference');
dif1.name('DomainMask');
dif1.selection('input').set({'cyl2'});
dif1.selection('input2').set({'cyl3'});
% Gate creation goes here. Move dif2 to end.
dif2 = geom1.create('dif2', 'Difference');
dif2.name('TrimmedGates');
dif2.selection('input').named('csel1');
dif2.selection('input2').set({'dif1'});

% Create geometry for swept domains.
cyl4 = geom1.create('cyl4', 'Cylinder');
cyl4.name('SweepUpper');
cyl4.set('pos', {'x_origin' 'y_origin' 'h_hetero'});
cyl4.set('r', 'r_domain');
cyl4.set('h', 'h_sweep');
cyl5 = geom1.create('cyl5', 'Cylinder');
cyl5.name('SweepLower');
cyl5.set('pos', {'x_origin' 'y_origin' '-h_hetero-h_sweep'});
cyl5.set('r', 'r_domain');
cyl5.set('h', 'h_sweep');
geom1.run;
%% Define selections.
box1 = mod1.selection.create('box1', 'Box');
box1.set('zmin', 'z_2DEG');
box1.set('zmax', 'z_2DEG');
box1.set('entitydim', '2');
box1.set('condition', 'inside');
box1.name('2DEG');

box2 = mod1.selection.create('box2', 'Box');
box2.set('zmin', '0');
box2.set('condition', 'inside');
box2.name('Vacuum');

box3 = mod1.selection.create('box3', 'Box');
box3.set('zmax', '0');
box3.set('condition', 'inside');
box3.name('Hetero');

box4 = mod1.selection.create('box4', 'Box');
box4.set('zmin', 'z_2DEG');
box4.set('zmax', 0);
box4.set('condition', 'inside');
box4.name('2DEG_till_Gates');

dif1 = mod1.selection.create('dif1', 'Difference');
dif1.name('2DEG_wo_Drain');
dif1.set('entitydim', '2');
dif1.set('add', {'box1'});
%dif1.set('subtract', {'geom1_layer_wp21_bnd'});

box5 = mod1.selection.create('box5', 'Box');
box5.name('SweepLower');
box5.set('zmax', '-h_hetero');
box5.set('condition', 'inside');

box6 = mod1.selection.create('box6', 'Box');
box6.name('SweepUpper');
box6.set('zmin', 'h_vac');
box6.set('condition', 'inside');

box7 = mod1.selection.create('box7', 'Box');
box7.name('MainDomain');
box7.set('zmin', '-h_hetero');
box7.set('zmax', 'h_vac');
box7.set('condition', 'inside');

uni1 = mod1.selection.create('uni1', 'Union');
uni1.name('SweepDomain');
uni1.set('input', {'box5' 'box6'});
%% Define variables.
var1 = mod1.variable.create('var1');
var1.name('Default Variables');
var1.set('V_mod', '0 [V]');
var1.selection.named('dif1');
var2 = mod1.variable.create('var2');
var2.name('Drain Variables');
var2.set('V_mod', 'V_D');
var2.selection.geom('geom1', 2);
%var1.selection.named('geom1_layer_wp21_bnd');
%% Define materials.
mat1 = mod1.material.create('mat1');
mat1.materialModel('def').set('relpermittivity', {'epsilon_hetero'});
mat1.selection.named('box3');
mat1.name('Heterostruct');
mat2 = mod1.material.create('mat2');
mat2.materialModel('def').set('relpermittivity', {'epsilon_vac'});
mat2.selection.named('box2');
mat2.name('Vacuum');
%% Define physics.
es = mod1.physics.create('es', 'Electrostatics', 'geom1');
sfcd1 = es.feature.create('sfcd1', 'SurfaceChargeDensity', 2);
sfcd1.name('2DEG Charge Density');
sfcd1.set('rhoqs', ['-e_const*dos*(E_f+e_const*(V+V_mod))*' ...
                    '((V+V_mod)>-E_f/e_const)+' ...
                    'e_const*dos*E_f']);
sfcd1.selection.named('box1');
%% Define mesh.
mesh1 = mod1.mesh.create('mesh1', 'geom1');
size1 = mesh1.create('size1', 'Size');
size1.name('Size 2DEG');
size1.selection.named('box1');
size1.set('custom', 'on');
size1.set('hmax', 'M_2DEG_SZ_MAX');
size1.set('hmaxactive', true);
mesh1.feature('size').set('custom', 'on');
mesh1.feature('size').set('hmax', 'M_SZ_MAX');
mesh1.feature('size').set('hmin', 'M_SZ_MIN');
mesh1.feature('size').set('hnarrow', 0.1);
mesh1.feature('size').set('hgrad', 'M_GROW');
ftet = mesh1.feature.create('ftet', 'FreeTet');
ftet.selection.named('box7')

swe1 = mesh1.create('swe1', 'Sweep');
swe1.selection.named('uni1');
swe1.create('dis1', 'Distribution');

%mesh1.run;
%% Define study and solution.
std = model.study.create('std');
std.feature.create('stat', 'Stationary');
sol1 = model.sol.create('sol1');
sol1.study('std');
sol1.attach('std');
sol1.create('st1', 'StudyStep');
sol1.create('v1', 'Variables');
s1 = sol1.create('s1', 'Stationary');
s1.set('stol', '1e-9');
%s1.create('fc1', 'FullyCoupled');
i1 = s1.create('i1', 'Iterative');
i1.create('mg1', 'Multigrid');
%s1.feature.remove('fcDef');
i1.set('linsolver', 'cg');
i1.feature('mg1').set('prefun', 'amg');
%% Clear definition variables from workspace.
clear cyl1 box1 box2 box3 box4 box5 box6 box7 uni1 es geom1 mat1 mat2 mesh1 std ref1 sfcd1 var1 var2 sol1 s1 mod1 dif1 csel1 cyl2 cyl3 cyl4 cyl5 dif2 size1 i1 ftet swe1
%% Encapsulate model in comsolkit object.
gl = comsolkit.GateLayoutModel('FromTag', char(model.tag));
clear model
