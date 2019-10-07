function [freeMemKB, totalMemKB]=systemMemStats
    % function [freeMemKB, totalMemKB]=systemMemStats
    %
    % Return memory usage. Cross-platform.

switch computer
    case 'GLNXA64'
        s=strsplit(evalc('system(''free'');'), '\n');

        lineToScrape= find(~cellfun(@isempty, (strfind( s, 'Mem:'))));
        if isempty(lineToScrape)
            freeMemKB=0;
            totalMemKB=0;
        else
            secondLine=strsplit(s{lineToScrape});
            totalMemKB=str2double(secondLine{2});
            
            thirdLine=strsplit(s{lineToScrape+1});
            freeMemKB=str2double(thirdLine{4});
        end
    case 'MACI64'
        f=str2num(evalc('system(''vm_stat | grep free | awk ''''{ print $3 }'''' | sed ''''s/\.//'''''');')); %#ok<*ST2NM>
        spec=str2num(evalc('system(''vm_stat | grep speculative | awk ''''{ print $3 }'''' | sed ''''s/\.//'''''');'));

        freeMemKB=convertPagesToKiB(f+spec);
        totalMemKB=convertGBToKiB(str2num(evalc('system(''hostinfo | grep memory | awk '''' { print $4 } '''''');')));
    otherwise %It's windows
        [~,RAM]=memory;
        freeMemKB=RAM.PhysicalMemory.Available/1024;
        totalMemKB=RAM.PhysicalMemory.Total/1024;
end


end

function szMiB=convertPagesToKiB(nPages)
szMiB=nPages*4;
end

function KiB=convertGBToKiB(GB)
KiB=GB*1000^3/1024;
end