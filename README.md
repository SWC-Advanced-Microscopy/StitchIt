<img src="https://raw.githubusercontent.com/wiki/SainsburyWellcomeCentre/StitchIt/images/rgb_brain_example.jpg" />

# StitchIt

*StitchIt* is a MATLAB package for stitching data acquired via our [ScanImage](http://scanimage.vidriotechnologies.com/))-based acquisition system (BakingTray).
To get started, please read the [Documentation](https://stitchit.mouse.vision/). 
There is a [changelog](https://raw.githubusercontent.com/SainsburyWellcomeCentre/StitchIt/master/changelog.txt).

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
- Cropping stitched datasets or partition a single stitched dataset into multiple ROIs.


**Post-stitching functionality**:

- Correction of intensity differences across different optical sections.
- Removal of tile seams in stitched images.
- Down-sampling the dataset to a single multi-page TIFF stack or MHD file. 


## Installation

Clone the repository. Add the ``code`` directory and its sub-directories to your MATLAB path. In addition, you will need
to acquire the following and add to your MATLAB path:

- [Slack MATLAB](https://github.com/DylanMuir/SlackMatlab)
- [yamlmatlab](https://github.com/raacampbell/yamlmatlab)
- [rsync](http://www.howtogeek.com/135533/how-to-use-rsync-to-backup-your-data-on-linux/) is needed if you want to use the `syncAndCrunch` tool to process data during acquisition. 
- Additionally, you will need the following MATLAB toolboxes: [statistics](https://www.mathworks.com/products/statistics.html), [parallel computing](https://www.mathworks.com/products/parallel-computing.html), and [image processing](https://www.mathworks.com/products/parallel-computing.html). 

If you need more information on the installation procedure, please see the [Installation](https://github.com/BaselLaserMouse/StitchIt/wiki/Installation) page on the [Wiki](https://github.com/BaselLaserMouse/StitchIt/wiki).
Stitchit will automatically check if it's up to date whenever the user runs `syncAndCrunch`.


## Questions and bug reports
Please use the project's [issue tracker](https://github.com/BaselLaserMouse/StitchIt/issues) for questions, bug reports, feature requests, etc.
Please do get in touch if use the software: especially if you are publishing with it!
You may also join the [StitchIt Gitter](https://gitter.im/open-serial-section/stitchit) room for discussions.


## Licensing 
This software is distributed under the GPL v3 licence. This repository may be freely forked and shared so long as this licence is attached.



## More tools
See [btpytools](https://github.com/SainsburyWellcomeCentre/btpytools) for Python-based helper tools. e.g. to compress raw data or send data to a remote server. You may install those via:
```
$ sudo pip install btpytools

```
