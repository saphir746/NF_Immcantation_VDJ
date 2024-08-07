#!/usr/bin/env Rscript

## load libraries

 suppressPackageStartupMessages(library(alakazam))
## suppressPackageStartupMessages(library(data.table))
 suppressPackageStartupMessages(library(dowser))
## suppressPackageStartupMessages(library(dplyr))
## suppressPackageStartupMessages(library(ggplot2))
 suppressPackageStartupMessages(library(scoper))
##suppressPackageStartupMessages(library(Seurat))
suppressPackageStartupMessages(library(shazam))
## suppressPackageStartupMessages(library(ggtree))

suppressPackageStartupMessages(library(airr))

args = commandArgs(trailingOnly=TRUE)

Files.bcr<-args[1]

imm_bcr <-  airr::read_rearrangement(Files.bcr)

mut_freq_clone <- observedMutations(imm_bcr ,
                                    sequenceColumn = "sequence_alignment",
                                    germlineColumn = "germline_alignment_d_mask",
                                    regionDefinition = IMGT_VDJ,
                                    frequency = FALSE, # mu_count_
                                    combine = TRUE,
                                    nproc = 4)

mut_freq_clone <- observedMutations(mut_freq_clone,
                                    sequenceColumn = "sequence_alignment",
                                    germlineColumn = "germline_alignment_d_mask",
                                    regionDefinition = IMGT_VDJ,
                                    frequency = TRUE, # mu_freq_
                                    combine = TRUE,
                                    nproc = 4)

airr::write_rearrangement(mut_freq_clone, file = gsub('.tsv','_mut_freq.tsv',Files.bcr))


