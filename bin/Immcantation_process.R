#!/usr/bin/env Rscript

## load libraries

## suppressPackageStartupMessages(library(alakazam))
## suppressPackageStartupMessages(library(data.table))
## suppressPackageStartupMessages(library(dowser))
## suppressPackageStartupMessages(library(dplyr))
## suppressPackageStartupMessages(library(ggplot2))
## suppressPackageStartupMessages(library(scoper))
##suppressPackageStartupMessages(library(Seurat))
## suppressPackageStartupMessages(library(shazam))
## suppressPackageStartupMessages(library(ggtree))

suppressPackageStartupMessages(library(airr))
library(dplyr)
library(purrr)
library(magrittr)


## copied from https://immcantation.readthedocs.io/en/stable/getting_started/10x_tutorial.html
## https://bioinformatics.thecrick.org/users/ghanata/projects/caladod/bernard.maybury/bm123-Single-cell-MIB-lymphomas-after-R-CHOP/scripts/R/_site/2_2_2_VDJ_Immcantation.html
## https://bioinformatics.thecrick.org/babs/post/vdj/

#args = commandArgs(trailingOnly=TRUE)

dir.in<-getwd()
#dir.in<-"/nemo/stp/babs/working/schneid/projects/vinuesac/qian.shen/qs699/Immcantation"

Files.in<-list.files(dir.in,pattern='_productive-T.tsv')

# Files.in<-map(dir.in.all, function(d){
#   list.files(paste0(dir.in,'/',d),pattern='productive-T.tsv')
# })
names(Files.in)<-Files.in %>% gsub('_(heavy|light)_productive-T.tsv','',.)

# read in the data
# Heavy & light chain data

pmap(list(Files.in,names(Files.in)), function(f,n){
  Dat<-airr::read_rearrangement(f) %>% 
      mutate(sequence_id=paste0(n,'_',sequence_id)) %>%
      mutate(cell_id=paste0(n,'_',cell_id))
  Dat
}) -> BCR_dat_all
names(BCR_dat_all)<- Files.in %>% gsub('_productive-T.tsv','',.) %>% gsub('[A-Z0-9]+_[a-zA-Z0-9]+_','',.)
BCR_dat_all_H <- names(BCR_dat_all) %>% grep('heavy',.,value=T)
BCR_dat_all_L <- names(BCR_dat_all) %>% grep('light',.,value=T)

BCR_dat_H<-BCR_dat_all[BCR_dat_all_H]
BCR_dat_L<-BCR_dat_all[BCR_dat_all_L]


# Remove cells with multiple heavy chains -----> but not for light chain data 
BCR_dat_H<-map(BCR_dat_H, function(bcr){
  bcr %>% 
    filter(locus == "IGH") %>% 
    select(cell_id) %>% table()-> multi_heavy
   multi_heavy_cells <- names(multi_heavy)[multi_heavy > 1]
  bcr %>% filter(!(cell_id %in% multi_heavy_cells ))
})

# Remove cells with multiple light chains
BCR_dat_L<-map(BCR_dat_L, function(bcr){
  bcr %>%
    filter(locus == "IGL"| locus == "IGK")  %>%
    select(cell_id) %>% table()-> multi_light
  multi_light_cells <- names(multi_light)[multi_light > 1]
  bcr %>% filter(!(cell_id %in% multi_light_cells ))
})

sData.H<-BCR_dat_H %>% bind_rows()
sData.L<-BCR_dat_L %>% bind_rows()

outfile.H=paste0(dir.in,'/SC24085_heavy_productive-T.tsv')
outfile.L=paste0(dir.in,'/SC24085_light_productive-T.tsv')
airr::write_rearrangement(sData.H,outfile.H)
airr::write_rearrangement(sData.L,outfile.L)

#

