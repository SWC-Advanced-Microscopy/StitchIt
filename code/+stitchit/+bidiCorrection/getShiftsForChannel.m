function stats=getShiftForChannel(chan)
    % Get all shifts for a particular channel across all sections


    section=handleSectionArg([]);
    section = section(section(:,2)==1,:);


    parfor ii=1:length(section)
        tmp=stitchit.bidiCorrection.getShiftForSection(section(ii,1),chan);
        if ~isempty(tmp)
            stats(ii)=tmp;
        end
    end

