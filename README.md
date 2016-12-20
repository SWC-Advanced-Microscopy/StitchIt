<img src="https://github.com/BaselLaserMouse/StitchIt/blob/gh-pages/images/rgb_brain_example.jpg" />

# StitchIt

StitchIt is a MATLAB package for assembling tiled image data. StitchIt was originally built for handling data from the TissueVision 2-photon tomography system, but the design of StitchIt is partly modular so it is possible to adapt the software to work with other tiled data sets (e.g. from a slide scanner or tiled images obtained from *in vivo* experiments).

To get started, please read the [PDF user manual](http://mouse.vision/st_manual_161122.pdf).
StitchIt is under heavy modification and the user manual will not be completely up to date.
Much of the content in the manual will soon be updated and put on the project's Wiki page.
StitchIt is written for Linux. 
Most things should work on Windows too, but this hasn't been tested and we can't provide support for it.


## Current state of the project
StitchIt is used routinely in-house for assembling image stacks from our TissueVision microscope. 

**With a single command the user can**:

- Pre-process image tiles as they are being acquired.
- Display the last completed section on the web.
- Automatically stitch data when acquisition completes. 
- Automatically conduct arbitrary analyses after acquisition completes.

**StitchIt has commands for basic tasks such as**:

- Stitching a data set.
- Calculating the average tile for illumination correction.
- Calculating coefficients for correcting for scanning artifacts (experimental).
- Techniques for exploring stitching accuracy. 


**Post-stitching functionality**:

- Correction of intensity differences across different optical sections.
- Removal of tile seams in stitched images.
- Down-sampling the dataset to a single multi-page TIFF stack or MHD file. 


**StitchIt currently lacks the following features**:

- By default, tile placement does not use tile coordinates since the coordinates returned by our TissueVision are not reliable. i.e. stitching accuracy is no better (may be worse) if we use actual tile coordinates. Systems other than the TissueVision may be different and YMMV. 
- The bidirectional artifact correction function (e.g. see [calcPhaseDelayShifts](https://github.com/BaselLaserMouse/StitchIt/blob/master/code/artifactCorrection/calcPhaseDelayShifts.m)) does not work well right now but can be fixed.
- More work is needed to adapt this code base to acquisition systems other than the TissueVision. 


## Installation

Clone the repository. Add the ``code`` directory and its sub-directories to your MATLAB path. In addition, you will need
to acquire the following and add to your MATLAB path:

- [Slack MATLAB](https://github.com/DylanMuir/SlackMatlab)
- [YAML MATLAB](https://github.com/raacampbell/yamlmatlab)
- Suggested function to get you started: ``help stitchSection``

If you need more information on the instalation procedure, please see the [Installation](https://github.com/BaselLaserMouse/StitchIt/wiki/Installation) page on the [Wiki](https://github.com/BaselLaserMouse/StitchIt/wiki).

## Previewing images during acquisition

If you are conducting a long experiment (e.g. with the TissueVision), StitchIt provides the facility to track progress
on the web and conduct pre-processing of the data during acquisition. 
This facility is provided via the ``syncAndCrunch`` tool.  
We find this facility useful. e.g. You can halt acquisition should anything go wrong. 
To set this up you will need a web server to which you have write access. You will need to set up [shared SSH keys](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2) to allow your analysis machine to push the images to the server. This needs to be done from the user account that runs StitchIt. If you wish, you may use the HTML and JavaScript files in the archive to produce an attractive image on the website (see the ```html``` directory).


## Questions and bug reports
Please use the project's [issue tracker](https://github.com/BaselLaserMouse/StitchIt/issues) for questions, bug reports, feature requests, etc.


## Licensing 
This software is distributed under the GPL v3 licence. This repository may be freely forked and shared so long as this licence is attached.

## Also see
- [TissueVisionMods](https://github.com/BaselLaserMouse/TissueVisionMods) for protocols and tweaks associated with the TissueVision microscopy system. 
