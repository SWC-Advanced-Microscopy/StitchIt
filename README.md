# StitchIt

StitchIt is a MATLAB package for assembling tiled image data. StitchIt was originally built for handling data from the TissueVision 1000 (from the TissueCyte company), but the design of StitchIt is modular so it is possible to adapt the software to work with other tiled data sets (e.g. from a slide scanner or tiled images obtained from *in vivo* experiments).

To get started, please read the [PDF user manual](https://bitbucket.org/tvbz/tvmat/downloads/user_manual.pdf).
Please note that StitchIt is under heavy modification and the user manual will not be completely up to date.


## Current state of the project
This software is used routinely in-house for assembling image stacks from our TissueVision microscope. 
It currently lacks the following features:

1. Tile placement does not use tile coordinates, since the coordinates returned by the TissueVision are not reliable. 
2. The bidirectional artifact correction function (e.g. see [calcPhaseDelayShifts](https://github.com/BaselLaserMouse/StitchIt/blob/master/code/artifactCorrection/calcPhaseDelayShifts.m)) does not work well for TissueVision data, which has an unconventional way of building the images.
3. The project is not completely modular (i.e. designed to work with multiple acquisition system). This is a work in progress. 


## Installation

Pull the repository. Add the code directory and its sub-directories to your MATLAB path. In addition, you will need
to acquire the following and add to your MATLAB path:

- [Slack MATLAB](http://www.mathworks.com/matlabcentral/fileexchange/48508-slackmatlab)
- [MATLAB Misc](https://bitbucket.org/raacampbell/misc-matlab)
- StitchIt is written for Linux (although most things will work on Windows too)
- Suggested function to get you started: ``help stitchSection``

## Previewing images during acquisition

If you are conducting a long experiment (e.g. with the TissueVision), StitchIt provides the facility to track progress
on the web and conduct pre-processing of the data during acquisition. 
This facility is provided via the ``syncAndCrunch`` tool.  
We find this facility useful. e.g. You can halt acquisition should anything go wrong. 
To set this up you will need a web server to which you have write access. You will need to set up [shared SSH keys](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2) to allow your analysis machine to push the images to the server. This needs to be done from the user account that runs StitchIt. If you wish, you may use the HTML and JavaScript files in the archive to produce an attractive image on the website (see the ```html``` directory).


## Questions and bug reports
Please use the project's [issue tracker](https://github.com/BaselLaserMouse/StitchIt/issues) for questions, bug reports, feature requests, etc.


## Licensing 
This software is distributed under the GPL v3 licence. This repository may be freely forked and shared if it is PUBLIC. 
If it is PRIVATE, please ask the author before sharing. 
