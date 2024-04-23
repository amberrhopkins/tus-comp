%% **** TMSEEG signal analyser (TESA) _ 2018 / 09 ****
% Revisited 2019 / 08
% Giacomo Bertazzoli, giacomo.bertazzoli@unitn.it
% Tested on MATLAB 2017b and EEGLAB14

%% TESA PAPER:
% Rogasch NC, Sullivan C, Thomson RH, Rose NS, Bailey NW, Fitzgerald PB, Farzan F,
% Hernandez-Pavon JC. Analysing concurrent transcranial magnetic stimulation and
% electroencephalographic data: a review and introduction to the open-source TESA
% software. NeuroImage. 2017; 147: 934-951.

%% Toolbox and packages needed:
% EEGLAB with TESA extension

%% Dataset description
% Data are resting-state TMS-EEG. TMS was delivered at 4 different areas, 2
% parietal and 2 frontal (left-right Dorsolateral prefrontal cortex (lPF
% -close
% rPF) and left-right inferior parietal lobule (lP - rP). Each area was
% stimulated 120 times with single monophasic stimuli (random ISI between
% 2-10 seconds). Total number of subjects (with test and re-test session):

%% METHOD TO REMOVE LARGE TMS-evoked MUSCLE ARTIFACT
%This script employes a FastICA decomposition with semi-automatic component
%selection to remove the TMS-evoked MUSCLE ARTIFACT (one of the alternative
%offered by TESA toolbox) Rogasch et al. 2017

%% TRIAL AND CHANNEL CHECK
% trial and channel are visually checked prior to the pipeline (as
% suggested in Rogash paper. Bad trial and Bad channel are annoted and
% saved in a structure and then removed during to the pipeline.

%% Define directories and subjects

clear variables	% prepare a clean workspace
close all   % close all open events
% code_dir=extractBefore(mfilename( 'fullpath' ), ['/' mfilename]); %define the folder in which the script is running
main_dir=extractBefore(mfilename( 'fullpath' ), ['/' mfilename]); %define the folder in which the script is running

%% Add plug-in % creare cartella generale che contenga plug in con path relative
addpath([main_dir '/PLUG-INs/natsortfiles']); %natsort
addpath([main_dir '/PLUG-INs/TESA1.1.1']); %TESA
addpath([main_dir '/PLUG-INs/eeglab_current/eeglab2023.0']); %eeglab
addpath([main_dir '/PLUG-INs/FastICA_25']); %fastICA
addpath([main_dir '/PLUG-INs/fieldtrip-20190905']); %fieldtrip
%addpath('/Users/amber/Documents/MATLAB/fieldtrip-20230613')

% initialize eeglab;
eeglab nogui %initialize eeg lab

%% Import BIDS data with EEGlab (it transform each brain-vison dataset in a .set dataset. It takes time).
% pop_importbids(main_dir);

%% Variables
trim_time=[0 20]; %remove first part of the resting EEG (sec)
trigger_code='T  1'; %trigger code sent to the EEG system
tms_removal_interval=[-2 8]; %interval where to cut and interpolate TMS pulse
cubic_interp_interval=[20,1]; %interval used to calculate interp values by pop_tesa_interpdata
hp_filt=0.1; %high pass filter cut-off fr in Hz
notch_filt=[58 62]; %notch filter limit in Hz
epoching=[-0.8 0.8]; %epoching in sec
final_ref={'TP9','TP10'}; %reref. [] for avg reref
lp_filt=45; %low pass filter limit in Hz
downsample=1000; %Hz to reach for the downsampling
epoching_short=[-0.6 0.6]; %epoching in sec
baseline_interval=[-600 -2]; %interval in ms for demeaning !!! CHEK BASED ON PULSE REMOVAL
epoching_rsEEG=10;

%% DEFINE DATA FOLDER
datafolder_parent = '/Users/amber/Documents/PhD/Research/Projects/LIFUP-PCI/Data/EEG';  % parent data folder. It includes in it and all the subdir all the dataset to be processed
mkdir(main_dir, '/derivatives'); % build output folder

%% choose datasets to process
all_datasets_list = dir([datafolder_parent '/**/*.vhdr']);

%% order the datasets and isolate names of the subjects
%check
all_datasets_list = table2struct(sortrows(struct2table(all_datasets_list), 'name')); %alphabetic order


%% select specific datasets
all_datasets_list=all_datasets_list(contains({all_datasets_list.name}, 'LIFUP-PCI'));
all_datasets_list=all_datasets_list(~contains({all_datasets_list.name}, '006'));
all_datasets_list=all_datasets_list(contains({all_datasets_list.name}, 'r.'));
%% name specific datasets
all_datasets_name =  extractBefore({all_datasets_list.name}, '.'); %make a list of just the name of the dataset in alphabetic order
% all_subjects_name =  char(extractBetween({all_datasets_list.name}, 11,13)); %make a list of just the subjects name
% all_subjects_name =  unique(all_subjects_name,'sorted'); %remove string with the same name

%% SCRIPT SETTING
overwrite_block_1=0;
overwrite_block_2=0;
overwrite_block_3=1;
overwrite_block_4=1;
overwrite_all=0;

%% Main loop - BLOCK 1
for maincounter=1:length(all_datasets_list) %loops through all datasets
    
    
    %build save name of the dataset
    current_datasets = all_datasets_name{maincounter}; %current dataset name
    current_subject = char(extractBetween(current_datasets, 11,13)); %current subj name
    curreent_session= char(extractBetween(current_datasets, 15,17)); %current dataset session (T0, T1... etc)
    if endsWith(current_datasets,'t')
        current_task='rstmseeg';
    elseif endsWith(current_datasets,'r')
        current_task='rseeg';
    end
    current_acq=char(extractBetween(current_datasets, 19,21)); %extaact if is pre LIFUP , post or delayed
    current_datasets_savename= ['sub-' current_subject '_ses-' curreent_session '_task-' current_task '_acq-' current_acq]; %name with the bids structure
    
    %save path for intermediates and figures
    current_output_folder= [main_dir '/derivatives/' extractBefore(current_datasets_savename, '_ses') '/'  'ses-' curreent_session '/eeg/TESA/' current_datasets_savename];
    mkdir(current_output_folder);
    
    
    %chek if step already done
    if  isfile([current_output_folder '/' current_datasets_savename '_TESA_step_1.set']) && overwrite_block_1==0 && overwrite_all==0
        disp(['***************** ' current_datasets_savename '_TESA_step_1.set ALREADY COMPUTED - SKIPPING *******************'])
    else
        
        %print which datasets it's being processed
        fprintf('/n******/n Processing %s/n******/n/n', ...
            current_datasets);
        
        %% load dataset
        %check the name of the current dataset in the list of .vhdr. Load the correct .vhdr from the corrisponding folder in all_datasets_list
        EEG = pop_loadbv(all_datasets_list(maincounter).folder,...
            [current_datasets '.vhdr']);
        
        %% Create a copy in the dataset in the intermediate folder
        pop_saveset(...
            EEG,...
            'filename', [current_datasets_savename '_raw.set'],...
            'filepath', current_output_folder);
        
        
        %% Read in the channel location file and get channel location
        EEG = pop_chanedit(EEG, 'lookup','standard-10-5-cap385.elp'); % Add the channel locations. Automatic eeglab channel setup
        
        %check electrode position
        figure; topoplot([],EEG.chanlocs, 'style', 'blank',  'electrodes', 'labelpoint', 'chaninfo', EEG.chaninfo);
        close
        %% remove extra signal
        if contains(current_datasets_savename,'rstmseeg') % if TMS-EEG
            % remove extra signal before first event and after last event (TMS-EEG)
            % make sure there are max 10 sec before the first event
            if strcmp(EEG.event(1).type, 'boundary')
                if EEG.event(2).latency>10*EEG.srate
                    
                    first_ev=EEG.event(2).latency;
                    EEG = pop_select( EEG, 'nopoint',[0 first_ev-(10*EEG.srate)] );
                else
                end
            end
            % make sure there are max 10 sec after the last event
            if EEG.event(end).latency+10*EEG.srate<(EEG.times(end)/1000)*EEG.srate
                
                last_ev=EEG.event(end).latency;
                EEG = pop_select( EEG, 'nopoint',[last_ev+10*EEG.srate (EEG.times(end)/1000)*EEG.srate] );
            else
            end
            
        elseif contains(current_datasets_savename,'rseeg') % if resting EEG
            %remove 10 sec in the begninning
            EEG = pop_select( EEG, 'rmtime', trim_time );
        end
        
        
        %% 1. Remove TMS pulse artifact
        if contains(current_datasets_savename,'rstmseeg') % if TMS-EEG
            % remove data around the TMS pulse
            EEG = pop_tesa_removedata( EEG, tms_removal_interval, [] ,{trigger_code});
            
            % Interpolate missing data around TMS pulse
            EEG = pop_tesa_interpdata( EEG, 'cubic', cubic_interp_interval );
        end
        
        %% 2. Hipass filter 0.1Hz
        EEG = pop_eegfiltnew(EEG, 'locutoff', hp_filt,'plotfreqz',1, 'usefftfilt', 1);
        close
        
        %% 3. Notch 60Hz
        EEG = pop_eegfiltnew(EEG, 'locutoff', notch_filt(1),'hicutoff',notch_filt(2),'revfilt',1,'plotfreqz',1,'usefftfilt', 1);
        close
        
        %% 4. Epoch data
        if contains(current_datasets_savename,'rstmseeg') % if TMS-EEG epoch normally
            EEG = pop_epoch( EEG, {trigger_code}, epoching , 'epochinfo', 'yes'); %check
        elseif contains(current_datasets_savename,'rseeg') % if resting EEG split in chunks of 10 secs
            max_number_chunks=floor(EEG.xmax/10);
            for x=1:max_number_chunks
                EEG = pop_editeventvals(EEG,'insert',{x,[],[],[],[],[],[],[],[],[]},'changefield',{x,'latency',10*x},'changefield',{x,'duration',10},'changefield',{x,'type','chunk'},'changefield',{x,'code','chunk'});
                
            end
            EEG = pop_epoch( EEG, {'chunk'}, [0 10] , 'epochinfo', 'yes'); %check
            
        end
        %% 5. Visual trial rejection
        pop_eegplot( EEG, 1, 1, 0);
        
        waitfor( findobj('parent', figure(1), 'string', 'UPDATE MARKS'), 'userdata');
        waitfor( findobj('parent', figure(1), 'string', 'Ok'), 'userdata');
        close all
        
        EEG = pop_rejepoch( EEG, EEG.reject.rejmanual ,0);
        
        %% 5b. Channel rejection
        ft_defaults
        EEG_dummy=EEG;
        
        data=eeglab2fieldtrip(EEG_dummy, 'timelock', 'none'); %convert format to fieldtrip
        data.dimord='chan_time';
        data.setname=EEG_dummy.setname;
        
        cfg=[];
        cfg.latency=[-0.1 0.3];
        data=ft_selectdata(cfg, data);
        
        cfg=[];
        cfg.layout='EEG1010.lay';
        cfg.viewmode='butterfly';
        ft_databrowser(cfg, data);
        
        
        channels2remove= input('Channels to remove (label). Type the channels (CaseSensitive!) separated by a blank space: ', 's');
        
        try
            channels2remove_cell=split(channels2remove);
            
            for x=1:length(channels2remove_cell)
                chan_index(x)=find(strcmp(channels2remove_cell(x),{EEG.chanlocs.labels}));
            end
            
            save([current_output_folder '/interpolated_channels'],  'channels2remove','chan_index');
            EEG = pop_interp(EEG, chan_index, 'spherical');
        catch
            
        end
        
        
        close all
        
        
        %% 5b. Channel rejection (deprecated)
        %         check=0;
        %         while check==0
        %             chan_rej=input('Do you want to remove any channel? y/n: ' ,'s');
        %             if strcmp(chan_rej,'y')
        %                 chan2rej=input('Type the channels (CaseSensitive!) separated by a blank space: ' ,'s');
        %                 chan2rej=split(chan2rej)';
        %                 EEG = pop_select( EEG, 'rmchannel',chan2rej);
        %                 check=1;
        %             elseif strcmp(chan_rej,'n')
        %                 disp('No channel to remove, continue')
        %                 check=1;
        %             end
        %         end
        
        %% 6. Reref to avg mastoids (TP9 TP10)
        
        EEG = pop_reref( EEG, final_ref); %check
        
        %% save part 1(automatic)
        EEG.setname= [current_datasets_savename '_TESA_step_1'];
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', current_output_folder);
        
    end
end
%% BLOCK 2

%find all completed step 1
processed_step1=dir([main_dir '/derivatives/**/*_TESA_step_1.set']);
% reconstruct old dataset name for comparison
x=1;
while x<=length(processed_step1)
original_dataset_name=['LIFUP-PCI_' char(extractBetween(processed_step1(x).name,'sub-','_')) '_' ...
    char(extractBetween(processed_step1(x).name,'ses-','_')) '_' ...
    char(extractBetween(processed_step1(x).name,'acq-','_')) '_'];
 
if contains(processed_step1(x).name,'rstmseeg')
    current_task_orig='t';
elseif contains(processed_step1(x).name,'rseeg')
    current_task_orig='r';
end

    original_dataset_name=[original_dataset_name current_task_orig '.vhdr'];

    %delete unwanted datasets
    if sum(strcmp(original_dataset_name, {all_datasets_list.name}))==1
        x=x+1;
    else
        processed_step1(x)=[];
    end
clear original_dataset_name
end


for maincounter=1:length(processed_step1) %loops through all datasets
    %% load data
    EEG=pop_loadset(processed_step1(maincounter).name, processed_step1(maincounter).folder);
    current_datasets_savename=extractBefore(EEG.setname,'_TESA');
    current_output_folder= [main_dir '/derivatives/' extractBefore(current_datasets_savename, '_ses') '/'  char(extractBetween(current_datasets_savename, '_','_task')) '/eeg/TESA/' current_datasets_savename];
    
    %chek if step already done
    if  isfile([current_output_folder '/' current_datasets_savename '_TESA_step_2_old.set']) && overwrite_block_2==0 && overwrite_all==0
        disp(['***************** ' current_datasets_savename '_TESA_step_2_old.set ALREADY COMPUTED - SKIPPING *******************'])
    else
        %% 7A. ICA extraction
        
%         EEG  = pop_runica(EEG,'interrupt', 'on', 'maxsteps', 1024, 'extended',0, 'pca', 30);
          EEG  = pop_runica(EEG,'interrupt', 'on', 'maxsteps', 1024, 'extended',0);

        EEG.setname = [current_datasets_savename '_TESA_step_2_old'];
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', current_output_folder);
    end
end
%% BLOCK 3

%find all completed step 2
processed_step2=dir([main_dir '/derivatives/**/*_TESA_step_2_old.set']);
% reconstruct old dataset name for comparison
x=1;
while x<=length(processed_step2)
original_dataset_name=['LIFUP-PCI_' char(extractBetween(processed_step2(x).name,'sub-','_')) '_' ...
    char(extractBetween(processed_step2(x).name,'ses-','_')) '_' ...
    char(extractBetween(processed_step2(x).name,'acq-','_')) '_'];
 
if contains(processed_step2(x).name,'rstmseeg')
    current_task_orig='t';
elseif contains(processed_step2(x).name,'rseeg')
    current_task_orig='r';
end

    original_dataset_name=[original_dataset_name current_task_orig '.vhdr'];

    %delete unwanted datasets
    if sum(strcmp(original_dataset_name, {all_datasets_list.name}))==1
        x=x+1;
    else
        processed_step2(x)=[];
    end
clear original_dataset_name
end

for maincounter=1:length(processed_step2) %loops through all datasets
    %% load data
    EEG=pop_loadset(processed_step2(maincounter).name, processed_step2(maincounter).folder);
    current_datasets_savename=extractBefore(EEG.setname,'_TESA');
    current_output_folder= [main_dir '/derivatives/' extractBefore(current_datasets_savename, '_ses') '/'  char(extractBetween(current_datasets_savename, '_','_task')) '/eeg/TESA/' current_datasets_savename];
    
    %chek if step already done
    if  isfile([current_output_folder '/' current_datasets_savename '_TESA_step_3.set']) && overwrite_block_3==0 && overwrite_all==0
        disp(['***************** ' current_datasets_savename '_TESA_step_3.set ALREADY COMPUTED - SKIPPING *******************'])
    else
%         if length(EEG.icachansind)==57
%               
%         EEG = pop_saveset(EEG, 'filename', [current_datasets_savename '_TESA_step_2_old_fullICA.set'], 'filepath', current_output_folder);
%         delete([current_output_folder '/' EEG.setname '.set'])
%         delete([current_output_folder '/' EEG.setname '.fdt'])
%       continue
%         else
%             continue
%         end
%         %% 7B. ICA selection
%         if contains(current_datasets_savename,'rstmseeg') % if TMS-EEG epoch normally
%             EEG = pop_tesa_compselect( EEG,...
%                 'figSize','medium',...
%                 'plotTimeX', [-100 300],...
%                 'muscleFreqIn', [7,75],...
%                 'moveElecs',{'AF7','F8'});
%         elseif contains(current_datasets_savename,'rseeg') % if resting EEG
%             EEG = pop_tesa_compselect( EEG,...
%                 'figSize','medium',...
%                 'plotTimeX', [EEG.xmin*1000 EEG.xmax*1000],...
%                 'tmsMuscle', 'off',...
%                 'muscleFreqIn', [7,75],...
%                 'moveElecs',{'AF7','F8'});s
%         end

        %% 7B. ICA selection
        if contains(current_datasets_savename,'rstmseeg') % if TMS-EEG epoch normally
            EEG = pop_tesa_compselect( EEG,...
                'tmsMuscle', 'off',...
                'blink', 'off',...
                'move', 'off',...
                'muscle', 'off',...
                'elecNoise', 'off',...
                'figSize','medium',...
                'plotTimeX', [-100 300],...
                'muscleFreqIn', [7,75],...
                'moveElecs',{'AF7','F8'});
        elseif contains(current_datasets_savename,'rseeg') % if resting EEG
            EEG = pop_tesa_compselect( EEG,...
                'tmsMuscle', 'off',...
                'blink', 'off',...
                'move', 'off',...
                'muscle', 'off',...
                'elecNoise', 'off',...
                'figSize','medium',...
                'plotTimeX', [EEG.xmin*1000 EEG.xmax*1000],...
                'tmsMuscle', 'off',...
                'muscleFreqIn', [7,75],...
                'moveElecs',{'AF7','F8'});
        end
        
        EEG.setname = [current_datasets_savename '_TESA_step_3'];
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', current_output_folder);
    end
end

%% BLOCK 4
%find all completed step 3
processed_step3=dir([main_dir '/derivatives/**/*_TESA_step_3.set']);
% reconstruct old dataset name for comparison
x=1;
while x<=length(processed_step3)
original_dataset_name=['LIFUP-PCI_' char(extractBetween(processed_step3(x).name,'sub-','_')) '_' ...
    char(extractBetween(processed_step3(x).name,'ses-','_')) '_' ...
    char(extractBetween(processed_step3(x).name,'acq-','_')) '_'];
 
if contains(processed_step3(x).name,'rstmseeg')
    current_task_orig='t';
elseif contains(processed_step3(x).name,'rseeg')
    current_task_orig='r';
end

    original_dataset_name=[original_dataset_name current_task_orig '.vhdr'];

    %delete unwanted datasets
    if sum(strcmp(original_dataset_name, {all_datasets_list.name}))==1
        x=x+1;
    else
        processed_step3(x)=[];
    end
clear original_dataset_name
end

for maincounter=1:length(processed_step3) %loops through all datasets
    %% load data
    EEG=pop_loadset(processed_step3(maincounter).name, processed_step3(maincounter).folder);
    current_datasets_savename=extractBefore(EEG.setname,'_TESA');
    current_output_folder= [main_dir '/derivatives/' extractBefore(current_datasets_savename, '_ses') '/'  char(extractBetween(current_datasets_savename, '_','_task')) '/eeg/TESA/' current_datasets_savename];
    
    %chek if step already done
    if  isfile([current_output_folder '/' current_datasets_savename '_TESA_Final.set']) && overwrite_block_4==0 && overwrite_all==0
        disp(['***************** ' current_datasets_savename '_TESA_Final.set ALREADY COMPUTED - SKIPPING *******************'])
    else
        
        %% 8. lowpass filter 45Hz
        EEG = pop_eegfiltnew(EEG, 'hicutoff',lp_filt,'plotfreqz',1,'usefftfilt', 1);
        close
        
        %% 8b. Interpolate back deleted channels (if any)
        
        %get removed channels
        dummy_chan_removed= EEG.chaninfo.removedchans;
        % remove references from removed channels (we do not want to
        % interpolate them)
        if isempty(final_ref)
        else
            for x=1:length(final_ref)
                dummy_chan_removed=dummy_chan_removed(~contains({dummy_chan_removed.labels},final_ref{x}));
            end
        end
        
        %if there are channel removed in prev steps, interpolate
        if isempty(dummy_chan_removed)
        else
            EEG = pop_interp(EEG, dummy_chan_removed, 'spherical');
        end
        
        %% 9. Downsample
        EEG = pop_resample( EEG, downsample);
        
        %% 10. crop epoch
        if contains(current_datasets_savename,'rstmseeg') % % if TMS-EEG
            EEG = pop_epoch( EEG, {trigger_code}, epoching_short , 'epochinfo', 'yes'); %check
            
            %% 11. Baseline correction
            
            EEG = pop_rmbase( EEG, baseline_interval);
        end
        %% remove EOG electrods
        EOGs_index=find(contains({EEG.chanlocs.labels}, 'EOG'));
        EEG=pop_select(EEG, 'nochannel', EOGs_index); %change
        
        %% Save point
        EEG.setname= [current_datasets_savename '_TESA_Final'];
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', current_output_folder);
        
        %% Plot the results
        % final TEP  scaled
        
        figure
        plot(EEG.times,mean(EEG.data, 3)); %plot avg trial TEP
        hold on
        
        if contains(current_datasets_savename,'rstmseeg')
            
            xlim([-100 400]);%restrict epoch
            ylim([-20 30]); % restrict amplitude range
        elseif contains(current_datasets_savename, 'rseeg')
            ylim([-10 10]); % restrict amplitude range
        end
        
        
        title('Final scaled avg reref');
        
        
        hold off
        %save figure  I had to comment the first saveas without format
        %specification because saveas without format specifics crushes
        %     saveas(gcf,...  %save .fig
        %         [current_output_folder '/' current_datasets_savename '_Final_scaled_avg_ref'])
        saveas(gcf,... %save .png
            [current_output_folder '/' current_datasets_savename '_TESA_Final'],...
            'png')
        close all
    end
end
