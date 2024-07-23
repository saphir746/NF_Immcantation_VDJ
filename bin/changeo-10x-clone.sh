#!/usr/bin/env bash
# Super script to run IgBLAST and Change-O on 10x data
#
# Author:  Jason Anthony Vander Heiden, Ruoyi Jiang
# Date:    2019.05.15
#
# Author:  Deb Schneider-Luftman
# Date:    2024.07.18
#
# Arguments:
#   -n  Sample name or run identifier which will be used for reading input file and as the output file prefix.
#   -x  Distance threshold for clonal assignment.
#   -r  Directory containing IMGT-gapped reference germlines.
#       Defaults to /usr/local/share/germlines/imgt/[species name]/vdj.
#   -g  Species name. One of human, mouse, rabbit, rat, or rhesus_monkey. Defaults to human.
#   -m  Distance model for clonal assignment.
#       Defaults to the nucleotide Hamming distance model (ham).
#   -o  Output directory. Will be created if it does not exist.
#       Defaults to a directory matching the sample identifier in the current working directory.
#   -f  Output format. One of changeo or airr. Defaults to airr.
#   -p  Number of subprocesses for multiprocessing tools.
#       Defaults to the available processing units.
#   -z  Specify to disable cleaning and compression of temporary files.
#   -h  Display help.

# Print usage
print_usage() {
    echo -e "Usage: `basename $0` [OPTIONS]"
    echo -e "  -n  Sample name or run identifier which will be used for reading input files and as the output file prefix."
    echo -e "  -x  Distance threshold for clonal assignment. Specify \"auto\" for automatic detection.\n"
    echo -e "  -r  Directory containing IMGT-gapped reference germlines.\n" \
            "     Defaults to /usr/local/share/germlines/imgt/[species name]/vdj."
    echo -e "  -g  Species name. One of human, mouse, rabbit, rat, or rhesus_monkey. Defaults to human."
    echo -e "  -m  Distance model for clonal assignment.\n" \
            "     Defaults to the nucleotide Hamming distance model (ham)."
    echo -e "  -o  Output directory. Will be created if it does not exist.\n" \
            "     Defaults to a directory matching the sample identifier in the current working directory."
    echo -e "  -f  Output format. One of changeo or airr. Defaults to airr."
    echo -e "  -p  Number of subprocesses for multiprocessing tools.\n" \
            "     Defaults to the available cores."
    echo -e "  -z  Specify to disable cleaning and compression of temporary files."
    echo -e "  -h  This message."
}

# Argument validation variables
REFDIR_SET=false
SPECIES_SET=false
DIST_SET=false
MODEL_SET=false
OUTNAME_SET=false
OUTDIR_SET=false
FORMAT_SET=false
NPROC_SET=false
THRESHOLD_METHOD_SET=false
THRESHOLD_MODEL_SET=false

# Argument defaults
ZIP_FILES=true
DELETE_FILES=true

# Get commandline arguments
while getopts "r:g:x:m:n:o:f:p:zh" OPT; do
    case "$OPT" in
    e)  THRESHOLD_METHOD=$OPTARG
        THRESHOLD_METHOD_SET=true
        ;;
    d)  THRESHOLD_MODEL=$OPTARG
        THRESHOLD_MODEL_SET=true
        ;;
    r)  REFDIR=$OPTARG
        REFDIR_SET=true
        ;;
    g)  SPECIES=$OPTARG
        SPECIES_SET=true
        ;;
    x)  DIST=$OPTARG
        DIST_SET=true
        ;;
    m)  MODEL=$OPTARG
        MODEL_SET=true
        ;;
    n)  OUTNAME=$OPTARG
        OUTNAME_SET=true
        ;;
    o)  OUTDIR=$OPTARG
        OUTDIR_SET=true
        ;;
    f)  FORMAT=$OPTARG
        FORMAT_SET=true
        ;;
    p)  NPROC=$OPTARG
        NPROC_SET=true
        ;;
    z)  ZIP_FILES=false
        DELETE_FILES=false
        ;;
    h)  print_usage
        exit
        ;;
    \?) echo -e "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
    :)  echo -e "Option -${OPTARG} requires an argument" >&2
        exit 1
        ;;
    esac
done

# Exit if required arguments are not provided
if ! ${OUTNAME_SET}; then
    echo -e "You must specify the Sample name or run identifier using the -n option." >&2
    exit 1
fi

