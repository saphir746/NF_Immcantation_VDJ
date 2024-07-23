#!/usr/bin/env nextflow

import java.nio.file.Paths

nextflow.enable.dsl=2

//////////////////////////////////////////////////////
//// Made on my own (schneid@crick.ac.uk)  ///////////
//////////////////////////////////////////////////////

publish_mode = "copy"
publish_overwrite = true

///////////////////////////////////////////////////////////////////////////////
//// PROCESSES ////////////////////////////////////////////////////////////////
        
process changeo10X {

        container "docker://immcantation/suite:4.5.0"

	publishDir Paths.get( params.outdir ),
            mode: publish_mode,
            overwrite: publish_overwrite
       
        input:
                tuple path(loc), val(SAM)

        output:
                path("*_productive-T.tsv")
        script:
        """
        FASTA=$loc/Cellranger_output/$SAM/outs/multi/vdj_b/all_contig.fasta
        CSV=$loc/Cellranger_output/$SAM/outs/multi/vdj_b/all_contig_annotations.csv
        changeo-10x \
		-s ${FASTA} \
		-a ${CSV} \
		-g ${params.org} \
		-t 'ig' \
		-n ${SAM} \
		-o .
        """
}

process Imm_process_R {

        container "docker://immcantation/suite:4.5.0"                                        

        publishDir Paths.get( params.outdir ),
            mode: publish_mode,
            overwrite: publish_overwrite

        input:
                tuple val(Hv), val(Lt)

        output:
                path("*_productive-T.tsv")
        script:
        """
	Immcantation_process.R $Hv $Lt
	"""
}

process changeo_clones {

        container "docker://immcantation/suite:4.5.0"                                        

        publishDir Paths.get( params.outdir ),
            mode: publish_mode,
            overwrite: publish_overwrite

        input:
                tuple val(Hv), val(Lt)

        output:
                path("*_productive-T.tsv")
        script:
        """
        changeo-10x-clone.sh -g ${params.org} \
			-x ${params.dist} \ 
			-sH $Hv \
			-sL $Lt \
			-n  $name \
			-o .
        """


}
