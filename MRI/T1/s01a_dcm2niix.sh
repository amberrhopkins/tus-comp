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
echo 'running script 1a...'
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

sub_input=$1
sub=${sub_input}

echo 'defining subject... ' ${sub_input}
echo ''

#################
### variables ###
#################

## directories ##

echo 'defining directories...'
echo ''

mridir=/u/project/monti/Data/tus-comp
projdir=/u/project/monti/Analysis/tus-comp
acqdir=${projdir}/acq_params
mnidir=${projdir}/MNItemplates
tractdir=${projdir}/tractography
maskdir=${projdir}/masks
datadir=${projdir}/subjects/${sub}
mkdir $datadir
regdir=${datadir}/registrations_fsl
mkdir $regdir
fsdir=${datadir}/freesurfer
mkdir $fsdir

## prefixes ##

echo 'defining prefixes...'
echo ''

subpref=${datadir}/${sub}
regpref=${regdir}/${sub}
dtipref=${subpref}_dti

## files ##

echo 'defining files...'
echo ''

acqparam_file1=${acqdir}/dti_acq_params
acqparam_file2=${acqdir}/dti_acq_params_APonly

b0=${datadir}/nodif_brain
b0mask=${b0}_mask

t1=${subpref}_anat
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
############################                 dcm2niix                 ############################
##################################################################################################

echo 'converting from dcm to niix with dcm2niix...'
echo ''

dcm2niix -i y -x y -z y ${mridir}/${sub}/*Prisma*

##################################################################################################
###########################      copying files to subject folder       ###########################
##################################################################################################

echo 'copying converted files to subject folder...'
echo ''

cp ${mridir}/${sub}/*Prisma*/*MPRAGE*Crop*.nii.gz ${datadir}/${sub}_anat.nii.gz
cp ${mridir}/${sub}/*Prisma*/*DTI*_AP*.nii.gz ${datadir}/${sub}_dti_AP.nii.gz
cp ${mridir}/${sub}/*Prisma*/*DTI*_PA*.nii.gz ${datadir}/${sub}_dti_PA.nii.gz
cp ${mridir}/${sub}/*Prisma*/*DTI*_AP*.bval ${datadir}/${sub}_dti_AP_bval.txt
cp ${mridir}/${sub}/*Prisma*/*DTI*_AP*.bvec ${datadir}/${sub}_dti_AP_bvec.txt
cp ${mridir}/${sub}/*Prisma*/*DTI*_PA*.bval ${datadir}/${sub}_dti_PA_bval.txt
cp ${mridir}/${sub}/*Prisma*/*DTI*_PA*.bvec ${datadir}/${sub}_dti_PA_bvec.txt

rm $mridir/${sub}/Prisma*/*

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
