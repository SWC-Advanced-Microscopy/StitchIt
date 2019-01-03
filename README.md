<img src="https://github.com/BaselLaserMouse/StitchIt/blob/gh-pages/images/rgb_brain_example.jpg" />

# StitchIt

*StitchIt* is a MATLAB package that was originally built for stitching data from the TissueVision 2-photon tomography system.
However, *StitchIt* is now sufficiently modular that it can handle other tiled data sets too (e.g. from a slide scanner or tiled images obtained from *in vivo* experiments using [ScanImage](http://scanimage.vidriotechnologies.com/)).
To get started, please read the [Wiki](https://github.com/BaselLaserMouse/StitchIt/wiki). 
Some older information is for now only available in the [PDF user manual](http://mouse.vision/st_manual_161122.pdf).
There is a [changelog](https://raw.githubusercontent.com/BaselLaserMouse/StitchIt/master/changelog.txt).

## Features

**With a single command (`syncAndCrunch`) the user can**:

- Pre-process image tiles as they are being acquired.
- Display the last acquired section on the web.
- Automatically stitch data when acquisition completes.
- Send Slack notifications when acquisition completes or pre-processing fails. 
- Automatically conduct arbitrary analyses after acquisition completes.


**StitchIt has commands for basic tasks such as**:

- Stitching subsets of a data set.
- Calculating the average tile for illumination correction.
- Calculating coefficients for correcting for scanning artifacts (experimental).
- Randomly accessing any tile in the dataset.
- Techniques for exploring stitching accuracy. 


**Post-stitching functionality**:

- Correction of intensity differences across different optical sections.
- Removal of tile seams in stitched images.
- Down-sampling the dataset to a single multi-page TIFF stack or MHD file. 


## Installation

Clone the repository. Add the ``code`` directory and its sub-directories to your MATLAB path. In addition, you will need
to acquire the following and add to your MATLAB path:

- [Slack MATLAB](https://github.com/DylanMuir/SlackMatlab)
- [rsync](http://www.howtogeek.com/135533/how-to-use-rsync-to-backup-your-data-on-linux/) is needed if you want to use the `syncAndCrunch` tool to process data during acquisition. 
- Additionally, you will need the following MATLAB toolboxes: [statistics](https://www.mathworks.com/products/statistics.html), [parallel computing](https://www.mathworks.com/products/parallel-computing.html), and [image processing](https://www.mathworks.com/products/parallel-computing.html). 

If you need more information on the installation procedure, please see the [Installation](https://github.com/BaselLaserMouse/StitchIt/wiki/Installation) page on the [Wiki](https://github.com/BaselLaserMouse/StitchIt/wiki).
Stitchit will automatically check if it's up to date whenever the user runs `syncAndCrunch`.


## Questions and bug reports
Please use the project's [issue tracker](https://github.com/BaselLaserMouse/StitchIt/issues) for questions, bug reports, feature requests, etc.

## Licensing 
This software is distributed under the GPL v3 licence. This repository may be freely forked and shared so long as this licence is attached.

## Also see
- [TissueVisionMods](https://github.com/BaselLaserMouse/TissueVisionMods) for protocols and tweaks associated with the TissueVision microscopy system. 
- [MaSIV](https://github.com/alexanderbrown/masiv) for visualising data. 
