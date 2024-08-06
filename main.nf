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
                path(HvLt)

        output:
                tuple path("*_heavy_productive-T.tsv"), path("*_light_productive-T.tsv")
        script:
        """
	Immcantation_process.R
	"""
}

process changeo_clones {

        container "docker://immcantation/suite:4.5.0"                                        

        publishDir Paths.get( params.outdir ),
            mode: publish_mode,
            overwrite: publish_overwrite

        input:
                tuple path(Hv), path(Lt), val(name)

        output:
                path("*.tsv")
        script:
        """
        changeo-10x-clone.sh -g ${params.org} \
			-x ${params.dist} \
			-n $name \
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
		.collect()
         	.set{ Intmd1 }
      
	Imm_process_R(Intmd1)
	Imm_process_R
		.out
		.map{[
			it[0],
			it[1],
			it[0].toString().replaceAll("(.*)/(.*)_heavy_productive-T.tsv", "\$2")
		]}
		.set{ Intmd2 }

//	Intmd2.view()
	changeo_clones(Intmd2)

}
