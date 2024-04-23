%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PCIst %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
close all
clc

main_dir=extractBefore(mfilename( 'fullpath' ), ['/' mfilename]); %define the folder in which the script is running
%%
addpath([main_dir '/PLUG-INs/eeglab_current/eeglab2020_0']); %eeglab

eeglab nogui
%% make save folder
mkdir([main_dir '/PCIst_results']);
savepath=[main_dir '/PCIst_results'];

%%
addpath([main_dir '/PLUG-INs']); %PCIst function

%% THIS CAN BE MADE SMARTER. CAN COMPUTE PCI JUST FOR THE SETs it did not compute yet

if isfile([savepath '/data_PCI_10ms.mat']) %skip if already computed
    load([savepath '/data_PCI_10ms.mat'])
else
    data_PCI=dir([main_dir '/derivatives/**/*rstmseeg*Final*.set']);

    for x=1:length(data_PCI)
        EEG=pop_loadset(data_PCI(x).name,...
            data_PCI(x).folder);

        %filter to 45Hz
        %         EEG = pop_eegfiltnew(EEG, 'hicutoff',45,'plotfreqz',1,'usefftfilt', 1);

        %downsample to 1000 Hz
        %         EEG = pop_resample( EEG, 1000);


        %     %% make sure early components' intensity are > 7 microV
        %
        %     [~, zero_index]=min(abs(EEG.times));
        %     eleven_index=zero_index+11*5;
        %     thirty_index=zero_index+30*5;
        %
        %     TEP=mean(EEG.data, 3);
        %
        %     if  max(max(TEP(:, eleven_index:thirty_index)))> 7

        % PCI calc
        data_PCI(x).PCIst_10ms=PCIst_10ms(mean(EEG.data,3), EEG.times);

        disp(['***dataset ' data_PCI(x).name ' DONE***' ]);

        %     else
        %         data_PCI(x).PCIst_7ms=NaN;
        %     disp(['***dataset ' data_PCI(x).name ' TEP too small!!  SKIPPING ***' ]);
        %     end

    end
    save([savepath '/data_PCI_10ms'],...
        'data_PCI');
end
%% reorder per condition
order_condition = readtable([main_dir '/order_conditions.xlsx']);

for x=1:length(data_PCI)
    % find sub number
    subnum=str2double(char(extractBetween(data_PCI(x).name, 5,7)));
    %find ses number
    sesnum=str2double(char(extractBetween(data_PCI(x).name, 13,15)));
    %find corrseponding target
    order_condition_sub=order_condition(order_condition.subNum==subnum,:);
    order_condition_sub_ses=order_condition_sub(order_condition_sub.ses==sesnum,:);
    %store target
    data_PCI(x).target=char(order_condition_sub_ses.target);
    data_PCI(x).target_num=order_condition_sub_ses.ses;
    data_PCI(x).sub_num=order_condition_sub_ses.subNum;
end

%% save var
save([savepath '/data_PCI_10ms'],...
        'data_PCI');
writetable(struct2table(data_PCI), [savepath '/data_PCI_10ms.csv'])
%% plot data



%delete existing figures
if exist([savepath '/figure_T.fig'], 'file')
    delete( [savepath '/figure_T.fig'])
end
if exist([savepath '/figure_G.fig'], 'file')
    delete( [savepath '/figure_G.fig'])
end
if exist([savepath '/figure_S.fig'], 'file')
    delete( [savepath '/figure_S.fig'])
end

%subject list
subj_list=strtok({data_PCI.name}, '_');
subj_list=unique(subj_list);

