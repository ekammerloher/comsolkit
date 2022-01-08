function [faces_matrix] = vertices2faces (vertices_matrix)
    %this function recives vertices matrix for an 'n' lines polygon and
    %returnes the faces matrix - only works with extruded straight up polygons 
    wall_faces = zeros(length(vertices_matrix)/2,4);
    for i=1:(length(vertices_matrix)/2-1)
        wall_faces(i,:) = [i, i+1, i+1+length(vertices_matrix)/2, i+length(vertices_matrix)/2];
    end
    wall_faces (i+1,:) = [length(vertices_matrix)/2, 1, length(vertices_matrix)/2+1, length(vertices_matrix)];
    top_and_bottom_faces = [1:length(vertices_matrix)/2;length(vertices_matrix)/2+1:length(vertices_matrix)];
    %in a case that the tom and bottom faces are with less vertices then the walls    
    if length(vertices_matrix)/2<4
        faces_matrix =[wall_faces; top_and_bottom_faces, top_and_bottom_faces(:,1)];
    else
        for j=5:length(vertices_matrix)/2
            wall_faces(:,j) = wall_faces(:,1);
        end 
        faces_matrix = [wall_faces; top_and_bottom_faces]; 
    end
end