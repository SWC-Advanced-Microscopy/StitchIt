function stats=analyseShiftsForChannel(data,doPlots)
    % Analyse data produced by getShiftForChannel
    %
    % stitchit.bidiCorrection.analyseShiftsForChannel(data,doPlots)
    %
    % Purpose
    % Make plots of the bidi shifts we have calculated.
    %
    % Inputs
    % data - the output of stitchit.bidiCorrection.getShiftsForChannel
    % doPlots - optional false by default

    if nargin<2
        doPlots = false;
    end

    sectionNumber = zeros(1,length(data));
    shiftsMed = zeros(1,length(data));
    shiftsMu = zeros(1,length(data));

    for ii=1:length(data)
        sectionNumber(ii) = data{ii}(1).sectionNumber;

        tShifts = [data{ii}.shiftAmnt];
        % TODO - I think we should treat nans as zero shift and change the 
        % code generating these accordingly
        tShifts(isnan(tShifts))=0;

        if range(tShifts)>1
            fprintf('Shifts for section %d are not reliable!\n',sectionNumber(ii));
        end
        shiftsMed(ii) = median(tShifts);
        shiftsMu(ii) = mean(tShifts);
    end



    if doPlots
        clf
        yyaxis('left')
        plot(sectionNumber,shiftsMed,'o-b')
        xlabel('section number')
        ylabel('median shift')

        yyaxis('right')
        plot(sectionNumber,shiftsMu,'o-r')
        ylabel('mean shift')
        grid on


    end