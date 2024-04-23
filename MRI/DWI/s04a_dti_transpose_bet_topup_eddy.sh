#!/bin/sh
#$ -cwd
# error = Merged with joblog
#$ -o joblog.$JOB_ID.$TASK_ID
#$ -j y
#$ -pe shared 1
## #$ -l h_rt=40:00:00,h_data=12G  ## change this line for scripts >24h long
#$ -l h_rt=20:00:00,h_data=12G,highp 
## #$ -l h_rt=24:00:00,h_data=6G, highp
#  Job array indexes
#$ -t 1-1:1 ## 3-10:1

##################################################################################################
##################################################################################################

echo ''
echo 'running script 8a...'
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
sub=${subj}

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
datadir=${maindir}/subjects/${sub}
regdir=${datadir}/registrations_fsl

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
############################       transposing bvals and bvecs        ############################
##################################################################################################

echo 'transposing bvals and bvecs...'
echo ''

input1=${bval_AP}.txt
output1=${bval_AP}_trans
input2=${bvec_AP}.txt
output2=${bvec_AP}_trans

input3=${bval_PA}.txt
output3=${bval_PA}_trans
input4=${bvec_PA}.txt
output4=${bvec_PA}_trans

## transpose - bvals ##

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
}' ${input2} > "${output2}.txt"

### PA files ###

## transpose - bvals ##

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
}' ${input3} > "${output3}.txt"

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
}' ${input4} > "${output4}.txt"

##################################################################################################
############################        dti initial preprocessing         ############################
##################################################################################################

## separate and merge b0s ##

echo 'separating and merging b0s...'
echo ''

fslroi ${dti_AP}.nii.gz ${dti_AP}_b0-1 0 1
fslroi ${dti_AP}.nii.gz ${dti_AP}_b0_2-7 65 7
fslmerge -t ${dti_AP}_all_b0s.nii.gz ${dti_AP}_b0-1.nii.gz ${dti_AP}_b0_2-7.nii.gz
fslroi ${dti_PA}.nii.gz ${dti_PA}_b0-1 0 1
fslmerge -t ${dtipref}_first_b0s.nii.gz ${dti_AP}_b0-1 ${dti_PA}_b0-1

##################################################################################################
############################                 fsl topup                ############################
##################################################################################################

echo 'running fsl topup...'
echo ''

# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/TopupUsersGuide/#A--datain
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide#A--acqp
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/Faq#How_do_I_know_what_to_put_into_my_--acqp_file
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/ApplyTopupUsersGuide
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/ExampleTopupFollowedByApplytopup

## to make dti_acq_params file ##

# AP phase-encoding (y axis) = 0 -1 0
# PA phase-encoding (y axis) = 0 1 0
# EPI factor = 86
# echo spacing = 0.7
# 4th value = 0.7*0.001*(86-1) = .0595

## run topup ##

topup --imain=${dtipref}_first_b0s.nii.gz --datain=${acqparam_file1}.txt --config=b02b0.cnf --out=${dtipref}_first_b0s_topup

applytopup --imain=${dti_AP}_all_b0s.nii.gz,${dti_PA}.nii.gz --datain=${acqparam_file1}.txt --inindex=1,2 --topup=${dtipref}_first_b0s_topup --out=${dtipref}_first_b0s_applytopup

## average corrected b0s ##

fslmaths ${dtipref}_first_b0s_applytopup.nii.gz -Tmean ${dtipref}_first_b0s_applytopup_average.nii.gz

## brain extraction of average corrected b0 ##

bet2 ${dtipref}_first_b0s_applytopup_average.nii.gz ${dtipref}_first_b0s_applytopup_average_brain -f .1 -m

##################################################################################################
############################             eddy correction              ############################
##################################################################################################

echo 'eddy correcting...'
echo ''

# https://fsl.fmrib.ox.ac.uk/fslcourse/2019_Beijing/lectures/FDT/fdt1.html
	# tutorial: run topup on 2 b0s (AP, PA), then run eddy on AP data with topup correction

# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide#The_eddy_executables
# eddy is a very computationally intense application, so in order to speed things up it has been parallelised. This has been done in two ways, resulting in two different executables

#    eddy_openmp: This executable has been parallelised through OpenMP, which allows eddy to use more than one core/CPU when running.

#    eddy_cuda: The other executable has been parallelised with CUDA, which allows eddy to use an Nvidia GPU if one is available on the system. 

