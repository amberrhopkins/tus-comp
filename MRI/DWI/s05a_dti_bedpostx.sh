#!/bin/sh
#$ -cwd
# error = Merged with joblog
#$ -o joblog.$JOB_ID.$TASK_ID
#$ -j y
#$ -pe shared 1
## #$ -l h_rt=40:00:00,h_data=12G  ## change this line for scripts >24h long
#$ -l h_rt=40:00:00,h_data=12G,highp 
## #$ -l h_rt=24:00:00,h_data=6G, highp
#  Job array indexes
#$ -t 1-1:1 ## 3-10:1

##################################################################################################
##################################################################################################

echo ''
echo 'running script 9a...'
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

dti_AP=${dtipref}_AP
bval_AP=${dti_AP}_bval
bvec_AP=${dti_AP}_bvec

dti_PA=${dtipref}_PA
bval_PA=${dti_PA}_bval
bvec_PA=${dti_PA}_bvec

##################################################################################################
############################       setting up for for bedpostx        ############################
##################################################################################################

### transposing eddy-corrected bvecs ###

echo 'transposing eddy-corrected bvecs...'
echo ''

input1=${dti_AP}_eddy.eddy_rotated_bvecs
output1=${bvec_AP}_eddy_trans

## transpose - bvecs ##

awk '
{ 
    for (i=1; i<=NF; i++)  {
        a[NR,i] = $i
    }
}
NF>p { p = NF }
END {    
    for(j=1; j<=p; j++) {
        str=a[1,j]
        for(i=2; i<=NR; i++){
            str=str"\t"a[i,j];
        }
        print str
    }
}' ${input1} > "${output1}.txt"

##################################################################################################
############################           prepare for bedpostx           ############################
##################################################################################################

echo 'preparing bedpostx...'
echo ''

# IMPORTANT, bedpost requires input folder with the following files named exactly as such (bvals, bvecs, data.nii.gz, nodif_brain.nii.gz, nodif_brain_mask.nii.gz)

mv ${dti_AP}_eddy.nii.gz ${datadir}/data.nii.gz
cp ${bval_AP}_trans_truncated.txt ${datadir}/bvals
cp ${bvec_AP}_eddy_trans_truncated.txt ${datadir}/bvecs

# (Optional) To see if bedpost input folder is ready
# bedpostx_datacheck ${datadir}

##################################################################################################
############################             running bedpostx             ############################
##################################################################################################

echo 'running bedpostx...'
echo ''

# for FSL documentation, see http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide#BEDPOSTX, or type/enter function name into command line

bedpostx ${datadir} -n 3 -b 3000 -j 1250 -s 25 -model 2

  # output goes in new created folder called ${maindir}/${fullsubj}.bedpostX

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
