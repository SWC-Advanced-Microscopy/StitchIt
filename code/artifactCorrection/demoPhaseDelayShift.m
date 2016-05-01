function demoPhaseDelayShift

% Run a toy example to show how the phase delay correction works. 
%
% function demoPhaseDelayShift
%
%
% ALSO:
% calcPhaseDelayShifts, applyPhaseDelayShifts
%
%
% Rob Campbell - Basel, 2014






%Make an image, construct a "fake" structure with shift values and shift the image
im = imread('cameraman.tif');


%loop through repeatedly
stats=calcPhaseDelayShifts(im,5); %calculate phase correction. all shifts are zero, obviously


%Add small random shifts
shiftsToAdd = round(rand(1,length(stats.xShifts))*2);
stats.xShifts = shiftsToAdd;

imWithShifts = applyPhaseDelayShifts(im,stats);


%Now take them out again
stats=calcPhaseDelayShifts(imWithShifts); 
imWithNOShifts = applyPhaseDelayShifts(imWithShifts,stats);


%Show the results
clf

subplot(2,1,1)
imagesc(imWithShifts)


subplot(2,1,2)
imagesc(imWithNOShifts)

