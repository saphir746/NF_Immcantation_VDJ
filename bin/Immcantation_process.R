# load libraries

# suppressPackageStartupMessages(library(alakazam))
# suppressPackageStartupMessages(library(data.table))
# suppressPackageStartupMessages(library(dowser))
# suppressPackageStartupMessages(library(dplyr))
# suppressPackageStartupMessages(library(ggplot2))
# suppressPackageStartupMessages(library(scoper))
# suppressPackageStartupMessages(library(Seurat))
# suppressPackageStartupMessages(library(shazam))
# suppressPackageStartupMessages(library(ggtree))

suppressPackageStartupMessages(library(airr))
library(dplyr)
library(purrr)
library(magrittr)


## copied from https://immcantation.readthedocs.io/en/stable/getting_started/10x_tutorial.html
## https://bioinformatics.thecrick.org/users/ghanata/projects/caladod/bernard.maybury/bm123-Single-cell-MIB-lymphomas-after-R-CHOP/scripts/R/_site/2_2_2_VDJ_Immcantation.html
## https://bioinformatics.thecrick.org/babs/post/vdj/

args = commandArgs(trailingOnly=TRUE)

#dir.in<-args[1]
dir.in<-"/nemo/stp/babs/working/schneid/projects/vinuesac/qian.shen/qs699/Immcantation"

dir.in.all<-list.files(dir.in,pattern='results_')

Files.in<-map(dir.in.all, function(d){
  list.files(paste0(dir.in,'/',d),pattern='productive-T.tsv')
})
names(Files.in)<-dir.in.all %>% gsub('results_SC24085_','',.)

# read in the data
# Heavy & light chain data

pmap(list(dir.in.all,Files.in,names(Files.in)), function(d,f,n){
  dir<-paste0(dir.in,'/',d)
  Dat<-lapply(unlist(f),function(ff){
     airr::read_rearrangement(paste0(dir,'/',ff)) %>% 
      mutate(sequence_id=paste0(n,'_',sequence_id)) %>%
      mutate(cell_id=paste0(n,'_',cell_id))-> bcr_dat
  })
  names(Dat)<- unlist(f) %>% gsub('_productive-T.tsv','',.) %>% gsub('[A-Z0-9]+_[a-zA-Z0-9]+_','',.)
  Dat
})-> BCR_dat_all

BCR_dat_H<-lapply(BCR_dat_all, function(bcr_dat) bcr_dat[["heavy"]])
names(BCR_dat_H)<-names(Files.in)
BCR_dat_L<-lapply(BCR_dat_all, function(bcr_dat) bcr_dat[["light"]])
names(BCR_dat_L)<-names(Files.in)

# Remove cells with multiple heavy chains -----> but not for light chain data 
BCR_dat_H<-map(BCR_dat_H, function(bcr){
  bcr %>% 
    filter(locus == "IGH") %>% 
    select(cell_id) %>% table()-> multi_heavy
   multi_heavy_cells <- names(multi_heavy)[multi_heavy > 1]
  bcr %>% filter(!(cell_id %in% multi_heavy_cells ))
})

sData.H<-BCR_dat_H %>% bind_rows()
sData.L<-BCR_dat_L %>% bind_rows()

outfile.H=paste0(dir.in,'/SC24085_heavy_productive-T.tsv')
outfile.L=paste0(dir.in,'/SC24085_light_productive-T.tsv')
airr::write_rearrangement(sData.H,outfile.H)
airr::write_rearrangement(sData.L,outfile.L)

#

