function gateTabOverlap = make3D(gateTab, extra_len, hard_Zpos)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %  Given an input gate table, this function returns a gate table
    %  that contains the shapes, locations and heights of all additional
    %  shapes required to define a 3D structure with multiple overlaps.
    %  gateTab has elements - gate name, gate Zpos, gate thickness and gate
    %  shape. The output gate table can directly be pipelined into comsol
    %  to simulate the output structure.
    %
    %  gateTabOut = getStructureMain(gateTabIn, 10, false)
    %
    %  Parameters:
    %  gateTab: An input gate table with columns - name, zPos, thickness,
    %           shape.
    %           The zPos is used only for ordering, so need not be exact,
    %           it will be decided by the function itself and output
    %           correctly. The thickness is the desired thickness of the
    %           gate, and the shape is the actual gate shape without 
    %           overlaps.
    %  extra_len: Either a positive number or -1. Enter same units as the 
    %             thickness if positive. If -1, the extra len is the same
    %             as the thickness. Default: -1
    %  hard_Zpos: Whether you want to enforce the zPos input along with the
    %             gate table or not. Default: false
    %
    % Example useage:
    %
    %for i =1:height(gateTabOut)
    %    uName = char(gateTabOut.name(i)+int2str(i)+int2str(i*2+1));
    %    if contains(gateTabOut.name(i), 'oxide')
    %        gl.add_layer({gateTabOut(i,:).shape.regions}, ...
    %                 uName,@comsolkit.Layer, ...
    %                 'Distance', gateTabOut(i,:).thickness, 'zPosition', gateTabOut(i,:).zPos, 'CumSel', 'oxide'); % Gate objects inherit from Layer. Layers live in gl.layerArray.
    %    else
    %        gl.add_layer({gateTabOut(i,:).shape.regions}, ...
    %                 uName, @comsolkit.Gate, ...
    %                 'Distance', gateTabOut(i,:).thickness, 'zPosition', gateTabOut(i,:).zPos, 'CumSel', char(gateTabOut.name(i)));
    %        
    %        if contains(gateTabOut.name(i), 'claviature_gate')
    %            
    %            idx = gateTabOut.name(i)
    %            regexp(idx, '\d*', 'Match');
    %            b = mod(str2num(regexp(idx, '\d*', 'Match')),4);
    %            name = char(strcat((regexprep(idx, '\d+$', '')), int2str(b)));
    %            gl.set_param(['v_' name], 0);
    %            gl.layerArray(i).voltage = ['v_' name];    
    %        elseif contains(gateTabOut.name(i), 'screening_gate')
    %            disp("Screening_gate");
    %            gl.set_param(['v_' char(gateTabOut.name(i))], 0);
    %            gl.layerArray(i).voltage = ['v_' char(gateTabOut.name(i))];
    %        else
    %            gl.set_param(['v_' char(gateTabOut.name(i))], 0);
    %            gl.layerArray(i).voltage = ['v_' char(gateTabOut.name(i))];
    %        end
    %    end
    %end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    tol = 1e-6;

    % Sorting the input table based on the zPos, getting all unique gate names.
    gateTab_sorted = sortrows(gateTab, 'zPos', 'ascend');
    gZpos_min = gateTab_sorted.zPos(1);
    gateObj = gateTab_sorted.shape;
    gatenames = gateTab.name;
    unq_gatenames = unique(gateTab.name);
    
    if nargin < 3
        hard_Zpos = false;
    end
    if nargin < 2
        extra_len = -1;
    end

    if ~hard_Zpos
        gateTab_sorted.zPos(:) = 0;
    end

    %Initializing output gate table, and passing the lowest gate directly into the output table
    gateTabOverlap = table.empty(0,4);
    gateTabOverlap.Properties.VariableNames=["name","zPos","thickness","shape"];
    gateTabOverlap = [gateTabOverlap; gateTab_sorted(1,:)];
    

    for i=2:length(gateObj)
        gateTab_out_overlap = table.empty(0,4);
        gateTab_out_overlap.Properties.VariableNames=["name","zPos","thickness","shape"];
    
        gateTab_out_extra = table.empty(0,4);
        gateTab_out_extra.Properties.VariableNames=["name","zPos","thickness","shape"];
    
        % Get overlaps, height of overlaps
        for j=1:height(gateTabOverlap)
            overlap = intersect(gateObj(i), gateTabOverlap.shape(j));
            if area(overlap) > 0
                gName = gateTab_sorted.name(i);
                gzPos = gateTabOverlap.zPos(j)+gateTabOverlap.thickness(j);
                gthickness = gateTab_sorted.thickness(i);
                if height(gateTab_out_overlap) > 0
                    % Check intersection with existing overlaps
                    for k=1:height(gateTab_out_overlap)
                        intersect_area = intersect(gateTab_out_overlap.shape(k), overlap);
                        if area(intersect_area) > 0
                            if (gzPos) > (gateTab_out_overlap.zPos(k))
                                gateTab_out_overlap.shape(k) = subtract(gateTab_out_overlap.shape(k), intersect_area);
                            else
                                overlap = subtract(overlap, intersect_area);
                            end
                        end
                    end
                end
                if area(overlap)>0
                    gate = {gName, gzPos, gthickness, overlap};
                    gateTab_out_overlap = [gateTab_out_overlap;gate];
                end
            end
        end
        idx_zeroarea = [];
        % Optimization - removing zero area shapes to speed up processing time.
        for j = 1:height(gateTab_out_overlap)
            if area(gateTab_out_overlap.shape(j)) == 0
                idx_zeroarea = [idx_zeroarea; j];
            end
        end
        gateTab_out_overlap(idx_zeroarea, :) = [];
        
        if isempty(gateTab_out_overlap.zPos)
            gateTab_sorted.zPos(i) = 0;
        else
            gateTab_sorted.zPos(i) = min(gateTab_out_overlap.zPos);
        end
        % Sort by height, descending (same thickness)
        gateTab_out_overlap = sortrows(gateTab_out_overlap, 'zPos', 'descend');
       
        % Combine gates at same height - to minimize number of table entries.
        gateTab_out_overlapCombined = table.empty(0,4);
        gateTab_out_overlapCombined.Properties.VariableNames=["name","zPos","thickness","shape"];
        zPosArray = unique(gateTab_out_overlap.zPos);
        for j=1:length(zPosArray)
            subtab = gateTab_out_overlap(gateTab_out_overlap.zPos==zPosArray(j),:);
            thicknessArray = unique(subtab.thickness);
            for k=1:length(thicknessArray)
               subtab3 = subtab(subtab.thickness==thicknessArray(k),:);
               if length(subtab3.shape)>1
                    ar_comb = union(subtab3.shape);
               else
                    ar_comb = subtab3.shape(1);
               end
               gate = {gateTab_sorted.name(i), zPosArray(j), thicknessArray(k), ar_comb};
               gateTab_out_overlapCombined = [gateTab_out_overlapCombined; gate];
            end
        
        end
        gateTab_out_overlap = gateTab_out_overlapCombined;
        gateTab_out_overlap = sortrows(gateTab_out_overlap, 'zPos', 'descend');
        
        % Extra material
        for j=1:height(gateTab_out_overlap)
            if extra_len >0
                overlap = polybuffer(gateTab_out_overlap.shape(j),extra_len,'JointType','miter','MiterLimit',2); 
            else
                overlap = polybuffer(gateTab_out_overlap.shape(j),gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2);
            end
            
            overlap = intersect(overlap, gateObj(i));
            extra_material = subtract(overlap, gateTab_out_overlap.shape(j));
            
            % To avoid rounding errors
            extra_material = polybuffer(extra_material,-0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2); 
            extra_material = polybuffer(extra_material,0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2);
            
            % If the extra material intersects with  an overlap region of
            % greater than or equal to height, we discard it
            zPos_j = gateTab_out_overlap.zPos(j);
            idx = max(find(gateTab_out_overlap.zPos == zPos_j));
            for k = 1:idx
                intersect_greater_height = intersect(extra_material, gateTab_out_overlap.shape(k));
                extra_material = subtract(extra_material, intersect_greater_height);
                extra_material = polybuffer(extra_material,-0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2); 
                extra_material = polybuffer(extra_material,0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2);
            
                a = 1;
            end
            
            for k = 1:height(gateTab_out_extra)
                intersect_extra = intersect(extra_material, gateTab_out_extra.shape(k));
                extra_material = subtract(extra_material, intersect_extra);
                extra_material = polybuffer(extra_material,-0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2); 
                extra_material = polybuffer(extra_material,0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2);
            
            end
            
            
            if area(extra_material) > 0
                gName = gateTab_sorted.name(i);
                
                
                extra_material_regions = [];
                for k = idx+1:height(gateTab_out_overlap)
                    intersect_lower_height = intersect(extra_material, gateTab_out_overlap.shape(k));
                    extra_material_regions = [extra_material_regions; intersect_lower_height];
                    extra_material = subtract(extra_material, intersect_lower_height);
                    extra_material = polybuffer(extra_material,-0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2); 
                    extra_material = polybuffer(extra_material,0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2);
            
                end
                
                for k =1:length(extra_material_regions)
                    gzPos = gateTab_sorted.zPos(i)+gateTab_sorted.thickness(i);
                    for l = 1:height(gateTabOverlap)
                        if (area(intersect(gateTabOverlap.shape(l), extra_material_regions(k))) > 0) && ((gateTabOverlap.zPos(l)+gateTabOverlap.thickness(l)) > gzPos)
                            gzPos = (gateTabOverlap.zPos(l)+gateTabOverlap.thickness(l));
                        end
                    end

                    gthickness = gateTab_out_overlap.zPos(j)+gateTab_out_overlap.thickness(j)-gzPos;

                    %disp(gName+" "+ gzPos+" "+ gthickness+" "+ gateTab_sorted.zPos(i)+" "+ gateTab_sorted.thickness(i)+" "+ gateTab_out_overlap.zPos(j)+" "+gateTab_out_overlap.thickness(j));
                    gate = {gName, gzPos, gthickness, simplify(extra_material_regions(k))};
                    gateTab_out_extra = [gateTab_out_extra;gate];
                end
                if area(extra_material)>0
                    gthickness = gateTab_out_overlap.thickness(j);
                    gzPos = gthickness;
                    gate = {gName, gzPos, gthickness, simplify(extra_material)};
                    gateTab_out_extra = [gateTab_out_extra;gate];
                end
            end
            
        end
       
        
        gateRemainingOriginal = gateTab_sorted(i,:);
        gateRemainingOriginal.zPos = 0;
        
        
        if height(gateTab_out_overlap)>0
            gateOverlapUnion = gateTab_out_overlap.shape(1);
            for j=2:height(gateTab_out_overlap)
                gateOverlapUnion = union(gateOverlapUnion, gateTab_out_overlap.shape(j));
            end
            gateRemainingOriginal.shape = subtract(gateRemainingOriginal.shape, gateOverlapUnion);
            
            %gateRemainingOriginal.shape = polybuffer(gateRemainingOriginal.shape,-0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2); 
            %gateRemainingOriginal.shape = polybuffer(gateRemainingOriginal.shape,0.05*gateTab_out_overlap.thickness(j),'JointType','miter','MiterLimit',2);
            
        end
        
        if ~isempty(gateTab_out_extra.shape)
            for j = 1:length(gateTab_out_extra.shape)
                gateTab_out_extra.shape(j) = polybuffer(gateTab_out_extra.shape(j),-0.05*gateTab_out_overlap.thickness(1),'JointType','miter','MiterLimit',2); 
                gateTab_out_extra.shape(j) = polybuffer(gateTab_out_extra.shape(j),0.05*gateTab_out_overlap.thickness(1),'JointType','miter','MiterLimit',2);

            end
        end

        gateTab_layer_i = [gateTab_out_overlap; gateTab_out_extra];
        
        % Combining gates to minimize number of table entries
        gateTab_layer_iCombined = table.empty(0,4);
        gateTab_layer_iCombined.Properties.VariableNames=["name","zPos","thickness","shape"];
        zPosArray = unique(gateTab_layer_i.zPos);
        for j=1:length(zPosArray)
            subtab = gateTab_layer_i(gateTab_layer_i.zPos==zPosArray(j),:);
            thicknessArray = unique(subtab.thickness);
            for k=1:length(thicknessArray)
               subtab3 = subtab(subtab.thickness==thicknessArray(k),:);
               if length(subtab3.shape)>1
                    ar_comb = union(subtab3.shape);
               else
                    ar_comb = subtab3.shape(1);
               end
               gate = {gateTab_sorted.name(i), zPosArray(j), thicknessArray(k), ar_comb};
               gateTab_layer_iCombined = [gateTab_layer_iCombined; gate];
            end
        end
        gateTab_layer_i = gateTab_layer_iCombined;
        gateTab_layer_i = sortrows(gateTab_layer_i, 'zPos', 'descend');
       
        
        if area(gateRemainingOriginal.shape) > 0
            gateTabOverlap = [gateTabOverlap; gateRemainingOriginal; gateTab_layer_i];
        else
            gateTabOverlap = [gateTabOverlap; gateTab_layer_i];
        end
    end
    for i = 1:length(gateTabOverlap.zPos)
        gateTabOverlap.zPos(i) = gateTabOverlap.zPos(i)+gZpos_min;
    end
end