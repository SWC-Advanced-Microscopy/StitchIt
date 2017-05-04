classdef bakingtray < micSys

    %Inherits abstract class micSys. 

    properties (Constant)

    end



    methods
        % The following are methods for reading the ScanImage header
        [nbchannels, nbplanes] = size_from_scanimage(~,tifpath)
        si_metadata = parse_si_header(~,tiff_header, si_fields)
    end

end