# Hence, there is not longer an executable named eddy and when I refer to the eddy-command in the rest of this users guide it is implied that this is either eddy_openmp or eddy_cuda. The eddy_cuda version is potentially much faster than eddy_openmp and not all new features will be available for the OpenMP version. This is because the slow speed makes it almost impossible to test the more time-consuming options thoroughly. I warmly recommend investing in a couple of CUDA cards. 

# 02/03/2019: NOTE: I lost the my acqp and index files (somehow!), so I need to recheck what my parameters are and rerun (and check output to see if it makes any difference)
	# need to add the "slice to vol" movement correction (see https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide)
		# I need to know the slice interleaving order, need to check scanner protocol to see if multiband (and what factor)
		# or, I can get a .json file from dcm2nii(x) from the dicoms

# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide#A--slspec
# "--slspec

# specifies a text-file that describes how the slices/MB-groups were acquired. This information is necessary for eddy to know how a temporally continuous movement translates into location of individual slices/MB-groups. Let us say a given acquisition has N slices and that m is the MB-factor (also known as Simultaneous Multi-Slice (SMS)). Then the file pointed to be --slspec will have N/m rows and m columns. Let us for example assume that we have a data-set which has been acquired with an MB-factor of 3, 15 slices and interleaved slice order. The file would then be

# 0 5 10
# 2 7 12
# 4 9 14
# 1 6 11
# 3 8 13

## where the first row "0 5 10" specifies that the first, sixth and 11th slice are acquired first and together, followed by the third, eighth and 13th slice etc. For single-band data and for multi-band data with an odd number of excitations/MB-groups it is trivial to work out the --slspec file using the logic of the example. For an even number of excitations/MB-groups it is considerably more difficult and we recommend using a DICOM->niftii converter that writes the exact slice timings into a .JSON file. This can then be used to create the --slspec file."

eddy_openmp --imain=${dti_AP}.nii.gz --mask=${dtipref}_first_b0s_applytopup_average_brain_mask.nii.gz --index=${acqparam_file1}_index.txt --bvecs=${dti_AP}_bvec_trans.txt --bvals=${dti_AP}_bval_trans.txt --acqp=${acqparam_file1}.txt --fwhm=0 --topup=${dtipref}_first_b0s_topup --flm=quadratic --out=${dti_AP}_eddy #-repol
	
	# --repol error (eddy: msg=--rep_ol cannot be used for this version of eddy)...need eddy version 5.0.10 or 5.0.11 (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide#The_eddy_executables) --note, I'm requesting that hoffman get the new version!

	# NOTE 02-03-19: DTI64 acquisition changed after first subject, so the acqparams and index files will change too! (need to double-check)
	# NOTE 02-03-19: need to double-check acq params!!
	# NOTE 02-03-19: (for LIFUP001, voxdims are not 2x2x2 (1.97x1.97x3)

	# DTI64 (siemens) protocol for LIFUP
		# EPI factor = 86
		# echo spacing = 0.7ms
		# PHase encoding dir = A>>P
		# vox dim = 2x2x1mm
		# TR = 7000
		# TE = 93

	# How to customize LIFUP for FSL's eddy acqp file and index file
		# acqp file: 0 -1 0 0.0595
			## fourth col value is 0.0595 = 0.7*(86-1)*0.001
			## how to make, e.g.: printf "0 -1 0 0.0595" > acqparams.txt
		# index file: all 1's, one column for each volume in DTI64 file
			# for LIFUP patients (at least for LIFUP01_chronic tested so far, 1b0 and 64dirs, so 65 1's in total)
				# to make: indx=""; for ((i=1; i<=64; i+=1)); do indx="$indx 1"; done
				# echo $indx > index.txt

    # for more info, see https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/Faq#How_do_I_know_what_to_put_into_my_--acqp_file
	# also, https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide
    	# FSL e.g., for acqp, PE=A>>P and echo spacing = 0.8ms and EPI factor=128, so the vector is 0 -1 0 and the 4th column value is 0.8*(128-1)*.001=0.0602(in sec)
    	# could also add the --repol argument for futher artifact correction (see user guide)

## brain extraction of average corrected b0 ##
bet2 ${dti_AP}_eddy.nii.gz ${datadir}/nodif_brain -f .2 -m

