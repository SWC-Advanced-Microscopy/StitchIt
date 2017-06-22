<img src="https://github.com/BaselLaserMouse/StitchIt/blob/gh-pages/images/rgb_brain_example.jpg" />


# StitchIt and CIDRE

This is a fork of the main stream poject [*StitchIt*](https://github.com/BaselLaserMouse/StitchIt). Here, we integrate CIDRE illumination correction algorithm [CIDRE](https://github.com/Fouga/cidre) into the image illumination correction pipeline. 

Nonlinear illumination of an image is a common artifact of any microscope. This artifact is particularly noticable in a tile acquasition system such as [Ragan et al.](http://www.nature.com/nmeth/journal/v9/n3/abs/nmeth.1854.html). To adjust brightness of the image, one can calculte an average image of the acquired stack.  
Although this tehcnique can works very well on images with good autoflourescence, on images with a weak backgound signal the average image is not robust enough. 
