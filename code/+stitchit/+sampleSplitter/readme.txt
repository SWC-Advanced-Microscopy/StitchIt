
The stitchit.+sampleSplitter functions are associated with the class stitchit.sampleSplitter but are
designed to be run without creating an instance of stitchit.sampleSplitter 

The idea is that the user interactively creates ROIs using the GUI provided by stitchit.sampleSplitter
and then has the option of saving the ROIs to a .mat file, sending it to a remote PC and initiating 
the ROI splitting at the command line. The files in this directory will implement this latter part. 

This is a bit ugly, I admit, and to a degree could have been avoided by proper model/view practices 
in the class, but I didn't plan ahead and it's not worth doing now for such a small tool. 