## remove trailing b0s from eddy-corrected data ##
fslsplit ${dti_AP}_eddy.nii.gz ${dti_AP}_TEMP -t
fslmerge -t ${dti_AP}_eddy.nii.gz ${dti_AP}_TEMP0000.nii.gz ${dti_AP}_TEMP0001.nii.gz ${dti_AP}_TEMP0002.nii.gz ${dti_AP}_TEMP0003.nii.gz ${dti_AP}_TEMP0004.nii.gz ${dti_AP}_TEMP0005.nii.gz ${dti_AP}_TEMP0006.nii.gz ${dti_AP}_TEMP0007.nii.gz ${dti_AP}_TEMP0008.nii.gz ${dti_AP}_TEMP0009.nii.gz ${dti_AP}_TEMP0010.nii.gz ${dti_AP}_TEMP0011.nii.gz ${dti_AP}_TEMP0012.nii.gz ${dti_AP}_TEMP0013.nii.gz ${dti_AP}_TEMP0014.nii.gz ${dti_AP}_TEMP0015.nii.gz ${dti_AP}_TEMP0016.nii.gz ${dti_AP}_TEMP0017.nii.gz ${dti_AP}_TEMP0018.nii.gz ${dti_AP}_TEMP0019.nii.gz ${dti_AP}_TEMP0020.nii.gz ${dti_AP}_TEMP0021.nii.gz ${dti_AP}_TEMP0022.nii.gz ${dti_AP}_TEMP0023.nii.gz ${dti_AP}_TEMP0024.nii.gz ${dti_AP}_TEMP0025.nii.gz ${dti_AP}_TEMP0026.nii.gz ${dti_AP}_TEMP0027.nii.gz ${dti_AP}_TEMP0028.nii.gz ${dti_AP}_TEMP0029.nii.gz ${dti_AP}_TEMP0030.nii.gz ${dti_AP}_TEMP0031.nii.gz ${dti_AP}_TEMP0032.nii.gz ${dti_AP}_TEMP0033.nii.gz ${dti_AP}_TEMP0034.nii.gz ${dti_AP}_TEMP0035.nii.gz ${dti_AP}_TEMP0036.nii.gz ${dti_AP}_TEMP0037.nii.gz ${dti_AP}_TEMP0038.nii.gz ${dti_AP}_TEMP0039.nii.gz ${dti_AP}_TEMP0040.nii.gz ${dti_AP}_TEMP0041.nii.gz ${dti_AP}_TEMP0042.nii.gz ${dti_AP}_TEMP0043.nii.gz ${dti_AP}_TEMP0044.nii.gz ${dti_AP}_TEMP0045.nii.gz ${dti_AP}_TEMP0046.nii.gz ${dti_AP}_TEMP0047.nii.gz ${dti_AP}_TEMP0048.nii.gz ${dti_AP}_TEMP0049.nii.gz ${dti_AP}_TEMP0050.nii.gz ${dti_AP}_TEMP0051.nii.gz ${dti_AP}_TEMP0052.nii.gz ${dti_AP}_TEMP0053.nii.gz ${dti_AP}_TEMP0054.nii.gz ${dti_AP}_TEMP0055.nii.gz ${dti_AP}_TEMP0056.nii.gz ${dti_AP}_TEMP0057.nii.gz ${dti_AP}_TEMP0058.nii.gz ${dti_AP}_TEMP0059.nii.gz ${dti_AP}_TEMP0060.nii.gz ${dti_AP}_TEMP0061.nii.gz ${dti_AP}_TEMP0062.nii.gz ${dti_AP}_TEMP0063.nii.gz ${dti_AP}_TEMP0064.nii.gz
rm ${dti_AP}_TEMP*

## transpose - bvecs ##
input1=${subjpref}_dti_AP_eddy.eddy_rotated_bvecs
output1=${bvec_AP}_eddy_trans

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

## remove correspoding b0 lines from eddy-corrected bvecs/bvals ##

sed '66,71d' ${bval_AP}_trans.txt > TEMP.txt
sed '$d' TEMP.txt > ${bval_AP}_trans_truncated.txt

sed '66,71d' ${bvec_AP}_eddy_trans.txt > TEMP2.txt
sed '$d' TEMP2.txt > ${bvec_AP}_eddy_trans_truncated.txt

##################################################################################################
##################################################################################################

cd ${scriptdir}

echo 'done'
echo ''
