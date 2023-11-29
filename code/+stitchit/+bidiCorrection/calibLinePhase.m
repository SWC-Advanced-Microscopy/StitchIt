function [correctedImg,stats] = calibLinePhase(imFname, imIdx,suppressPlot)
    % function [correctedImg,stats] = calibLinePhase(imFname, imIdx)

    if nargin<2
        imIdx=2;
    end

    if nargin<3
        suppressPlot=false;
    end

    verbose=true;

    % Load the image from the raw data stack
    origImg = imread(imFname,imIdx);

    tInfo=imfinfo(imFname);
    metaData=stitchit.tools.parse_si_header(tInfo(1),'Software');

    % Define empty stats array and output imgae in case of an error
    correctedImg = [];
    stats.shiftAmnt = [];
    stats.iter = [];
    stats.newPhase = [];
    stats.origPhase = [];
    stats.imMu = [];
    stats.imMed = [];

    % Phase the original image was taken with
    origPhase = metaData.linePhase;
    if verbose
        fprintf('Original phase: %0.4f us\n',origPhase*1E6)
    end

    currentImg = origImg;

    % Calculate a new phase, if this is different from the original phase it indicates
    % some shifting is necessary.
    T=tic;
    newPhase = stitchit.bidiCorrection.calibLinePhase.calibrateLinePhase(double(currentImg'),metaData);

    if verbose
        fprintf('New phase calculated in %0.2f s : %0.4f us to %0.4f us\n', ...
            toc(T), metaData.linePhase*1E6, newPhase*1E6)
    end




    % The is the difference between the new phase and the original phase
    % Ideally this should be 0, newPhase == origPhase so no phase shift
    % needed - image is aligned.
    delta = abs(newPhase - origPhase);

    % The amount of pixels to shift by
    shiftAmnt = 0;

    % The last shift amount that produces a reduction in the change in
    % phase difference. If a shift increases the phase difference we want
    % to use this value and break operation. This is necessary since data
    % loss may create a situation in which the phase difference will never
    % be 0, so we just want to minimize it as much as possible.
    lastGoodShiftAmnt = nan;
    iter = 0;
    maxIter = 10;
    newImg = [];
    % Ideally shift until delta is 0, i.e. no phase shift needed
    T=tic;

    while (delta ~= 0) && iter < maxIter
        if verbose
            fprintf('Iter. %d shift by %0.2f\n', iter, shiftAmnt)
        end

        % Shift the image lines by some amount to generate a new image
        newImg = shiftEvenLines(currentImg, shiftAmnt);

        % Use the shifted image as the new current image
        currentImg = newImg;

        % Calculate a new phase using the shifted image. If the shift fixed
        % the image the calculated new phase should match the original
        % phase. This function assumes the image was captured using the
        % original phase so it should spit out the same value if the
        % alignment is good.
        newPhase = stitchit.bidiCorrection.calibLinePhase.calibrateLinePhase(double(currentImg'),metaData);

        % You may never be able to correct the phase due to data loss so don`t try for ever
        iter = iter + 1;

        % Cache the old delta to see if the difference is getting better or worse
        lastDelta = delta;

        % What is the difference between the newPhase calculated using the
        % shifted image and the original phase - again ideally the delta
        % will be 0 because the calibration function will spit out the
        % original phase indicating no shift needed- ie alignment is good
        delta = abs(newPhase - origPhase);

        % Ideally the difference between the new phase and the original
        % phase should approach 0 as things improve. So if the new delta is
        % worse than the previous delta, then it means we are moving away
        % from 0 and the shifting is making things worse.
        if delta > lastDelta
            if verbose
                disp('Getting worse, so lets go back and stop')
            end
            newImg = shiftEvenLines(origImg, lastGoodShiftAmnt);
            break
        else
            if verbose
                disp('Getting better')
            end
            lastGoodShiftAmnt = shiftAmnt;
        end

        % Check to see if phase got worse and in what direction to change new shift.
        if newPhase > origPhase
            shiftAmnt = shiftAmnt + 1;
        else
            shiftAmnt = shiftAmnt - 1;
        end
    end

    if iter == maxIter
        if verbose
            warning(sprintf('Unable to correct image in fewer than %d iterations\n',maxIter));
        end
        correctedImg = [];
        lastGoodShiftAmnt = nan; % So we don't count it
    elseif ~suppressPlot && ~isempty(newImg)
        correctedImg = newImg;
        figure(84235);
        imshow(correctedImg, []);
%         imshow(correctedImg, 'Colormap', summer(256));
    end

    if verbose
        fprintf('Shifted in %0.2f s\n', toc(T))
    end

    stats.shiftAmnt = lastGoodShiftAmnt;
    stats.iter = iter;
    stats.newPhase = newPhase;
    stats.origPhase = origPhase;
    stats.imMu = mean(origImg(:));
    stats.imMed = median(origImg(:));
    stats.imFname = imFname;
end



function shiftOut = shiftEvenLines(img, shiftAmt)
     [r,c] = size(img);
     out = img;
     for i = 1:r
          if ~mod(i, 2) % if 0 then even line
               out(i,:) = circshift(img(i, :), shiftAmt);
          end
     end
    shiftOut = out;
end
