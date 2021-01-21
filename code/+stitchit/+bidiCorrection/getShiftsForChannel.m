function stats=getShiftForChannel(chan)
    % Get all shifts for a particular channel across all sections


    section=handleSectionArg([]);
    section = section(section(:,2)==1,:);

    parfor ii=1:length(section)
        tSection = section(ii,1);
        fprintf('Starting section %d\n',tSection)
        tmp=stitchit.bidiCorrection.getShiftForSection(tSection,chan);
        fprintf('Done section %d\n',tSection)

        if ~isempty(tmp)
            stats{ii}=tmp;
        end
    end

