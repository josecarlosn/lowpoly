No shader do addon Heightmap Terrain, modifique as linhas iniciais por essas:
(isso vai fazer a filtragem ser nearest)

uniform sampler2D u_ground_albedo_bump_0 : source_color, filter_nearest;
uniform sampler2D u_ground_albedo_bump_1 : source_color, filter_nearest;
uniform sampler2D u_ground_albedo_bump_2 : source_color, filter_nearest;
uniform sampler2D u_ground_albedo_bump_3 : source_color, filter_nearest;
