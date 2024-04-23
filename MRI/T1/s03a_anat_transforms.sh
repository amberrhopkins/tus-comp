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
echo 'running script 3a...'
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

export NO_FSL_JOBS=true #turn on off fsl subjobs to help grid

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
sub=${subj}

echo 'defining subject... ' ${sub}
echo ''

#################
### variables ###
#################

## directories ##

echo 'defining directories...'
echo ''

maindir=/u/project/monti/Analysis/tus-comp
acqdir=${maindir}/acq_params
MNIdir=${maindir}/MNItemplates
tractdir=${maindir}/tractography
datadir=${maindir}/subjects/${sub}
regdir=${datadir}/registrations_fsl
fsdir=${datadir}/freesurfer/${sub}
maskdir=${maindir}/masks

## prefixes ##

echo 'defining prefixes...'
echo ''

subjpref=${datadir}/${sub}
regpref=${regdir}/${sub}
dtipref=${subjpref}_dti

## files ##

echo 'defining files...'
echo ''

acqparam_file1=${acqdir}/dti_acq_params
acqparam_file2=${acqdir}/dti_acq_params_APonly

b0=${datadir}/nodif_brain
b0mask=${b0}_mask

t1=${subjpref}_anat
t1brain=${t1}_brain_fs
t1brainmask=${t1brain}_mask

MNI1mm_head=${FSLDIR}/data/standard/MNI152_T1_1mm
MNI1mm_brain=${FSLDIR}/data/standard/MNI152_T1_1mm_brain
MNI1mm_config=/u/project/monti/Analysis/tus-comp/MNItemplates/T1_2_MNI152_1mm.conf

dti_AP=${dtipref}_AP
bval_AP=${dti_AP}_bval
bvec_AP=${dti_AP}_bvec

dti_PA=${dtipref}_PA
bval_PA=${dti_PA}_bval
bvec_PA=${dti_PA}_bvec

## for fsl registrations ##

step2for=${regpref}_T1toMNI
step2inv=${regpref}_MNItoT1

##################################################################################################
####################                      t1 registration                    #####################
##################################################################################################

echo 'registering T1 to MNI standard space...'
echo ''

echo 'linear registrations with flirt...'
echo ''

# using FLIRT, see FSL's documentation here: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FLIRT/UserGuide

# T1 to MNI #
flirt -in ${t1}.nii.gz -ref ${MNI1mm_head}.nii.gz -omat ${step2for}.mat -out ${step2for}_flirt -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12 -cost corratio

# MNI to T1 #
convert_xfm -omat ${step2inv}.mat -inverse ${step2for}.mat

echo 'non-linear registrations with fnirt...'
echo ''

# using FNIRT, see FSL's documentation here: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FNIRT/UserGuide

# T1 to MNI #
fnirt --in=${t1}.nii.gz --aff=${step2for}.mat --cout=${step2for}_warp --config=${MNI1mm_config} --iout=${step2for}_fnirt

# MNI to T1 #
invwarp -w ${step2for}_warp -o ${step2inv}_warp -r ${t1}.nii.gz

##################################################################################################
#################           warp freesurfer files onto t1 image                ###################
##################################################################################################

echo 'warping fs files onto T1...'
echo ''

## brain extraction ##

echo 'brain extraction...'
echo ''

mri_convert ${subjpref}_anat_brain_fs_MNI1mm.mgz ${subjpref}_anat_brain_fs_MNI1mm.nii.gz
applywarp -i ${subjpref}_anat_brain_fs_MNI1mm.nii.gz -o ${subjpref}_anat_brain_fs_T1.nii.gz -r ${t1}.nii.gz -w ${step2inv}_warp.nii.gz --interp=nn
fslmaths ${subjpref}_anat_brain_fs_T1.nii.gz -bin -mul 1000 ${subjpref}_anat_brain_mask.nii.gz

cp ${subjpref}_anat_brain_fs_T1.nii.gz ${subjpref}_anat_brain.nii.gz

echo ''

## left central thalamus ##

echo 'left central thalamus...'
echo ''

mri_convert ${subjpref}_roi_left_central_thalamus_mask_fs_MNI1mm.mgz ${subjpref}_roi_left_central_thalamus_mask_fs_MNI1mm.nii.gz
applywarp -i ${subjpref}_roi_left_central_thalamus_mask_fs_MNI1mm.nii.gz -o ${subjpref}_roi_left_central_thalamus_mask_fs_T1.nii.gz -r ${t1}.nii.gz -w ${step2inv}_warp.nii.gz --interp=nn
fslmaths ${subjpref}_roi_left_central_thalamus_mask_fs_T1.nii.gz -bin -mul 1000 ${subjpref}_roi_left_central_thalamus_mask_fs_T1.nii.gz

echo ''

##################################################################################################
#################               warp rois onto the T1 image                    ###################
##################################################################################################

echo 'warping MNI rois onto T1...'
echo ''

## left GPe ##

echo 'left GPe...'
echo ''

cp ${maskdir}/roi_left_GPe_mask_MNI1mm.nii.gz ${subjpref}_roi_left_GPe_mask_MNI1mm.nii.gz
applywarp -i ${maskdir}/roi_left_GPe_mask_MNI1mm.nii.gz -o ${subjpref}_roi_left_GPe_mask_T1.nii.gz -r ${t1}.nii.gz -w ${step2inv}_warp.nii.gz --interp=nn
fslmaths ${subjpref}_roi_left_GPe_mask_T1.nii.gz -bin -mul 1000 ${subjpref}_roi_left_GPe_mask_T1.nii.gz

## body and splenium of the CC ##

echo 'body and splenium of the CC...'
echo ''

cp ${maskdir}/roi_bodyCC_spleniumCC_mask_MNI1mm.nii.gz ${subjpref}_roi_bodyCC_spleniumCC_mask_MNI1mm.nii.gz
applywarp -i ${maskdir}/roi_bodyCC_spleniumCC_mask_MNI1mm.nii.gz -o ${subjpref}_roi_bodyCC_spleniumCC_mask_T1.nii.gz -r ${t1}.nii.gz -w ${step2inv}_warp.nii.gz --interp=nn
fslmaths ${subjpref}_roi_bodyCC_spleniumCC_mask_T1.nii.gz -bin -mul 1000 ${subjpref}_roi_bodyCC_spleniumCC_mask_T1.nii.gz

## right parietal ##

echo 'right parietal...'
echo ''

cp ${maskdir}/roi_right_parietal_mask_MNI1mm.nii.gz ${subjpref}_roi_right_parietal_mask_MNI1mm.nii.gz
applywarp -i ${maskdir}/roi_right_parietal_mask_MNI1mm.nii.gz -o ${subjpref}_roi_right_parietal_mask_T1.nii.gz -r ${t1}.nii.gz -w ${step2inv}_warp.nii.gz --interp=nn
fslmaths ${subjpref}_roi_right_parietal_mask_T1.nii.gz -bin -mul 1000 ${subjpref}_roi_right_parietal_mask_T1.nii.gz

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
