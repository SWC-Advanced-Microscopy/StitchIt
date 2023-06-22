function stats=getShiftsForChannel(chan,everyNSections)
    % Get all bidi shifts for a particular channel across all sections
    %
    % stitchit.bidiCorrection.getShiftsForChannel(chan,everyNSections)
    %
    % Purpose
    % Loop through a series of sections for one channel and calculate the
    % optimal bidi phase shift for each. The calculate is quite time
    % consuming so it is possible to do this for every N sections.
    %
    % Inputs
    % chan - Which channel to use for the calculation. This input argument
    %        is required. You should choose the channel with the strongest
    %        signal. A purely auto-fluorescence channel is likely not
    %        going to have enough structure for this work.
    % everyNSections - Optional. 1 by default. e.g. if set to 3 the
    %               calculation is run on every third section only.
    %
    %
    % shiftsChan2 = stitchit.bidiCorrection.getShiftsForChannel(2,10);
    %
    %
    % Rob Campbell - SWC 2019
    %
    % Also see:
    %  stitchit.bidiCorrection.getShiftForSection

    if nargin<2 || isempty(everyNSections)
        everyNSections=1;
    end

    section = handleSectionArg([]);
    section = section(section(:,2)==1,:);

    section = section(1:everyNSections:end,:);

    fprintf('Running over a total of %d sections\n', length(section))

    T=tic;
    parfor ii=1:length(section)
        tSection = section(ii,1);
        fprintf('Starting section %d\n',tSection)
        tmp=stitchit.bidiCorrection.getShiftForSection(tSection,chan);
        fprintf('Done section %d\n',tSection)

        if ~isempty(tmp)
            stats{ii}=tmp;
        end
    end

    fprintf('Finished processing channel %d in %0.1f seconds\n',chan,toc(T))