if ! ${DIST_SET}; then
    echo -e "You must specify the Distance threshold for clonal assignment using the -x option." >&2
    exit 1
fi

# Set format options
if ! ${FORMAT_SET}; then
    FORMAT="airr"
fi

if [[ "${FORMAT}" == "airr" ]]; then
    EXT="tsv"
    LOCUS_FIELD="locus"
    PROD_FIELD="productive"
else
	EXT="tab"
	LOCUS_FIELD="LOCUS"
	PROD_FIELD="FUNCTIONAL"
fi

# Set threshold method
if ! ${THRESHOLD_METHOD_SET}; then
    THRESHOLD_METHOD="density"
fi

# Set threshold model
if ! ${THRESHOLD_MODEL_SET}; then
    THRESHOLD_MODEL="gamma-gamma"
fi

HEAVY_PROD="${OUTNAME}_heavy_${PROD_FIELD}-T.${EXT}"
LIGHT_PROD="${OUTNAME}_light_${PROD_FIELD}-T.${EXT}"

# Check that heavy chain files exist and determined absolute paths
if [ -e ${HEAVY_PROD} ]; then
    HEAVY_PROD=$(realpath ${HEAVY_PROD})
else
    echo -e "File '${HEAVY_PROD}' not found." >&2
    exit 1
fi

# Check that light chain files exist and determined absolute paths
if [ -e ${LIGHT_PROD} ]; then
    LIGHT_PROD=$(realpath ${LIGHT_PROD})
else
    echo -e "File '${LIGHT_PROD}' not found." >&2
fi

# Set and check species
if ! ${SPECIES_SET}; then
    SPECIES="human"
elif [ ${SPECIES} != "human" ] && \
     [ ${SPECIES} != "mouse" ] && \
     [ ${SPECIES} != "rabbit" ] && \
     [ ${SPECIES} != "rat" ] && \
     [ ${SPECIES} != "rhesus_monkey" ]; then
    echo "Species (-g) must be one of 'human', 'mouse', 'rabbit', 'rat', or 'rhesus_monkey'." >&2
    exit 1
fi

# Set reference sequence
if ! ${REFDIR_SET}; then
    REFDIR="/usr/local/share/germlines/imgt/${SPECIES}/vdj"
else
    REFDIR=$(realpath ${REFDIR})
fi

# Set distance model
if ! ${MODEL_SET}; then
    MODEL="ham"
fi

# Set output directory
if ! ${OUTDIR_SET}; then
    OUTDIR=${OUTNAME}
fi

# Check output directory permissions
if [ -e ${OUTDIR} ]; then
    if ! [ -w ${OUTDIR} ]; then
        echo -e "Output directory '${OUTDIR}' is not writable." >&2
        exit 1
    fi
else
    PARENTDIR=$(dirname $(realpath ${OUTDIR}))
    if ! [ -w ${PARENTDIR} ]; then
        echo -e "Parent directory '${PARENTDIR}' of new output directory '${OUTDIR}' is not writable." >&2
        exit 1
    fi
fi


# Set number of processes
if ! ${NPROC_SET}; then
    NPROC=$(nproc)
fi


# DefineClones run parameters
DC_MODE="gene"
DC_ACT="set"

# Create germlines parameters
CG_GERM="full dmask"

# Make output directory
mkdir -p ${OUTDIR}; cd ${OUTDIR}

# Define log files
LOGDIR="logs"
PIPELINE_LOG="${LOGDIR}/pipeline-10x-clone.log"
ERROR_LOG="${LOGDIR}/pipeline-10x-clone.err"
mkdir -p ${LOGDIR}
echo '' > $PIPELINE_LOG
echo '' > $ERROR_LOG

# Check for errors
check_error() {
    if [ -s $ERROR_LOG ]; then
        echo -e "ERROR:"
        cat $ERROR_LOG | sed 's/^/    /'
        exit 1
    fi
}

# Set extension
CHANGEO_VERSION=$(python3 -c "import changeo; print('%s-%s' % (changeo.__version__, changeo.__date__))")

# Start
echo -e "IDENTIFIER: ${OUTNAME}"
echo -e "DIRECTORY: ${OUTDIR}"
echo -e "CHANGEO VERSION: ${CHANGEO_VERSION}"
echo -e "\nSTART"
STEP=0

##################
####################### Mods begin here
#########################

# Assign clones


printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "Single cell filter"
singlecell-filter -d ${HEAVY_PROD},${LIGHT_PROD} -o . -f ${FORMAT} \
>> $PIPELINE_LOG 2> $ERROR_LOG
check_error

