** StitchIt **

StitchIt is a MATLAB package for assembling tiled image data. StitchIt was originally built for handling data from the TissueVision 1000, but the design of StitchIt is modular so it is possible to adapt the software to work with other tiled data sets (e.g. from a slide scanner or tiled images obtained from *in vivo* experiments).

To get started, please read the [PDF user manual](https://bitbucket.org/tvbz/tvmat/downloads/user_manual.pdf).  


** Installation **

Pull the repository. Add the code directory and its sub-directories to your MATLAB path. In addition, you will need
to acquire the following and add to your MATLAB path:

- [Slack MATLAB](http://www.mathworks.com/matlabcentral/fileexchange/48508-slackmatlab)
- [MATLAB Misc](https://bitbucket.org/raacampbell/misc-matlab)
- StitchIt is written for Linux (although most things will work on Windows too)

** Previewing images during acquisition **

If you are conducting a long experiment (e.g. with the TissueVision), StitchIt provides the facility to track progress
on the web. This allows you to halt acquisition should anything go wrong. To set this up you will need a web server to
which you have write access. You will need to set up [shared SSH keys](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2) to allow your analysis machine to push the images to the server. This needs to be done from the user account that runs StitchIt. If you wish, you may use the HTML and JavaScript files in the archive to produce an attractive image on the website (see the ```html``` directory).


** Licensing **

This software will be open-sourced following publication. In the mean time, please do not distribute it. Questions can be addressed to the author, Rob Campbell, at rob@mouse.vision