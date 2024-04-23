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
echo 'running script 2a...'
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
maskdir=${maindir}/masks
subdir=${maindir}/subjects/${sub}
regdir=${subdir}/registrations_fsl
fsdir=${subdir}/freesurfer

## prefixes ##

echo 'defining prefixes...'
echo ''

subjpref=${subdir}/${sub}
regpref=${regdir}/${sub}
dtipref=${subjpref}_dti

## files ##

echo 'defining files...'
echo ''

acqparam_file1=${acqdir}/dti_acq_params
acqparam_file2=${acqdir}/dti_acq_params_APonly

b0=${subdir}/nodif_brain
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
##########################          recon-all with freesurfer           ##########################
##################################################################################################

echo 'processing t1-weighted data with recon-all in freesurfer...'
echo ''

#https://freesurfer.net/fswiki/ThalamicNuclei

recon-all -all -subjid ${sub} -i ${t1}.nii.gz -sd ${fsdir}

##################################################################################################
##########################          recon-all with freesurfer           ##########################
##################################################################################################

echo 'segmenting thalamic nuclei...'
echo ''

#https://freesurfer.net/fswiki/ThalamicNuclei

segmentThalamicNuclei.sh ${sub} ${fsdir}

##################################################################################################
##########################              isolate left CM                 ##########################
##################################################################################################

echo 'isolating left central nuclei...'
echo ''

fsdir=${subdir}/freesurfer/${sub}

#https://surfer.nmr.mgh.harvard.edu/fswiki/mri_binarize

# left CM #
mri_binarize --i ${fsdir}/mri/ThalamicNuclei.v13.T1.mgz --o ${fsdir}/mri/ThalamicNuclei_leftCM.mgz --match 8106 --binval 1

# left MDl #
mri_binarize --i ${fsdir}/mri/ThalamicNuclei.v13.T1.mgz --o ${fsdir}/mri/ThalamicNuclei_leftMDl.mgz --match 8112 --binval 1

# left CeM #
mri_binarize --i ${fsdir}/mri/ThalamicNuclei.v13.T1.mgz --o ${fsdir}/mri/ThalamicNuclei_leftCeM.mgz --match 8104 --binval 1

# left CL #
mri_binarize --i ${fsdir}/mri/ThalamicNuclei.v13.T1.mgz --o ${fsdir}/mri/ThalamicNuclei_leftCL.mgz --match 8105 --binval 1

echo 'creating central nuclei mask...'
echo ''

mri_concat --sum --o ${fsdir}/mri/ThalamicNuclei_left_central_thalamus.mgz \
    --i ${fsdir}/mri/ThalamicNuclei_leftCL.mgz \
    --i ${fsdir}/mri/ThalamicNuclei_leftCM.mgz \
    --i ${fsdir}/mri/ThalamicNuclei_leftMDl.mgz \
    --i ${fsdir}/mri/ThalamicNuclei_leftCeM.mgz \

##################################################################################################
#####################               copy fs files to sub dir                 #####################
##################################################################################################

echo ''
echo 'bringing extracted brain and left central thalamic nuclei to subject folder...'
echo ''

cp ${fsdir}/mri/transforms/talairach.xfm /u/project/monti/Analysis/tus-comp/subjects/${sub}/${sub}_talairach_fs.xfm
cp ${fsdir}/mri/brain.mgz /u/project/monti/Analysis/tus-comp/subjects/${sub}/${sub}_anat_brain_fs.mgz
cp ${fsdir}/mri/ThalamicNuclei_left_central_thalamus.mgz /u/project/monti/Analysis/tus-comp/subjects/${sub}/${sub}_roi_left_central_thalamus_mask_fs.mgz

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
