# Usage:
# R --slave --vanilla --args "[inDirectory]" "[outDirectory]" < RORUTADIS-RepresentativeValueFunction.R

rm(list=ls())

library(rorutadis)
library(RXMCDA)

stopifnot(packageVersion("rorutadis") >= "0.3.1") # rorutadis in version 0.3.1 or later is required

inDirectory <- normalizePath(commandArgs()[5])
outDirectory <- normalizePath(commandArgs()[6])
errorMessage <- NULL

inputFiles <- c("alternatives.xml",
                "criteria.xml",
                "performanceTable.xml",
                "categories.xml",
                "assignmentExamples.xml",
                "assignmentComparisons.xml",
                "categoriesCardinalities.xml",
                "methodParameters.xml",
                "preferenceRelation.xml")
isMandatory <- c(T, T, T, T, F, F, F, T, F)

trees <- list()
setwd(inDirectory)

for (i in seq_len(length(inputFiles))) {
  tree <- NULL
  
  if (file.exists(inputFiles[i])) {  
    tmpErr <- try({
      tree <- xmlTreeParse(inputFiles[i], useInternalNodes=TRUE)
    })
    
    if (inherits(tmpErr, 'try-error')) {
      trees[[i]] <- paste("Error reading file ", inputFiles[i],": ", gsub("\n$", "", tmpErr[1]), sep = "")
    } else if (checkXSD(tree) == 0) {
      trees[[i]] <- paste(inputFiles[i], " is not XMCDA valid.", sep="")
    } else {
      trees[[i]] <- tree
    }
  } else {
    if (isMandatory[i]) {
      trees[[i]] <- paste("Missing file: ", inputFiles[i], ".", sep="")
    } else {
      trees[i] <- list(NULL)
    }
  }
}

names(trees) <- gsub("\\.xml$", "", inputFiles)

fileErrors <- which(sapply(trees, typeof) == "character")

