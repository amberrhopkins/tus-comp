#!/bin/sh
#$ -cwd
# error = Merged with joblog
#$ -o joblog.$JOB_ID.$TASK_ID
#$ -j y
#$ -pe shared 1
##$ -l h_rt=32:00:00,h_data=12G ## change this line for scripts >24h long
#$ -l h_rt=32:00:00,h_data=12G,highp ## change this line for scripts >24h long
## #$ -l h_rt=24:00:00,h_data=6G, highp
#  Job array indexes
#$ -t 1-1:1 ## 3-10:1

##################################################################################################
##################################################################################################

echo ''
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

## directories ##

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
MNI1mm_conf=/u/project/monti/Analysis/tus-comp/MNItemplates/T1_2_MNI152_1mm.conf

dti_AP=${dtipref}_AP
bval_AP=${dti_AP}_bval
bvec_AP=${dti_AP}_bvec

dti_PA=${dtipref}_PA
bval_PA=${dti_PA}_bval
bvec_PA=${dti_PA}_bvec

## for FSL registrations ##

step1for=${regpref}_DIFFtoT1
step1inv=${regpref}_T1toDIFF
step2for=${regpref}_T1toMNI
step2inv=${regpref}_MNItoT1
step3for=${regpref}_DIFFtoMNI
step3inv=${regpref}_MNItoDIFF

##################################################################################################
############################     linear registrations with flirt      ############################
##################################################################################################

### linear registrations ###

echo 'running linear registrations with flirt...'
echo ''

# using FLIRT, see FSL's documentation here: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FLIRT/UserGuide

## diffusion to T1 ## 

epi_reg --epi=${b0}.nii.gz --t1=${t1}.nii.gz --t1brain=${t1brain}.nii.gz --out=${step1for} -v > ${regpref}_epireg_log.txt

## T1 to diffusion ##

convert_xfm -omat ${step1inv}.mat -inverse ${step1for}.mat

## diffusion to MNI ##

convert_xfm -omat ${step3for}.mat -concat ${step2for}.mat ${step1for}.mat

  flirt -init ${step3for}.mat -applyxfm -in ${b0}.nii.gz -ref ${MNI1mm_brain}.nii.gz -out ${step3for}_flirt

## MNI to diffusion ##

convert_xfm -omat ${step3inv}.mat -inverse ${step3for}.mat

##################################################################################################
############################    nonlinear registrations with fmirt    ############################
##################################################################################################

echo 'running nonlinear registrations with fnirt...'
echo ''

# using FNIRT, see FSL's documentation here: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FNIRT/UserGuide

## diffusion to MNI ##

convertwarp -o ${step3for}_warp -r ${MNI1mm_head}.nii.gz -m ${step1for}.mat -w ${step2for}_warp

  applywarp --ref=${MNI1mm_head}.nii.gz --in=${b0}.nii.gz --warp=${step3for}_warp --out=${step3for}_fnirt

## MNI to diffusion ##

convertwarp -o ${step3inv}_warp -r ${b0mask}.nii.gz -w ${step2inv}_warp --postmat=${step1inv}.mat

  applywarp --ref=${b0}.nii.gz --in=${MNI1mm_brain}.nii.gz --warp=${step3inv}_warp --out=${step3inv}_fnirt

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
