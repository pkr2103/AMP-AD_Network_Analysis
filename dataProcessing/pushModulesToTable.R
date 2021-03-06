brainRegion <- c('dorsolateralPrefrontalCortex',
                 'cerebellum',
                 'temporalCortex',
                 'frontalPole',
                 'inferiorFrontalGyrus',
                 'parahippocampalGyrus',
                 'superiorTemporalGyrus')
grabCurrentModuleManifest <- function(brainRegion){
  synapseClient::synapseLogin()
  regularModuleQuery <- paste0("SELECT * FROM syn8681664 WHERE ( ( study = 'MSBB' OR study = 'MayoRNAseq' OR study = 'ROSMAP' ) AND ( analysisType = 'moduleIdentification' ) AND ( method = 'wina' OR method = 'speakeasy' OR method = 'megena' OR method = 'rWGCNA' ) AND (tissueOfOrigin = '",brainRegion,"') AND (columnScaled = 'TRUE') )")
  model <- list()
  model$module1 <- synapseClient::synTableQuery(regularModuleQuery)@values
  
  metanetModuleQuery <- paste0("SELECT * FROM syn8681664 WHERE ( ( study = 'MSBB' OR study = 'MayoRNAseq' OR study = 'ROSMAP' ) AND ( analysisType = 'consensusModuleIdentification' ) AND (tissueOfOrigin = '",brainRegion,"') AND (columnScaled = 'TRUE') AND (deprecated = 'FALSE') )")
  model$module2 <- synapseClient::synTableQuery(metanetModuleQuery)@values
  res <- rbind(model$module1,
               model$module2[which.max(model$module2$Q),])
  
  return(res)
}
pullAndReformat <- function(manifest){
  bar <- lapply(manifest$id,synapseClient::synGet)
  modules <- lapply(bar,function(x){
    library(dplyr)
    synapseClient::getFileLocation(x) %>%
      data.table::fread(data.table=F)})
  
  names(modules) <- manifest$method
  modules$speakEasy$V1 <- modules$kmeans$Gene.ID
  colnames(modules$speakEasy) <- c('Gene.ID','Module')
  colnames(modules$kmeans)[1:2] <- c('Gene.ID','Module')
  modules$kmeans <- dplyr::select(modules$kmeans,-moduleLabel)

  modules$rWGCNA <- dplyr::select(modules$rWGCNA,V1,dplyr::starts_with('moduleColors'))
  colnames(modules$rWGCNA) <- c('Gene.ID','Module')
  
  colnames(modules$megena)[1:2] <- c('Gene.ID','Module')
  modules$megena <- dplyr::select(modules$megena,-is.hub)
  modules$wina <- dplyr::select(modules$wina,Geneid,module)
  colnames(modules$wina)[1:2] <- c('Gene.ID','Module')
  tidyDf <- mapply(function(x,y){
      return(cbind(x,rep(y,nrow(x))))
      },
    modules,
    names(modules),
    SIMPLIFY=FALSE)
  tidyDf <- do.call(rbind,tidyDf)
  colnames(tidyDf)[3] <- 'method'
  
  #make custom name
  tidyDf <- dplyr::mutate(tidyDf,ModuleName = paste0(tidyDf$method,tidyDf$Module))
  
  #get hugo ids
  ensgIds <- unique(tidyDf$Gene.ID)
  fullIds <- utilityFunctions::convertEnsemblToHgnc(ensgIds)
  
  tidyDf <- dplyr::left_join(tidyDf,fullIds,by=c('Gene.ID'='ensembl_gene_id'))
  colnames(tidyDf)[1] <- 'GeneID'
  
  return(tidyDf)
}

mods <- list()
mods$dlpfc <- grabCurrentModuleManifest(brainRegion[1]) %>% pullAndReformat
mods$cbe <- grabCurrentModuleManifest(brainRegion[2]) %>% pullAndReformat
mods$tcx <- grabCurrentModuleManifest(brainRegion[3]) %>% pullAndReformat
mods$fp <- grabCurrentModuleManifest(brainRegion[4]) %>% pullAndReformat
mods$ifg <- grabCurrentModuleManifest(brainRegion[5]) %>% pullAndReformat
mods$phg <- grabCurrentModuleManifest(brainRegion[6]) %>% pullAndReformat
mods$stg <- grabCurrentModuleManifest(brainRegion[7]) %>% pullAndReformat

#mods <- do.call(rbind,mods)
addBrainRegionFxn <- function(x,y){
  x$brainRegion <- rep(y,nrow(x))
  return(x)
}

mods2 <- mapply(addBrainRegionFxn,
                mods,
                names(mods)%>%toupper,
                SIMPLIFY=F)
allMods <- do.call(rbind,mods2)
allMods$ModuleNameFull <- paste0(allMods$ModuleName,allMods$brainRegion)
allMods$ModuleNameFull <- gsub("kmeans","metanetwork",allMods$ModuleNameFull)
allMods$method <- gsub("kmeans","metanetwork",allMods$method)
allMods$ModuleName <- gsub("kmeans","metanetwork",allMods$ModuleName)
rSynapseUtilities::makeTable(allMods,'full individual module manifest August 14 2017','syn2370594')

