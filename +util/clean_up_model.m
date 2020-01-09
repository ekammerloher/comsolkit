function clean_up_model(model)
    % clean_up_model Remove all recreatable data from model and purge history.
    %
    % clean_up_model(model)

    % Based on Reclaim.java http://evgeni.org/oldfish/Script_for_clearing_Comsol_solution_data_in_all_your_MPH_files
    assert(isa(model, 'com.comsol.clientapi.impl.ModelClient'), 'model must be a Comsol ModelClient.');

    model.hist.disable(); % Do not accumelate history any more.
    model.resetHist();

    % Use java iterator, since sol has a java.lang.Iterable interface.
    itr = model.sol.iterator();
    while itr.hasNext()
        sol = itr.next();
        sol.clearSolution();
    end

    model.mesh.clearMeshes();
end
