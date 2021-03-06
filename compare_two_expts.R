# This script does the following two two tn-seq aggregate files
# 1. takes as an input an aggregate file from aerobio
# 2. merges it with the esential, cluster data 
# 3. rearranges output table in a nicer way 
# 4. saves it as a .csv file 
# 5. removes from the table non informative data (essential genes and genes without cluster assigned, genes with < N insertions)
# 6. creates a data.frame of genes where mutants completely dissapeared at time 2 
# 7. and another data.frame with the genes with fitness values and standard deviation data suitable for statistical comparisons 
# 8. and then both dataframes are saved as .csv files

# The two experiments can then be compared. This script will scale the 
# mean and sd values for fitnes of each gene to make the comparison 
# across experiments possible. This is done by dividint the mean (or sd)
# value for each gene by the median fitness of all genes within that experiment

# Once scaled, the comparison across experiments is done using a t test 
# with Benjamini-Hochberg correction for false discovery. 
# The two experiments are merged using CLUSTER identity, which means 
# comparison across strains is possible (as long as we have cluster and essentiality
# information on both strains)

# [input] inputfilename1: Tn-Seq aggregate file for experiment 1 (output of aerobio/magenta)
# [input] inputfilename2: Tn-Seq aggregate file for experiment 2 (output of aerobio/magenta)
# [input] essentialsfile: .RData file that has a data table named "ALL_essentials". 
#         This contains gene essentiality data for 22 strains (generated by Federico Rosconi)
# [input] N: the minimum number of insertions in a gene. Genes with <N insertions (in either 
#         experiment 1 or 2) will not be included in the statistical analysis.
# [input] outdirname: output directory name

