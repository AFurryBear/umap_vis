function EvTAFv4Sim(batchf,configfile,ChanSpec);
%ND=EvTAFv4Sim(batchf,configfile,ChanSpec);
% Loads every cbin file in the batchfile -> batchf and simulates
%  EvTAFv4 triggers.  All EvTAFv4 params are loaded from the file
% listed in configifle.  This must be new binary
% config file format.  Note there is an old version of the config file
% format that will not work here but this should only effect me (evren)
% and tim warren.  ChanSpec is the channel you want to use as the
% sound/song data.  usualy format 'obs0' or 'obs2r' etc.
% 
%output - write X.rec files with the simulated trigger times in them
% so if the cbin filename is : bk57w35_170809_093631.355.cbin
% this program will output a file called : bk57w35_170809_093631.355X.rec
% this way any original rec files do not get written over.
% you can read this recfile by using readrecf which returns a strucutre
% with all the file info.  Just set the second input ADDX to 1 and it will
% add the X in X.rec for you automatically.  example:
% rd=readrecf('bk57w35_170809_093631.355.cbin',1);
% then rd.ttimes is the trigger times in msec
% also useful rd.trignote is which of the notes triggered meaning which
% index of Note Detection Info brought about the trigger
%
%ND is an array of strucutures.  it contains all kinds of
%information about the evtaf triggering. It corresponds to the Note
%Detection Info strucutre in the main EvTAFv4 LabVIEW window
% if you want to see the trigger times 

[ND,OP]=ReadEvTAFv4ConfigFile(configfile);

% do some checks to make sure everything is ok
for ii=1:length(ND)
    if isempty(ND(ii).Templ)
        disp(['Templates are empty for note detect info index = ',num2str(ii)]);
        if exist(ND(ii).TemplFile,'file')
            disp(['Load the templates from the template file : ',ND(ii).TemplFile]);
            ND(ii).Templ=load(ND(ii).TemplFile);
        else
            disp(['Could not file the Template File indicated : ',ND(ii).TemplFile]);
            disp(['Probably a path mismatch']);
            disp(['Please choose the right template file']);
            [FileName,PathName,FilterIndex] = uigetfile('*',['Template for Note Index ',num2str(ii)]);
            ND(ii).TemplFile=[FileName,PathName];
            ND(ii).Templ=load(ND(ii).TemplFile);
        end
    end

    %verify template normalizations
    for jj=1:size(ND(ii).Templ,2)
        ND(ii).Templ(1:6,jj)=0;
        ND(ii).Templ(:,jj)=ND(ii).Templ(:,jj)./max(ND(ii).Templ(:,jj));
    end

    % get the number of data points that have to be read in based on the
    % size of the templates
    if (ii==1)
        NFFT=2*size(ND(ii).Templ,1);
    else
        if (NFFT~=2*size(ND(ii).Templ,1))
            disp(['ERROR - EvTAF Limitation all templates have the be the same length in freq bins']);
            return;
        end
    end

    if (length(ND(ii).CntRng)~=size(ND(ii).Templ,2))
        disp(['Counter Range values and Templates are of different sizes for Note index : ',num2str(ii)]);
        disp(['Cannot continue']);
        return;
    end
end


inputfiles=[];
fid=fopen(batchf,'r');
while (1)
    fn=fgetl(fid);
    if (ischar(fn))
        if (exist(fn,'file'))
            inputfiles(length(inputfiles)+1).fn=fn;
        else
            disp(['Could not fine file : ',fn]);
            disp('Skipping it');
        end
    else
        break;
    end
end
fclose(fid);

for IFile=1:length(inputfiles)
    %loop over every file in the batchfile
    fn=inputfiles(IFile).fn;
    disp(fn);
    [dat,fs]=evsoundin('',fn,ChanSpec); % load up the raw data

    PREBUFIND=ceil(OP.FileBufferLeng*fs);

    %skip the data in the prebuffer - Cannot trigger off this data since
    %it is just held in the buffer and no sound playback happens if the box
    %is 'quiet'
    
    [ND,TemplMatchVals]=EvTAFv4(ND,OP,dat,fs);
    
    SimTrigInfo=[];
    for iND=1:length(ND)
         SimTrigInfo=[SimTrigInfo;...
             ND(iND).TriggerTimes*1e3,ones(size(ND(iND).TriggerTimes))*(iND-1)];
    end
    [sortv,sorti]=sort(SimTrigInfo(:,1));
    SimTrigInfo=SimTrigInfo(sorti,:);
    
    rd=readrecf(fn);
    rd.ttimes=SimTrigInfo(:,1);
    rd.trignote=SimTrigInfo(:,2);
    wrtrecf(fn,rd,1);
    
    % old debug code
    %for iND=1:length(ND)
        %disp(['IND  = ',num2str(iND)]);
        %for ijk=1:length(ND(iND).TriggerTimes)
        %    disp(num2str(ND(iND).TriggerTimes(ijk),6));
        %end
        %disp([' ']);

        %rd=readrecf(fn);
        %tt=[rd.ttimes,zeros(size(rd.ttimes))];
        %for ijk=1:size(tt,1)
        %    pppp=findstr(rd.pbname{ijk},'Templ = ');
        %    strtemp=rd.pbname{ijk};
        %    tt(ijk,2)=str2num(strtemp(pppp+8:end));
        %end


        % Some Debug output i used early on
        %compare the sim trigs to the actual trigs
        %if (isempty(tt))
        %    disp(['No trigs in recfile : Nact = 0  - Nsim = ',num2str(length(ND(iND).TriggerTimes))]);
        %    continue;
        %end

        
        %pppp=find(tt(:,2)==iND-1);
        %if (length(pppp)==0)
        %    continue;
        %end
        %tttemp=tt(pppp,1);
        %if (length(tttemp)~=length(ND(iND).TriggerTimes))
        %    disp(['XTrig Times not the same size : Nact = ',num2str(length(tttemp)),' Nsim = ',num2str(length(ND(iND).TriggerTimes))]);
        %end
        %for ijk=1:length(ND(iND).TriggerTimes)
        %    [yy,iy]=min(abs(ND(iND).TriggerTimes(ijk)*1e3-tttemp));
        %    disp(['iND = ',num2str(iND)]);
        %    disp(['Act Trig Time = ',num2str(tttemp(iy)),' Sim Trigger Time = ',num2str(ND(iND).TriggerTimes(ijk)*1e3)]);
        %    disp(['Diff in ms = ',num2str( tttemp(iy) - ND(iND).TriggerTimes(ijk)*1e3)]);
        %end
    end
end % loop over files