if [ "$DIST" == "auto" ]; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "Detect cloning threshold"
    ### Avinash' version
    shazam-threshold -d ${HEAVY_PROD} -m density -n "${OUTNAME}" \
    -f ${FORMAT} -p ${NPROC} \
      > /dev/null 2> $ERROR_LOG
    check_error
    ### 2022 master branch version
    ## https://bitbucket.org/kleinstein/immcantation/src/master/pipelines/changeo-10x.sh
    ## l.404
    # shazam-threshold -d ${HEAVY_PROD},${LIGHT_PROD}  -m ${THRESHOLD_METHOD} -n "${OUTNAME}" \
    #     --model ${THRESHOLD_MODEL} --cutoff "user" --spc 0.995 -o . \
    #     -f ${FORMAT} -p ${NPROC} \
    # > /dev/null 2> $ERROR_LOG
    # check_error
    DIST=$(tail -n1 "${OUTNAME}_threshold-values.tab" | cut -f2)
else
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "Calculating distances"
    shazam-threshold -d ${HEAVY_PROD} -m none -n "${OUTNAME}" \
    -f ${FORMAT} -p ${NPROC} \
     &> /dev/null
fi


printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "Define clones (scoper)"
scoper-clone -d ${HEAVY_PROD},${LIGHT_PROD} -o . -f ${FORMAT} \
    --method ${MODEL} --threshold ${DIST} --nproc ${NPROC} \
    --log "${LOGDIR}/clone.log" \
    --name "${OUTNAME}_heavy","${OUTNAME}_light" \
    >> $PIPELINE_LOG 2> $ERROR_LOG

CLONE_FILE="${OUTNAME}_heavy_clone-pass.${EXT}"
check_error

# printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "DefineClones"
# DefineClones.py -d ${HEAVY_PROD} --model ${MODEL} \
#     --dist ${DIST} --mode ${DC_MODE} --act ${DC_ACT} --nproc ${NPROC} \
#     --outname "${OUTNAME}_heavy" --log "${LOGDIR}/clone.log" --format ${FORMAT} \
#     >> $PIPELINE_LOG 2> $ERROR_LOG
# CLONE_FILE="${OUTNAME}_heavy_clone-pass.${EXT}"
# check_error
# 
# if [ -f "${LIGHT_PROD}" ]; then
#     printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "VL clone correction"
#     light_cluster.py -d ${CLONE_FILE} -e ${LIGHT_PROD} \
#         -o "${OUTNAME}_heavy_clone-light.${EXT}" --format ${FORMAT} --doublets count \
#         > /dev/null 2> $ERROR_LOG
#     CLONE_FILE="${OUTNAME}_heavy_clone-light.${EXT}"
# else
#     printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "VL correction skipped"
# fi

printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "CreateGermlines"
CreateGermlines.py -d ${CLONE_FILE} --cloned -r ${REFDIR} -g ${CG_GERM} \
    --outname "${OUTNAME}_heavy" --log "${LOGDIR}/germline.log" --format ${FORMAT} \
    >> $PIPELINE_LOG 2> $ERROR_LOG
HEAVY_PROD="${OUTNAME}_heavy_germ-pass.${EXT}"
check_error

# # Zip or delete intermediate files
# printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "Compressing files"
# TEMP_FILES=$(ls *.tsv *.tab 2> /dev/null | grep -v "${HEAVY_PROD}\|${LIGHT_PROD}")
# if [[ ! -z $TEMP_FILES ]]; then
#     if $ZIP_FILES; then
#         tar -zcf temp_files.tar.gz $TEMP_FILES
#     fi
#     if $DELETE_FILES; then
#         rm $TEMP_FILES
#     fi
# fi

# End
# printf "DONE\n\n"
# cd ../

# Zip or delete intermediate files
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 30 "Compressing files"
TEMP_FILES=$(ls *.tsv *.tab 2> /dev/null | grep -v "${HEAVY_PROD}\|${LIGHT_PROD}\|${HEAVY_NON}\|${LIGHT_NON}\|${DB_PASS}")
if [[ ! -z $TEMP_FILES ]]; then
    if $ZIP_FILES; then
        tar -zcf temp_files.tar.gz $TEMP_FILES
    fi
    if $DELETE_FILES; then
        rm $TEMP_FILES
    fi
fi

# End
printf "DONE\n\n"
cd ../
