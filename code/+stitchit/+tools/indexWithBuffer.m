function inds = indexWithBuffer(inputVector,index,bufferSize)
% Return the item at "index" with +/- bufferSize values. Handles edge cases.
%
%  function inds = indexWithBuffer(inputVector,index,bufferSize)
%
% Purpose
% We want to be able to return an index plus the n values around it. 
% We want to be able to handle the extremes. So for values in the middle
% of the range it returns (index-bufferSize):(index+bufferSize). If 
% index=1 then it will return 1:(bufferSize*2).
%
%
% Examples
% >> stitchit.tools.indexWithBuffer(1:20,1,3)  
%
% ans =
%
%     1     2     3     4     5     6     7
%
% >> stitchit.tools.indexWithBuffer(1:20,10,3)
%
% ans =
%
%     7     8     9    10    11    12    13
% >> stitchit.tools.indexWithBuffer(1:20,19,3) 
%
% ans =
%
%    14    15    16    17    18    19    20
%
%
% Rob Campbell - Basel 2016




inds = index-bufferSize : index+bufferSize;

if inds(1)<1
  inds = inds - inds(1) +1;
elseif inds(end)>length(inputVector)
  inds = inds - (inds(end) - length(inputVector));
end