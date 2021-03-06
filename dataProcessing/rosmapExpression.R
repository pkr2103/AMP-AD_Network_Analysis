synapseClient::synapseLogin()

exprDataObj <- synapseClient::synGet('syn8456719')

exprData <- data.table::fread(exprDataObj@filePath,data.table=F)

geneKey <- as.matrix(exprData[,1])
#rownames(exprData) <- exprData[,1]
exprData <- exprData[,-c(1)]
exprData <- t(exprData)
colnames(exprData) <- geneKey
exprData <- t(exprData)
#exprData <- exprData[-which(duplicated(rownames(exprData))),]
write.csv(exprData,file='ROSMAP_Expression.csv',quote=F)

#version comment
comment = "ROSMAP expression data processed with the RNAseq reprocessing pipeline in the AMP-AD consortia, residualized for batch and technical confounds without adjusting for clinical or cognitive phenotypes for May 2017 data freeze"

foo = synapseClient::File('ROSMAP_Expression.csv',parentId='syn7981630',versionComment = comment)

bar2 = synapseClient::synGet('syn7981630',downloadFile=F)
anno = synapseClient::synGetAnnotations(bar2)

#annotations
synapseClient::synSetAnnotations(foo) = as.list(anno)


permLink =githubr::getPermlink(repository = 'Sage-Bionetworks/AMP-AD_Network_Analysis',
                               ref = 'branch',
                               refName = 'module-comparisons',
                               repositoryPath = 'rosmapExpression.R')

#provenance and store
foo = synapseClient::synStore(foo,
               used = as.list(c('syn8456719')),
               executed = as.list(c(permLink)),
               activityName = 'Format ROSMAP expression Data',
               activityDescription = 'Push ROSMAP data into format for network pipeline')





