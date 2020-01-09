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

box4 = model.selection.create('box4', 'Box');
box4.set('zmin', 't_2DEG');
box4.set('zmax', 0);
box4.set('condition', 'inside');
box4.name('2DEG_till_Gates');


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
%mesh1.feature('size').set('hauto', 1);
mesh1.feature('size').set('custom', 'on');
mesh1.feature('size').set('hmax', 150);
mesh1.feature('size').set('hmin', 1);
mesh1.feature('size').set('hnarrow', 0.1);
mesh1.feature('size').set('hgrad', 1.5);

ref1 = mesh1.create('ref1', 'Refine');
ref1.selection.named('box4');
ref1.set('numrefine', 1);

mesh1.run;

%% Study
std = model.study.create('std');
std.feature.create('stat', 'Stationary');
%% Clear workspace
clear blk1 blk2 box1 box2 box3 box4 es geom1 mat1 mat2 mesh1 std
%% Comsolkit
gl = comsolkit.GateLayoutModel('FromTag', char(model.tag));
clear model
%%
gl.set_param('t_2DEG','-35'); %Depth of the 2DEG below the Gateinterface
gl.set_param('epsilon_vac', '11.3'); % constant for Al2O3

gl.set_param('origin_x', 418.301555);
gl.set_param('origin_y', 289.642176);
gl.set_param('l_domain', 1132.043829);
gl.set_param('w_domain', 1198.356020);
%%
m_star=0.19*util.const.m_e; %effective electron mass in silicon
dos=2*m_star/(2*pi*util.const.h_bar^2); % [1/(J*m^2)] silicon DOS 
E_g=1.11*util.const.e; % [J] silicon gap
q=-util.const.e;
E_vs=0.07*10^(-3).*util.const.e; % typical value of Valley Splitting in Si

gl.set_param('E_g', E_g);
gl.set_param('E_vs', E_vs);
gl.set_param('dos', dos);
gl.set_param('e', util.const.e);

clear m_star dos E_g q E_vs