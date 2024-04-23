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
echo 'running script 13a...'
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
bedpostdir=${datadir}.bedpostX

## prefixes ##

echo 'defining prefixes...'
echo ''

subjpref=${datadir}/${fullsubj}
regpref=${regdir}/${fullsubj}
dtipref=${subjpref}_dti
t1_pref=${datadir}/${fullsubj}

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
############################               tractography               ############################
##################################################################################################

## creating text file listing waypoints to use with probtrackx2 ##

echo 'creating text file of waypoints...'
echo ''

echo ${subjpref}_roi_bodyCC_spleniumCC_mask_DIFF.nii.gz > ${datadir}/${fullsubj}_waypoints_list.txt
echo ${subjpref}_roi_right_parietal_mask_DIFF.nii.gz >> ${datadir}/${fullsubj}_waypoints_list.txt

##################################################################################################

## left GPe ##

echo 'conducting tractography from left GPe to right parietal cortex...'
echo ''

echo 'running probtrackx2...'
echo ''

seed=${subjpref}_roi_left_GPe_mask_DIFF
target=${subjpref}_roi_right_parietal_mask_DIFF
outname=${fullsubj}_left_GPe_to_right_parietal_way-spleniumCC_nostop
outdir=${tractdir}/${outname}

probtrackx2 -x ${seed}.nii.gz --randfib=0 --fibst=1 --forcedir --opd --ompl --pd -l --distthresh=12 --onewaycondition -c 0.2 -S 2000 --steplength=0.5 -P 5000 --fibthresh=0.01 --sampvox=1.2 -s ${bedpostdir}/merged -m ${datadir}/nodif_brain_mask.nii.gz --dir=${outdir} --out=${outname} --waypoints=${datadir}/${fullsubj}_waypoints_list.txt --waycond=AND --wayorder

echo ''
echo 'thresholding tract...'
echo ''

perthresh=0.10
tract1=${outdir}/${outname}
tract1dir=${outdir}
txfm=${regpref}_DIFFtoT1

# move tract to T1 #
flirt -in ${tract1}.nii.gz -ref ${t1brain}.nii.gz -init ${txfm}.mat -applyxfm -out ${tract1}_T1.nii.gz

# divide A by waytotal #
fslmaths ${tract1}_T1.nii.gz -div `cat ${tract1dir}/waytotal` ${tract1}_T1_div.nii.gz

# mul A by 100 #
fslmaths ${tract1}_T1_div.nii.gz -mul 100 ${tract1}_T1_div_mul100.nii.gz

# thresh > 0.10% #
fslmaths ${tract1}_T1_div_mul100.nii.gz -thr $perthresh ${tract1}_T1_thr${perthresh}per.nii.gz

# binarize threshed #
fslmaths ${tract1}_T1_thr${perthresh}per.nii.gz -bin ${tract1}_T1_thr${perthresh}per_bin.nii.gz

##################################################################################################

## left central thalamus ##

echo 'conducting tractography from left central thalamus to right parietal cortex...'
echo ''

echo 'running probtrackx2...'
echo ''

seed=${subjpref}_roi_left_central_thalamus_mask_fs_DIFF
target=${subjpref}_roi_right_parietal_mask_DIFF
outname=${fullsubj}_left_central_thalamus_to_right_parietal_way-spleniumCC_nostop
outdir=${tractdir}/${outname}

probtrackx2 -x ${seed}.nii.gz --randfib=0 --fibst=1 --forcedir --opd --ompl --pd -l --distthresh=12 --onewaycondition -c 0.2 -S 2000 --steplength=0.5 -P 5000 --fibthresh=0.01 --sampvox=1.2 -s ${bedpostdir}/merged -m ${datadir}/nodif_brain_mask.nii.gz --dir=${outdir} --out=${outname} --waypoints=${datadir}/${fullsubj}_waypoints_list.txt --waycond=AND --wayorder

echo ''
echo 'thresholding tract...'
echo ''

perthresh=0.10
tract1=${outdir}/${outname}
tract1dir=${outdir}
txfm=${regpref}_DIFFtoT1

# move tract to T1 #
flirt -in ${tract1}.nii.gz -ref ${t1brain}.nii.gz -init ${txfm}.mat -applyxfm -out ${tract1}_T1.nii.gz

# divide A by waytotal #
fslmaths ${tract1}_T1.nii.gz -div `cat ${tract1dir}/waytotal` ${tract1}_T1_div.nii.gz

# mul A by 100 #
fslmaths ${tract1}_T1_div.nii.gz -mul 100 ${tract1}_T1_div_mul100.nii.gz

# thresh > 0.10% #
fslmaths ${tract1}_T1_div_mul100.nii.gz -thr $perthresh ${tract1}_T1_thr${perthresh}per.nii.gz

# binarize threshed #
fslmaths ${tract1}_T1_thr${perthresh}per.nii.gz -bin ${tract1}_T1_thr${perthresh}per_bin.nii.gz

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
