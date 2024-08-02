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
                tuple path(FASTA), path(CSV), val(SAM)

        output:
                path("*_productive-T.tsv")
        script:
        """
	changeo-10x \
		-s $FASTA \
		-a $CSV \
		-g ${params.org} \
		-t 'ig' \
		-n $SAM \
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

///////////////////////////////////////////////////////////////////////////////
//// MAIN WORKFLOW ////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

workflow {
  
	Channel
		.fromPath(params.indir+'/*', type:'dir', maxDepth:1)
		.map{[
			it,	
			it.toString().replaceAll("(.*)/SC[0-9]+_(.*)", "\$2")
		]}
		.map{[
	           it[0]+'/outs/multi/vdj_b/all_contig.fasta',
		   it[0]+'/outs/multi/vdj_b/all_contig_annotations.csv',
		   it[1]
		]}
		.set{ Indirs }

	changeo10X(Indirs)
	changeo10X
		.out
         	.view()

}
