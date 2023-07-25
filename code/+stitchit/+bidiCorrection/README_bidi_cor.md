# Post-Hoc Bidirectional Scanning Correction

Code here is for implementing post-hoc bidirectional scanning correction. 
**NOTE** this is all very hacky right now and badly documented. 

## Getting shifts for a single section

```
>> stitchit.bidiCorrection.getShiftForSection(12,2)
```



### How this is applied
The `tileLoad` function has a param/value pair called `bidiShiftPixels`. 
This shifts loaded tiles by an integer amount. 
`tileLoad` is called by `stitchSection`, which also has a `bidiShiftPixels` that is simply passes to `tileLoad`. 
So to test the effect of a value you can just do something like:
```
stitchSection([170,1],1,'bidiShiftPixels',-1)
```

Then can stitch all four channels
```
for ii=1:4; stitchSection([],ii,'bidiShiftPixels',1,'OverWrite',false); end  
```
