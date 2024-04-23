#!/bin/sh
#$ -cwd
# error = Merged with joblog
#$ -o joblog.$JOB_ID.$TASK_ID
#$ -j y
#$ -pe shared 1
#$ -l h_rt=1:00:00,h_data=6G ## change this line for scripts >24h long
## #$ -l h_rt=24:00:00,h_data=6G, highp
#  Job array indexes
#$ -t 1-1:1 ## 3-10:1

##################################################################################################
##################################################################################################

echo 'running script 11a...'
echo ''

##################################################################################################
############################               setting up                 ############################
##################################################################################################

echo 'loading modules...'
echo ''

. /u/local/Modules/default/init/modules.sh
module use /u/project/CCN/apps/modulefiles
module load ccnscripts
module load matlab/R2020b
module load freesurfer/7.4.1
module load fsl
module load mricron/20200331

export NO_FSL_JOBS=false #turn on off fsl subjobs to help grid

echo 'defining script directory...'
echo ''

scriptdir=/u/project/monti/Analysis/tus-comp/scripts
cd ${scriptdir}

##################################################################################################
############################             defining objects             ############################
##################################################################################################

###############
### subject ###
###############

subj=$1
fullsubj=${subj}

echo 'defining subject... ' ${subj}
echo ''

#################
### variables ###
#################

### directories ###

echo 'defining directories...'
echo ''

maindir=/u/project/monti/Analysis/tus-comp
acqdir=${maindir}/acq_params
MNIdir=${maindir}/MNItemplates
tractdir=${maindir}/tractography
maskdir=${maindir}/masks
datadir=${maindir}/subjects/${fullsubj}
regdir=${datadir}/registrations_fsl

### prefixes ###

echo 'defining prefixes...'
echo ''

subjpref=${datadir}/${fullsubj}
regpref=${regdir}/${fullsubj}
dtipref=${subjpref}_dti
tractpref=${tractdir}/${fullsubj}

### files ###

echo 'defining files...'
echo ''

t1=${subjpref}_anat
t1brain=${t1}_brain
t1brainmask=${t1brain}_mask

##################################################################################################
############################           tractography masks             ############################
##################################################################################################

### thalamus ###

echo 'creating thalamus tractography mask, thresholded...'
echo ''

#creating thalamus tractography mask thresholded 80 and up, -thr 80
fslmaths ${tractpref}_left_central_thalamus_to_right_parietal_way-spleniumCC_nostop/${fullsubj}_left_central_thalamus_to_right_parietal_way-spleniumCC_nostop_T1_thr0.10per.nii.gz -thr 80 ${tractpref}_left_central_thalamus_to_right_parietal_way-spleniumCC_nostop/${fullsubj}_left_central_thalamus_thresholded_mask.nii.gz

#copying file over to subject folder
cp ${tractpref}_left_central_thalamus_to_right_parietal_way-spleniumCC_nostop/${fullsubj}_left_central_thalamus_thresholded_mask.nii.gz ${subjpref}_dti_left_central_thalamus_thresholded_mask.nii.gz

### GPe ###

echo 'creating GPe tractography mask, thresholded...'
echo ''

#creating GPe tractography mask thresholded 80 and up, -thr 80
fslmaths ${tractpref}_left_GPe_to_right_parietal_way-spleniumCC_nostop/${fullsubj}_left_GPe_to_right_parietal_way-spleniumCC_nostop_T1_thr0.10per.nii.gz -thr 80 ${tractpref}_left_GPe_to_right_parietal_way-spleniumCC_nostop/${fullsubj}_left_GPe_thresholded_mask.nii.gz

#copying file over to subject folder
cp ${tractpref}_left_GPe_to_right_parietal_way-spleniumCC_nostop/${fullsubj}_left_GPe_thresholded_mask.nii.gz ${subjpref}_dti_left_GPe_thresholded_mask.nii.gz

##################################################################################################
############################         joint tractography mask          ############################
##################################################################################################

echo 'binarizing thalamus and GPe tractography mask...'
echo ''

#binarize thalamus tractography 
fslmaths ${subjpref}_dti_left_central_thalamus_thresholded_mask.nii.gz -bin -mul 1000 ${subjpref}_dti_left_central_thalamus_thresholded_binarized_mask.nii.gz

#binarize GPe tractography 
fslmaths ${subjpref}_dti_left_GPe_thresholded_mask.nii.gz -bin -mul 1000 ${subjpref}_dti_left_GPe_thresholded_binarized_mask.nii.gz

echo 'combining binarized thalamus and GPe tractography mask...'
echo ''

#add the images and threshold
fslmaths ${subjpref}_dti_left_central_thalamus_thresholded_binarized_mask.nii.gz -add ${subjpref}_dti_left_GPe_thresholded_binarized_mask.nii.gz ${subjpref}_dti_left_central_thalamus_GPe_combined_mask.nii.gz

echo 'thresholding combined binarized thalamus and GPe tractography mask...'
echo ''

fslmaths ${subjpref}_dti_left_central_thalamus_GPe_combined_mask.nii.gz -thr 1500 ${subjpref}_dti_left_central_thalamus_GPe_combined_thresholded_mask.nii.gz

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