compare_two_expts <-  function(inputfilename1, inputfilename2, essentialsfile, N, outdirname){
  source('./t.test2.R')
  library(ggplot2)
  #load necessary data
  All_essentials <- read.csv(essentialsfile, header=T, stringsAsFactors = F)
  aggfile1 <- read.csv(inputfilename1, header=T, stringsAsFactors = F)
  aggfile2 <- read.csv(inputfilename2, header=T, stringsAsFactors = F)
  filestub1 <- tools::file_path_sans_ext(basename(inputfilename1))
  filestub2 <- tools::file_path_sans_ext(basename(inputfilename2))
  filestub <- paste0(filestub1,"_", filestub2)
  # if "Output" directory doesn't exist, create it 
  dir.create(outdirname, showWarnings = FALSE)
  
  # Make a new column for Total-Blank.Removed (this is the bottleneck-corrected total)
  aggfile1$Blank.Removed <- as.numeric(aggfile1$Blank.Removed)
  aggfile1$Total.BN <- aggfile1$Total - aggfile1$Blank.Removed
  #merge aggregate data with essentiality
  tnfile1 <- merge(All_essentials, aggfile1, by.x = "locus",by.y = "locus",all = F) 
  #reorder the columns 
  tnfile1<-tnfile1[,c(2:5,1,6:18,20,23,19,21,24:26, 29)]
  # write to file
  completefilename1 <- file.path(outdirname, paste0(filestub1, '_complete.csv'))
  write.csv(tnfile1, completefilename1, row.names = F,quote=T)
  
  # Make a new column for Total-Blank.Removed (this is the bottleneck-corrected total)
  aggfile2$Blank.Removed <- as.numeric(aggfile2$Blank.Removed)
  aggfile2$Total.BN <- aggfile2$Total - aggfile2$Blank.Removed
  #merge aggregate data with essentiality
  tnfile2 <- merge(All_essentials, aggfile2, by.x = "locus",by.y = "locus",all = F) 
  #reorder the columns 
  tnfile2<-tnfile2[,c(2:5,1,6:18,20,23,19,21,24:26, 29)]
  # write to file
  completefilename2 <- file.path(outdirname, paste0(filestub2, '_complete.csv'))
  write.csv(tnfile2, completefilename2, row.names = F,quote=T)
  
  
  
  # remove essentials
  tnfile_sub1<-subset(tnfile1, Binomial.Call!="Essential") #5
  # remove rows where Total (bottleneck corrected) are <N or NA
  tnfile_sub1 <- tnfile_sub1[!is.na(tnfile_sub1$Total.BN) & tnfile_sub1$Total.BN > N,]
  # separate genes that had no insertions at time2 (these have sd=X)
  tnfile_sub1_nullW <- subset(tnfile_sub1, sd=="X")
  tnfile_sub1_W <- subset(tnfile_sub1, sd!="X")
  # write these to file
  nullWfile1 <- file.path(outdirname, paste0(filestub1, '_nullW.csv'))
  Wfile1 <- file.path(outdirname, paste0(filestub1, '_W.csv'))
  if (nrow(tnfile_sub1_nullW)>0){
    write.csv(tnfile_sub1_nullW, nullWfile1, row.names = F,quote=T)
  }
  write.csv(tnfile_sub1_W, Wfile1, row.names = F,quote=T)
  
  # remove essentials
  tnfile_sub2<-subset(tnfile2, Binomial.Call!="Essential") #5
  # remove rows where Total (bottleneck corrected) are <N or NA
  tnfile_sub2 <- tnfile_sub2[!is.na(tnfile_sub2$Total.BN) & tnfile_sub2$Total.BN > N,]
  # separate genes that had no insertions at time2 (these have sd=X)
  tnfile_sub2_nullW <- subset(tnfile_sub2, sd=="X")
  tnfile_sub2_W <- subset(tnfile_sub2, sd!="X")
  # write these to file
  nullWfile2 <- file.path(outdirname, paste0(filestub2, '_nullW.csv'))
  Wfile2 <- file.path(outdirname, paste0(filestub2, '_W.csv'))
  if (nrow(tnfile_sub2_nullW)>0){
    write.csv(tnfile_sub2_nullW, nullWfile2, row.names = F,quote=T)
  }
  write.csv(tnfile_sub2_W, Wfile2, row.names = F,quote=T)
  
  
  #adjust the W values on the two tables such that they are on a comparable scale
  #we do this by dividing the observed W by the expected W (median W across all genes)
  tnfile_sub1_W$W <- tnfile_sub1_W$mean/median(tnfile_sub1_W$mean)
  tnfile_sub2_W$W <- tnfile_sub2_W$mean/median(tnfile_sub2_W$mean)
  # do the same for the SD as well
  tnfile_sub1_W$sd <- as.numeric(tnfile_sub1_W$sd)
  tnfile_sub2_W$sd <- as.numeric(tnfile_sub2_W$sd)
  tnfile_sub1_W$sd.scaled <- tnfile_sub1_W$sd/median(tnfile_sub1_W$mean)
  tnfile_sub2_W$sd.scaled <- tnfile_sub2_W$sd/median(tnfile_sub2_W$mean)
  
  ## merge the two tnfiles based on Cluster
  drops <- c('locus_TIGR4',	'Old_locus_TIGR4',	'locus_D39',	'locus_Taiwan19F','gene')
  tnfile_sub2_W<-tnfile_sub2_W[, !(names(tnfile_sub2_W) %in% drops)]
  tnfile_ttest <- merge(tnfile_sub1_W, tnfile_sub2_W, by="MCL_Sub")
  tnfile_ttest$dW <- tnfile_ttest$W.x - tnfile_ttest$W.y
  
  #perform the t test, retrieve p value
  tnfile_ttest$pvalue <- sapply(c(1:nrow(tnfile_ttest)), function(i){
    t <- t.test2(tnfile_ttest$W.x[i], tnfile_ttest$W.y[i], 
                 tnfile_ttest$sd.scaled.x[i], tnfile_ttest$sd.scaled.y[i], 
                 tnfile_ttest$Total.BN.x[i], tnfile_ttest$Total.BN.y[i])
    pval <- t[["p"]]
    return(pval)
  })
  
  
  #adjust p value for false discovery
  tnfile_ttest$padj <- p.adjust(tnfile_ttest$pvalue, "BH")
  # mark discoveries based on non-adjusted p value
  tnfile_ttest$Sig <- ""

  tnfile_ttest$Sig[tnfile_ttest$pvalue<=0.002]<-"***"
  tnfile_ttest$Sig[tnfile_ttest$pvalue<=0.0002]<-"****"
  
  tnfile_ttest$Discovery <- FALSE
  tnfile_ttest$Discovery[tnfile_ttest$padj<=0.05] <- TRUE
  
  #write to file
  discoveriesfile <- file.path(outdirname, paste0(filestub, '_discovery.csv'))
  write.csv(tnfile_ttest, discoveriesfile, row.names = F,quote=T)
  
  #make a volcano plot
  tnfile_ttest$logp <- -log10(tnfile_ttest$padj)
  tnfile_ttest$Significant <- tnfile_ttest$padj<0.05 
  volcanoname <- file.path(outdirname, paste0(filestub, '_volcano.png'))
  ggplot(tnfile_ttest, aes(x=dW, y=logp, col=Significant))+geom_point()+theme_minimal()+
    geom_text(aes(label=ifelse(Significant,as.character(locus.x),'')),hjust=0,vjust=0)+
    scale_color_manual(values=c("black", "red"))
  ggsave(volcanoname, width=10, height=6)
  
  #make a scatter plot comparing the fitness in the two experiments
  corrplotname <- file.path(outdirname, paste0(filestub, '_comparison.png'))
  ggplot(tnfile_ttest, aes(x=W.x, y=W.y, col=Significant))+geom_point()+theme_minimal()+
    geom_text(aes(label=ifelse(Significant,as.character(locus.x),'')),hjust=0,vjust=0)+
    scale_color_manual(values=c("black", "red"))
  ggsave(corrplotname, width=10, height=6)
}
