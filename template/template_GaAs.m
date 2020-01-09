%% Import/create
import com.comsol.model.*
import com.comsol.model.util.*

model = ModelUtil.create('Model');
geom1 = model.geom.create('geom1', 3);
geom1.lengthUnit('nm');

%% Parameters
model.param.set('t_2DEG', '-100', 'zPosition of the 2DEG');
model.param.set('l_domain', '3000', 'Length of domain');
model.param.set('origin_x', '30000', 'Origin of domain corner');
model.param.set('origin_y', '23400', 'Origin of domain corner');
model.param.set('t_hetero', '500', 'Height of lower domain');
model.param.set('t_vac', '500', 'Height of upper domain');
model.param.set('w_domain', '1200', 'Width of domain');

model.param.set('epsilon_hetero', '13', 'Dielectric constant of lower domain');
model.param.set('epsilon_vac', '1', 'Dielectric constant of upper domain');

model.param.set('n0', '1e15 [1/m^2]', 'Charges per square meter of 2DEG');
model.param.set('m_star', 'me_const*0.067', 'Effective mass');
model.param.set('dos', 'm_star/(hbar_const^2*pi)', 'Density of states');
model.param.set('E_f', 'hbar_const^2*pi*n0/m_star', 'Fermi energy');

model.param.set('V_D', '-10e-3 [V]', 'Drain bias voltage');
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
sfcd1 = es.feature.create('sfcd1', 'SurfaceChargeDensity', 2);
sfcd1.set('rhoqs', '-e_const*n0');
sfcd1.selection.named('box1');
sfcd2 = es.feature.create('sfcd2', 'SurfaceChargeDensity', 2);
sfcd2.set('rhoqs', '-e_const*dos*(E_f+ e_const*V)*(V>-E_f/e_const) + e_const*dos*E_f');
%sfcd2.selection.named('box1');
sfcd3 = es.feature.create('sfcd3', 'SurfaceChargeDensity', 2);
sfcd3.set('rhoqs', '-e_const*dos*(E_f+ e_const*(V+V_D))*((V+V_D)>-E_f/e_const) + e_const*dos*E_f');
%sfcd3.selection.named('box1');

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
clear blk1 blk2 box1 box2 box3 box4 es geom1 mat1 mat2 mesh1 std ref1 sfcd1 sfcd2 sfcd3
%% Comsolkit
gl = comsolkit.GateLayoutModel('FromTag', char(model.tag));
clear model
%%
path = '\\janeway\User AG Bluhm\Kammerloher\PhD\fabrication\ASD04\asd_04_Ebeam_small.dxf';
[~,polylines,~,~,~] = matlab_exchange.f_LectDxf(path);
gl.batch_add_layer(cellfun(@(c) {c.*1e3}, polylines(:,1), 'UniformOutput', false), {}, comsolkit.GateLayoutModel.DEFAULT_GATE_CLASS, 'zPosition', -100, 'Distance', 30);

gl.set_param('origin_x', 2917130);
gl.set_param('origin_y', 2743876);
gl.set_param('l_domain', 2902);
gl.set_param('w_domain', 3351);
%%
gl.batch_remove_layer(1,numel(polylines(:,1)));
%%
layout = polyshape(cellfun(@(c) c(:,1).*1e3, polylines(:,1), 'UniformOutput', false), cellfun(@(c) c(:,2).*1e3, polylines(:,1), 'UniformOutput', false), 'SolidBoundaryOrientation', 'cw').regions;
mask = polyshape([str2double(gl.get_param('origin_x')) str2double(gl.get_param('origin_x')) str2double(gl.get_param('origin_x'))+str2double(gl.get_param('l_domain')) str2double(gl.get_param('origin_x'))+str2double(gl.get_param('l_domain'))], [str2double(gl.get_param('origin_y')) str2double(gl.get_param('origin_y'))+str2double(gl.get_param('w_domain')) str2double(gl.get_param('origin_y'))+str2double(gl.get_param('w_domain')) str2double(gl.get_param('origin_y'))]);
%%
g = polyshape.empty;
for p=layout(:)'
    new_p = p.intersect(mask);
    if new_p.NumRegions ~= 0
       g(end+1) = new_p;
    end
end
%%
gl.batch_add_layer(cellfun(@(c) {c}, {g.Vertices}, 'UniformOutput', false), {}, comsolkit.GateLayoutModel.DEFAULT_GATE_CLASS, 'zPosition', -100, 'Distance', 30);