#!/bin/sh
#$ -cwd
# error = Merged with joblog
#$ -o joblog.$JOB_ID.$TASK_ID
#$ -j y
#$ -pe shared 1
## #$ -l h_rt=32:00:00,h_data=12G ## change this line for scripts >24h long
#$ -l h_rt=32:00:00,h_data=12G,highp ## change this line for scripts >24h long
## #$ -l h_rt=24:00:00,h_data=6G, highp
#  Job array indexes
#$ -t 1-1:1 ## 3-10:1

##################################################################################################
##################################################################################################

echo ''
echo 'running script 10a...'
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
FAdir=${datadir}/dtifit
mkdir $FAdir

## prefixes ##

echo 'defining prefixes...'
echo ''

subjpref=${datadir}/${fullsubj}
regpref=${regdir}/${fullsubj}
dtipref=${subjpref}_dti
FApref=${FAdir}/${fullsubj}_dtifit

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

## for registrations ##

space1=b0
space2=T1
space3=MNI1mm

step1for=${space1}_to_${space2}
step1inv=${space2}_to_${space1}
step2for=${space2}_to_${space3}
step2inv=${space3}_to_${space2}

##################################################################################################
############################        dtifit for tensor fitting         ############################
##################################################################################################

# for FSL documentation, see https://users.fmrib.ox.ac.uk/~behrens/fdt_docs/fdt_dtifit.html or http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide#DTIFIT, or type/enter function name into command line

echo 'running dtifit for tensor fitting...'
echo ''

dtifit --data=${datadir}/data.nii.gz --out=${FApref} --mask=${datadir}/nodif_brain_mask.nii.gz --bvecs=${datadir}/${fullsubj}_dti_AP_bvec_eddy_trans_truncated.txt --bvals=${datadir}/${fullsubj}_dti_AP_bval_trans_truncated.txt --sse --wls --save_tensor

  # runs FSL's dtifit function to estimate the tensor for each voxel
  # note: this step is not necessary for tractography (since BEDPOST creates the necessary diffusion profile for PROBTRACK), but this step is necessary for any subsequent statistical nalysis which involves tensor-derived estimates of the "integrity" of white matter (i.e.,the diffusivity-based measures of FA, MD, AD, etc)
    # outputs a single .nii.gz file for each tensor-based diffusivity metric (FA, MD, etc)
    # (--wls) -> do weighted-least squares option (more accurate than the traditional OLS default)
    # (--sse --save_tensor) -> outputs the sum of squared error and the tensor details, can be useful if you want to scrutinize the tensor fitting procedure
    # (--data) -> this is the final preprocessed/QCed DWI data file created from the DTIPREP script (note, the data.nii.gz in the bedpostX folder is the identical copy of this data file, ${SUBJ}_dwi_QCed_fixorient.nii.gz)
    # (--mask) -> the brain mask (of the b0 image) of the final preprocessed diffusion file (the mask created from the BEDPOSTX script, based on the QCed DWI data created from the DTIPREP script) 
    # (--bvals --bveccs) -> the final bvals and bvecs of the QCed DWI data (created from the DTIPREP script)

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo ''
echo 'done'
echo ''