if (length(fileErrors) == 0) {
  # There was not file error.
  dataError <- NULL
  
  ############# mandatory
  
  #### alternatives
  
  if (is.null(dataError)) {
    data <- getNumberOfAlternatives(trees$alternatives)
    if (data$status == "OK") nrAlternatives <- data[[1]]
    else dataError <- data$status
  }
  
  if (is.null(dataError)) {
    data <- getAlternativesIDs(trees$alternatives)
    if (data$status == "OK") alternativesIDs <- data[[1]]
    else dataError <- data$status
  }
  
  #### criteria
  
  if (is.null(dataError)) {
    data <- getNumberOfCriteria(trees$criteria)
    if (data$status == "OK") nrCriteria <- data[[1]]
    else dataError <- data$status
  }
  
  if (is.null(dataError)) {
    data <- getCriteriaIDs(trees$criteria)
    if (data$status == "OK") criteriaIDs <- data[[1]]
    else dataError <- data$status
  }
  
  if (is.null(dataError)) {
    data <- getCriteriaValues(trees$criteria, criteriaIDs, "numberOfCharacteristicPoints")
    if (data$status != "OK") dataError <- data$status
  }
  
  if (is.null(dataError)) {
    characteristicPoints <- rep(0, nrCriteria)
    if (!is.null(data[[1]])) {
      for (i in 1:nrow(data[[1]])) {
        characteristicPoints[data[[1]][i, 1]] = data[[1]][i, 2]
      }
    }
  }
  
  if (is.null(dataError)) {
    data <- getCriteriaValues(trees$criteria, criteriaIDs, "preferenceDirection")
    if (data$status != "OK") dataError <- data$status
  }
  
  if (is.null(dataError)) {
    criteriaPreferenceDirections <- rep('g', nrCriteria)
    if (!is.null(data[[1]])) {
      for (i in 1:nrow(data[[1]])) {
        if (data[[1]][i, 2] == 0)
          criteriaPreferenceDirections[data[[1]][i, 1]] = 'g'
        else
          criteriaPreferenceDirections[data[[1]][i, 1]] = 'c'
      }
    }
  }
  
  #### performanceTable
  
  if (is.null(dataError)) {
    data <- getPerformanceTables(trees$performanceTable, alternativesIDs, criteriaIDs)
    if (data$status == "OK") performanceTables <- data[[1]]
    else dataError <- data$status
  }
  
  #### categories
  
  if (is.null(dataError)) {
    data <- getNumberOfCategories(trees$categories)
    if (data$status == "OK") nrCategories <- data[[1]]
    else dataError <- data$status
  }
  
  if (is.null(dataError)) {
    data <- getCategoriesIDs(trees$categories)
    if (data$status == "OK") categoriesIDs <- data[[1]]
    else dataError <- data$status
  }
  
  ############# optional
  
  #### alternativeAssignemnts
  
  assignmentExamples <- NULL
  
  if (is.null(dataError) && !is.null(trees$assignmentExamples)) {
    data <- getAlternativesAffectations(trees$assignmentExamples, alternativesIDs, categoriesIDs)
    if (data$status == "OK") assignmentExamples <- data[[1]]
    else dataError <- data$status
  }
  
  #### alternativeComparisons
  
  assignmentPairwiseAtLeastComparisons <- NULL
  assignmentPairwiseAtMostComparisons <- NULL
  
  if (is.null(dataError) && !is.null(trees$assignmentComparisons)) {
    data <- getAlternativesComparisonsValues(trees$assignmentComparisons, alternativesIDs)
    if (data$status == "OK") {
      assignmentPairwiseAtLeastComparisons <- data$atLeastAsGoodAs
      assignmentPairwiseAtMostComparisons <- data$atMostAsGoodAs
    }
    else dataError <- data$status
  }
  
  #### categoriesCardinalities
  
  categoriesCardinalities <- NULL
  
  if (is.null(dataError) && !is.null(trees$categoriesCardinalities)) {
    data <- getCategoriesIntervalValues(trees$categoriesCardinalities, categoriesIDs)
    if (data$status == "OK") categoriesCardinalities <- data[[1]]
    else dataError <- data$status
  }
  
  #### preferenceRelation
  
  preferenceRelation <- NULL
  
  if (is.null(dataError) && !is.null(trees$preferenceRelation)) {
    data <- getAlternativesComparisonsValues(trees$preferenceRelation, alternativesIDs)
    if (data$status == "OK") preferenceRelation <- data[[1]]
    else dataError <- data$status
  }
  
  ############# parameters
  
  if (is.null(dataError)) {
    data <- getParameters(trees$methodParameters, "strictlyMonotonicValueFunctions")
    if (data$status == "OK") strictVF <- data[[1]]
    else dataError <- data$status
  }
  
  if (is.null(dataError)) {
    data <- getParameters(trees$methodParameters, "mode")
    if (data$status == "OK") {
      if (data[[1]] == "iterative") mode <- 0
      else if (data[[1]] == "compromise") mode <- 1
    }
    else dataError <- data$status
  }
  
  if (is.null(dataError)) {
    tmpErr <- try({
      problem <- buildProblem(performanceTables, nrCategories, strictVF,
                              criteriaPreferenceDirections, characteristicPoints)
      
      if (!is.null(assignmentExamples)) {
        for (i in seq_len(nrow(assignmentExamples))) {
          affectations = which (assignmentExamples[i, ] == TRUE)
          if (length(affectations) > 0) {
            firstTrue = min(affectations)
            lastTrue = max(affectations)
            
            if (length(firstTrue) > 0 && firstTrue > 1)
              problem <- addAssignmentsLB(problem, c(i, firstTrue))
            
            if (length(lastTrue) > 0 && lastTrue < nrCategories)
              problem <- addAssignmentsUB(problem, c(i, lastTrue))
          }
        }
      }
      
      problem$assignmentPairwiseAtLeastComparisons <- assignmentPairwiseAtLeastComparisons
      problem$assignmentPairwiseAtMostComparisons <- assignmentPairwiseAtMostComparisons
      problem$minimalClassCardinalities <-
        categoriesCardinalities[!is.na(categoriesCardinalities[, 2]), -3, drop=FALSE]
      problem$maximalClassCardinalities <-
        categoriesCardinalities[!is.na(categoriesCardinalities[, 3]), -2, drop=FALSE]      
      
      if (is.null(preferenceRelation)) {
        preferenceRelationMatrix <- NULL
      } else {
        preferenceRelationMatrix <- matrix(data = c(FALSE),
                                           ncol = nrAlternatives,
                                           nrow = nrAlternatives)
        
        for (i in seq_len(nrow(preferenceRelation))) {
          preferenceRelationMatrix[preferenceRelation[i, 1],
                                   preferenceRelation[i, 2]] <- TRUE
        }
      }
      
      representativeFunction <- findRepresentativeFunction(problem, mode, preferenceRelationMatrix)
      
      if(!is.null(representativeFunction)) {
        thresholds <- c(0, getThresholds(problem, representativeFunction))
        thresholds <- cbind(1:nrCategories, thresholds)
        alternativesUtilityTable <- getMarginalUtilities(problem, representativeFunction)
        rownames(alternativesUtilityTable) <- alternativesIDs
        colnames(alternativesUtilityTable) <- criteriaIDs
        criteriaFunctions <- getCharacteristicPoints(problem, representativeFunction)
        names(criteriaFunctions) <- criteriaIDs
        assignments <- getAssignments(problem, representativeFunction)
        assignmentsMatrix <- matrix(data = FALSE, nrow = nrAlternatives, ncol = nrCategories)
        for (i in seq_len(length(assignments))) {
          assignmentsMatrix[i, assignments[i]] <- TRUE
        }
      }
    })
    
    if (inherits(tmpErr, 'try-error')) {
      # Execution error.
      errorMessage <- paste("Execution error: ", gsub("\n$", "", gsub("^.*: ", "", tmpErr[1])), sep = "")
    } else if (is.null(representativeFunction)) {
      errorMessage <- "Representative function not found."
    } else {
      # Success.
      setwd(outDirectory)
      
      tree <- newXMLDoc()
      newXMLNode("xmcda:XMCDA", 
                 attrs = c("xsi:schemaLocation" = "http://www.decision-deck.org/2009/XMCDA-2.0.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.0.0.xsd"),
                 suppressNamespaceWarning = TRUE, 
                 namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2009/XMCDA-2.0.0"), 
                 parent = tree)
      putCategoriesValues(tree, thresholds, categoriesIDs, "thresholds")
      saveXML(tree, file = "thresholds.xml")
      tree <- newXMLDoc()
      
      newXMLNode("xmcda:XMCDA", 
                 attrs = c("xsi:schemaLocation" = "http://www.decision-deck.org/2009/XMCDA-2.0.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.0.0.xsd"),
                 suppressNamespaceWarning = TRUE, 
                 namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2009/XMCDA-2.0.0"), 
                 parent = tree)
      putPointsCriterionFunction(tree, criteriaFunctions)
      saveXML(tree, file = "marginalValueFunctions.xml")
      tree <- newXMLDoc()
      
      newXMLNode("xmcda:XMCDA", 
                 attrs = c("xsi:schemaLocation" = "http://www.decision-deck.org/2009/XMCDA-2.0.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.0.0.xsd"),
                 suppressNamespaceWarning = TRUE, 
                 namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2009/XMCDA-2.0.0"), 
                 parent = tree)
      putPerformanceTable(tree, alternativesUtilityTable)
      saveXML(tree, file = "alternativesValuesTable.xml")
      
      tree <- newXMLDoc()
      newXMLNode("xmcda:XMCDA", 
                 attrs = c("xsi:schemaLocation" = "http://www.decision-deck.org/2009/XMCDA-2.0.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.0.0.xsd"),
                 suppressNamespaceWarning = TRUE, 
                 namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2009/XMCDA-2.0.0"), 
                 parent = tree)
      putAlternativesAffectations(tree, assignmentsMatrix, alternativesIDs, categoriesIDs, TRUE)
      saveXML(tree, file = "assignments.xml")
    }
  }
  else {
    # There was data error.
    errorMessage <- dataError
  }
} else {
  # There was at least one file error.
  errorMessage <- paste(unlist(trees[fileErrors]), collapse = " ")
}

setwd(outDirectory)

tree <- newXMLDoc()
newXMLNode("xmcda:XMCDA", 
           attrs = c("xsi:schemaLocation" = "http://www.decision-deck.org/2009/XMCDA-2.0.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.0.0.xsd"),
           suppressNamespaceWarning = TRUE, 
           namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2009/XMCDA-2.0.0"), 
           parent = tree)

if (is.null(errorMessage)) {
  putLogMessage(tree, "OK", name = "executionStatus")
} else {
  putLogMessage(tree, errorMessage, name = "Error")
}

saveXML(tree, file = "messages.xml")
