classdef tissuecyte < micSys

    %Inherits abstract class micSys. 
    %See micSys.m if you want to see which methods are crucial for instantiating this object
    properties (Constant)
    end



    methods 
        %Methods that also appear as function stubs common to all acquisition systems
        %are defined in seprate files. See micSys for list of required methods to instantiate this class.
        %The following methods are specific to the TISSUECYTE


        %------------------------------------------------------------------------


        function tifPrefix=acqDate2TifPrefix(obj,acqDate,index)
            % Uses the acqDate field from the params structure to construct the root tif file name
            %
            % tissuecyte.acqDate2TifPrefix
            %
            % tifPrefix=acqDate2TifPrefix(acqDate,index)
            %
            % Inputs
            % acqDate - [optional, string] (param.acqDate)
            % index - [optional, integer]  If supplied it builds the index into the TIF name
            %
            %
            % Outputs
            % tifPrefix - string defining the tif prefix.
            %
            %
            % Rob Campbell - Basel 2014
            acqDate = textscan(acqDate, '%d/%d/%d %d:%d:%d %cM');

            if acqDate{7} == 'P' & acqDate{4}<12
              acqDate{4} = acqDate{4} + 12;
            elseif acqDate{7} == 'A' & acqDate{4}==12 %Deal with midnight to 1 am
              acqDate{4}=0;
            end

            tifPrefix = sprintf('%02d%02d%04d-%02d%02d-', acqDate{1},acqDate{2}, acqDate{3},acqDate{4},acqDate{5});

            %Build index into tif name
            if nargin>2
                tifPrefix = sprintf('%s%d',tifPrefix,index);
            end

        end %acqDate2TifPrefix


        function [out,sucessfulRead]=readMosaicMetaData(obj,fname,verbose)
            % Read TissueVission Mosaic file into a MATLAB structure
            %
            % function [out,sucessfulRead]=readMosaicMetaData(fname,verbose)
            %
            % Purpose
            % Read meta-data from a TV mosiac file. Returns mosaic meta data as a structure. 
            %
            % Inputs
            % fname - relative or absolute path to mosaic meta-data file.
            % verbose - [optional, 0 by default] 
            % 
            % Outputs
            % out - a structure containing the metadata
            % sucessfulRead - 0 if the read failed for some reason. 1 otherwise.
            %
            % Rob Campbell - Basel - August 2014


            %Input argument error checking 
            if ~exist(fname,'file')
                error('Can not find parameter file: %s',fname)
            end

            if nargin<3
                verbose=0;
            end

            if verbose
              fprintf('%s: Reading param file: %s\n', mfilename, fname)
            end

            fid=fopen(fname,'r');
            fline=fgetl(fid);

            %following two lines amount to hard-coded variable names
            out.XPos=[];
            out.YPos=[];

            %Now loop through the file extracting all the values. 
            sucessfulRead=1;
            while ischar(fline)

                %If this is an X/Y position pair pull in the coordinates.
                if strfind(fline,'Pos')
                    tok=regexp(fline,'([XY]Pos)(-?\d+):(-?\d+)','tokens');

                    if isempty(tok)
                        fprintf('%s: problem reading info about tile. Last successfully read tile was %d\n', ...
                            mfilename, max([length(out.XPos),length(out.YPos)]))
                        sucessfulRead=0;
                        return
                    end

                    tok=tok{1};
                    key=tok{1};
                    val1=str2num(tok{2});
                    val2=str2num(tok{3});

                    %val1 is the difference (delta) and val2 is the stage position
                    out.(key)=[out.(key); [val1,val2]];


                    fline=fgetl(fid);       
                    continue
                end


                %Get key/value pairs
                tok=regexp(fline,'(\D+):(.*)','tokens');

                %Skip if we find no tokens
                if isempty(tok)
                    fline=fgetl(fid);       
                    continue
                end

                key=tok{1}{1};
                value=tok{1}{2};

                %Take out spaces in keys
                key=strrep(key,' ','');

                %Convert value to a number if it's not a string
                if isempty(regexp(value,'[a-zA-Z]')) & ~strcmp(key,'SampleID')
                    value=str2num(value);
                end

                out.(key)=value;
                fline=fgetl(fid);       

            end %while

            %layers defines the number of optical sections. It can be >1 even if we didn't ask for an optical z-stack. 
            %So we have to reset it if no z-stack was asked for
            if isfield(out,'Zscan') & out.Zscan==0
                out.layers=1;
            end

            fclose(fid);
        end %readMosaicMetaData


    end %methods

end %classdef