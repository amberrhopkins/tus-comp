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

echo ''
echo 'running script 12a...'
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

## prefixes ##

echo 'defining prefixes...'
echo ''

subjpref=${datadir}/${fullsubj}
regpref=${regdir}/${fullsubj}
dtipref=${subjpref}_dti

## files ##

echo 'defining files...'
echo ''

acqparam_file1=${acqdir}/dti_acq_params
acqparam_file2=${acqdir}/dti_acq_params_APonly

b0=${datadir}/nodif_brain
b0mask=${b0}_mask

t1=${subjpref}_anat
t1brain=${t1}_brain
t1brainmask=${t1brain}_mask

MNI1mm_head=${FSLDIR}/data/standard/MNI152_T1_1mm
MNI1mm_brain=${FSLDIR}/data/standard/MNI152_T1_1mm_brain

dti_AP=${dtipref}_AP
bval_AP=${dti_AP}_bval
bvec_AP=${dti_AP}_bvec

dti_PA=${dtipref}_PA
bval_PA=${dti_PA}_bval
bvec_PA=${dti_PA}_bvec

##################################################################################################
############################         registrations for rois           ############################
##################################################################################################

echo 'transforming rois to diffusion space...'
echo ''

## corpus callosum ##

echo 'body and splenium of corpus callosum...'
echo ''

applywarp -i ${subjpref}_roi_bodyCC_spleniumCC_mask_MNI1mm.nii.gz -o ${subjpref}_roi_bodyCC_spleniumCC_mask_DIFF.nii.gz -r ${datadir}/nodif_brain.nii.gz -w ${regpref}_MNItoDIFF_warp.nii.gz --interp=nn

## right parietal ##

echo 'right parietal...'
echo ''

applywarp -i ${subjpref}_roi_right_parietal_mask_MNI1mm.nii.gz -o ${subjpref}_roi_right_parietal_mask_DIFF.nii.gz -r ${datadir}/nodif_brain.nii.gz -w ${regpref}_MNItoDIFF_warp.nii.gz --interp=nn

## left GPe ##

echo 'left GPe...'
echo ''

applywarp -i ${subjpref}_roi_left_GPe_mask_MNI1mm.nii.gz -o ${subjpref}_roi_left_GPe_mask_DIFF.nii.gz -r ${datadir}/nodif_brain.nii.gz -w ${regpref}_MNItoDIFF_warp.nii.gz --interp=nn

## left central thalamus ##

echo 'left central thalamus...'
echo ''

applywarp -i ${subjpref}_roi_left_central_thalamus_mask_fs_MNI1mm.nii.gz -o ${subjpref}_roi_left_central_thalamus_mask_fs_DIFF.nii.gz -r ${datadir}/nodif_brain.nii.gz -w ${regpref}_MNItoDIFF_warp.nii.gz --interp=nn

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
