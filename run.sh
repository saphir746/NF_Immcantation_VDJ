#!/bin/sh

ml Nextflow/24.04.2
ml Singularity/3.11.3

WORKDIR=/nemo/stp/babs/working/schneid/projects/vinuesac/qian.shen/qs699/
OUTDIR=${WORKDIR}Immcantation
INDIR=${WORKDIR}

WORK_DIR=/camp/stp/babs/scratch/schneid/SC24085_Imm_NF/


export NXF_SINGULARITY_CACHEDIR=${WORKDIR}/images/cachedir/

nextflow run main.nf -resume \
	             --WD ${WORKDIR} \
		     --indir ${INDIR} \
	             --outdir ${OUTDIR} \
		     --org "mouse" \
		     -profile cluster \
		     -work-dir $WORK_DIR