for sub_count=1:length(subj_list)
    current_sub= data_PCI(startsWith({data_PCI.name}, subj_list{sub_count})); %isolate one subject

    for cond_all_count=1:length(current_sub) %plot that subjext, one plot per condition
        if strcmp(current_sub(cond_all_count).target, 'TAL')
            %Thalamus
            current_sub_T= current_sub(strcmp({current_sub.target}, 'TAL')); %isolate condition of that subject
            %reorder condition pre - post - delayed
            current_sub_T_ordered(1)= current_sub_T(contains({current_sub_T.name}, 'pre'));
            current_sub_T_ordered(2)= current_sub_T(contains({current_sub_T.name}, 'pos'));
            try %delayed sometimes is missing
                current_sub_T_ordered(3)= current_sub_T(contains({current_sub_T.name}, 'del'));
            catch
            end

            if exist([savepath '/figure_T.fig'], 'file')
                figure_T=  openfig([savepath '/figure_T']);
            else
                figure_T=figure;
            end
            hold on

            plot(1:length(current_sub_T_ordered), [current_sub_T_ordered(1:end).PCIst_10ms], '-x')
            text(1:length(current_sub_T_ordered), [current_sub_T_ordered(1:end).PCIst_10ms], strtok({current_sub_T_ordered(1:end).name}, '_'),'VerticalAlignment','bottom','HorizontalAlignment','right')

            hold on

            title('Thalamus')
            xlim([0 4]);
            xticks([1 2 3]);
            xticklabels({'pre', 'post', 'delayed'})
            ylabel('PCIst');
            %             yline(30);
            ylim([20 65]);
            hold off

            savefig(figure_T, [savepath '/figure_T']);
            close all

        elseif strcmp(current_sub(cond_all_count).target, 'GPE')
            %GPe

            current_sub_G= current_sub(strcmp({current_sub.target}, 'GPE')); %isolate condition of that subject
            %reorder condition pre - post - delayed
            current_sub_G_ordered(1)= current_sub_G(contains({current_sub_G.name}, 'pre'));
            current_sub_G_ordered(2)= current_sub_G(contains({current_sub_G.name}, 'pos'));
            try %delayed sometimes is missing
                current_sub_G_ordered(3)= current_sub_G(contains({current_sub_G.name}, 'del'));
            catch
            end

            if exist([savepath '/figure_G.fig'], 'file')
                figure_G= openfig([savepath '/figure_G']);
            else
                figure_G=figure;
            end
            hold on

            plot(1:length(current_sub_G_ordered), [current_sub_G_ordered(1:end).PCIst_10ms], '-x')
            text(1:length(current_sub_G_ordered), [current_sub_G_ordered(1:end).PCIst_10ms], strtok({current_sub_G_ordered(1:end).name}, '_'),'VerticalAlignment','bottom','HorizontalAlignment','right')

            hold on

            title('GPe')
            xlim([0 4]);
            xticks([1 2 3]);
            xticklabels({'pre', 'post', 'delayed'})
            ylabel('PCIst');
            %yline(30);
            ylim([20 65]);
            hold off

            savefig(figure_G, [savepath '/figure_G']);
            close all

        elseif strcmp(current_sub(cond_all_count).target, 'SHA')
            %Sham

            current_sub_S= current_sub(strcmp({current_sub.target}, 'SHA')); %isolate condition of that subject
            %reorder condition pre - post - delayed
            current_sub_S_ordered(1)= current_sub_S(contains({current_sub_S.name}, 'pre'));
            current_sub_S_ordered(2)= current_sub_S(contains({current_sub_S.name}, 'pos'));
            try %delayed sometimes is missing
                current_sub_S_ordered(3)= current_sub_S(contains({current_sub_S.name}, 'del'));
            catch
            end

            if exist([savepath '/figure_S.fig'], 'file')
                figure_S=  openfig([savepath '/figure_S']);
            else
                figure_S=figure;
            end
            hold on

            plot(1:length(current_sub_S_ordered), [current_sub_S_ordered(1:end).PCIst_10ms], '-x')
            text(1:length(current_sub_S_ordered), [current_sub_S_ordered(1:end).PCIst_10ms], strtok({current_sub_S_ordered(1:end).name}, '_'),'VerticalAlignment','bottom','HorizontalAlignment','right')

            hold on

            title('Sham')
            xlim([0 4]);
            xticks([1 2 3]);
            xticklabels({'pre', 'post', 'delayed'})
            ylabel('PCIst');
            %             yline(30);
            ylim([20 65]);
            hold off

            savefig(figure_S, [savepath '/figure_S']);
            close all
        end

    end
    clear current_sub

end

%% combine in one fig

% Load saved figures
fig_T=hgload([savepath '/figure_T.fig']);
fig_G=hgload([savepath '/figure_G.fig']);
fig_S=hgload([savepath '/figure_S.fig']);

% Prepare subplots
figure('units','normalized','outerposition',[0 0 1 1]);
figure_all(1)=subplot(1,3,1);
hold on

title('Thalamus')
xlim([0 4]);
xticks([1 2 3]);
xticklabels({'pre', 'post', 'delayed'})
ylabel('PCIst');
% yline(30);
ylim([20 60]);
hold off

figure_all(2)=subplot(1,3,2);
hold on

title('GPe')
xlim([0 4]);
xticks([1 2 3]);
xticklabels({'pre', 'post', 'delayed'})
ylabel('PCIst');
% yline(30);
ylim([20 60]);
hold off

figure_all(3)=subplot(1,3,3);
hold on

title('Sham')
xlim([0 4]);
xticks([1 2 3]);
xticklabels({'pre', 'post', 'delayed'})
ylabel('PCIst');
% yline(30);
ylim([20 60]);
hold off

% Paste figures on the subplots
copyobj(allchild(get(fig_T,'CurrentAxes')),figure_all(1));
copyobj(allchild(get(fig_G,'CurrentAxes')),figure_all(2));
copyobj(allchild(get(fig_S,'CurrentAxes')),figure_all(3));


savefig(gcf, [savepath '/figure_all']);
saveas(gcf,[savepath '/figure_all'],'svg')
close all
