<img src="https://github.com/BaselLaserMouse/StitchIt/blob/gh-pages/images/rgb_brain_example.jpg" />


# StitchIt and CIDRE

This is a fork of the main stream poject [*StitchIt*](https://github.com/BaselLaserMouse/StitchIt). Here, we integrate CIDRE illumination correction algorithm [CIDRE](https://github.com/Fouga/cidre) into the image illumination correction pipeline. 

In the original code the nonlinear illumination correction is performed by calculating the average image. It is working very well on images with good autoflourescence (e.g. brain sample), however, on spleen images we could find an appropriate background image. In this fork 
