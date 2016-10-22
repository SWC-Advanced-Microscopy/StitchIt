function writeTileStats(imStack,tileIndex,chansToLoad,thisDirName,statsFile)

	%Writes a tile stats binaru file in each directory. 
	% Rows are: 
	%  file index, layer index, tile mean, tile median

	fprintf('Creating stats file: %s\n',statsFile)				
	fid = fopen(statsFile,'w+'); %Empty the file
	fwrite(fid,3,'uint32'); %The number of ints per row

	for thisChan = 1:size(imStack,1) %imStack is a cell array
		for thisLayer = 1:size(imStack,2)
			if isempty(imStack{thisChan,thisLayer}), continue, end

			mu=squeeze(mean(mean(imStack{thisChan,thisLayer})));
			mu=uint32(round(mu)); 

			med=squeeze(median(median(imStack{thisChan,thisLayer})));
			med=uint32(round(med)); 

			index=tileIndex{thisChan,thisLayer}(:,1);
			index(:,end+1)=thisLayer;

			index(:,end+1)=mu;
			index(:,end+1)=med;
			index=index';
			fwrite(fid,index(:),'uint32');
		end
	end
	fclose(fid);
