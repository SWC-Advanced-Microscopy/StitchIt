
The stitchit.@sampleSplitter class makes a GUI that is used for either cropping a sample or splitting into separat eROIs. 
The whole process can be done via the GUI however, users can also save the ROIs to disk, sned them to a remote PC and
and initiate the ROI splitting at the command line. This latter part is achieved using the functions in stitchit.+sampleSplitter. 

The fact that half the tool is a bunch of functions and half is a class isn't really obvious to the user. I know it's all 
a bit ugly -- and to a degree could have been avoided by proper model/view practices -- but I didn't plan ahead and it's 
not worth doing now for such a small tool. 
