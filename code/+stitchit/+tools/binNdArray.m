function [ data ] = binNdArray(data, binSize, binType, verbose, resolution)
%BINNDARRAY Bin an array
%
% function [ data ] = binNdArray(data, binSize, binType, verbose)
%
% Inputs:
% - data: a nd array
% - binSize: integer or vector of integer. If an integer is given,
% the first two dimension of data are binned by that amount. If a
% vector is given, each dimension of data is binned by the
% corresponding value
% - binType: How to group data. Must be a string in {'mean', 'min',
%   'max', 'sum'} or a cell array of such strings with the same
% numel as binSize. Default: 'mean'.
% - verbose: integer controlling level of verbosity.
% - resolution: 'native' or 'double' for sum and mean. Should I
% perform the calculus in native resolution (default) or upcast to
% double before averaging. Output will then be double.
%
% Binning is done sequentially dimension by dimension.
debug = false;
tic();
    if ~exist('binType', 'var') || isempty(binType)
        binType = 'mean';
    end
    if ~exist('verbose', 'var') || isempty(verbose)
        verbose = 1;
    end
    if ~exist('resolution', 'var') || isempty(resolution)
        resolution = 'native';
    end
    
    % make binSize the proper size
    if isscalar(binSize)
        bV = binSize;
        binSize = ones([1, ndims(data) ]);
        binSize(1:2) = bV;
        clear('bV');
    elseif numel(binSize) ~= ndims(data)
        error('binSize must be a scalar or a vector with ndims values')
    end

    % same for binType
    if ~iscell(binType)
        assert(ischar(binType) || isstring(binType))
        binType = repmat({binType}, size(binSize));
    elseif numel(binType) ~= ndims(data)
        error(['binType must be a string or a cell array of ndims ' ...
               'strings'])
    end
    
    

    if any(binSize) <= 0
        error('binSize must contain only positive integers')
    end

    if debug
        disp('starting')  
                toc()
    end
    for iDim = 1:numel(binSize)
        if debug
            fprintf('dim %.0f\n', iDim)
        end
        bS = binSize(iDim);
        if bS == 1
            % bin by one, so do nothing
            continue
        end

        bT = binType{iDim};
        switch bT
          case 'mean'
            func = @(x) mean(x, 1, resolution);
          case 'sum'
            func = @(x) sum(x, 1, resolution);
          case 'min'
            func = @(x) min(x, [], 1);
          case 'max'
            func = @(x) max(x, [], 1);
          otherwise
            error('binType unknown: %s', bT)
        end
        
        if debug; disp('move');
                toc()
        end
        % move the relevant axis first
        order = (1:ndims(data));
        order(iDim) = 1;
        order(1) = iDim;
        data = permute(data, order);

        
        if debug; disp('cut');end
        % cut the extra useless data
        newShape = floor(size(data,1)/bS);
        oldPart = newShape * bS;
        if oldPart ~= size(data,1)
            if verbose > 1
                fprintf(['Binning will ignore %.0f pixel(s) along axis ' ...
                         '%.0f\n'], size(data, 1) - oldPart, iDim)
            end
            % A bit cumbersome writting to index only along the
            % first dimension
            idx = repmat({':'}, 1, ndims(data));
            idx{1} = 1:oldPart;
            data = data(idx{:});
        end
    
        if debug; disp('reshape');end
        % reshape by bin size
        shp = [2, size(data)];
        shp(2) = newShape;
        data = reshape(data, shp);

        
        if debug; disp('bin');
                toc()
        end
        % bin using the function
        data = squeeze(func(data));

        if debug; disp('reorder');
                toc()
        end
        
        % put back the axis in place
        data = permute(data, order);
        
        if debug; disp('done');end
    end 
    if debug
        toc()
    end
end

