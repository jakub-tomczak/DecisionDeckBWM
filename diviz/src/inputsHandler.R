library(purrr)

checkAndExtractInputs <- function(xmcdaData, programExecutionResult) { # TODO
  criteria <- getActiveCriteria(xmcdaData)
  
  criteriaNames <- sapply(as.list(criteria$criteria), function(x){x$name()})
  criteriaValuesList <- getNumericCriteriaValuesList(xmcdaData)
  
  if(is_empty(criteriaValuesList)){
    putProgramExecutionResult(xmcdaMessages, errors = "No `criteriaValues` node has been found.")
  }
  
  if(is.null(criteriaValuesList$bestToOthers)){
    putProgramExecutionResult(xmcdaMessages, errors = "`criteriaValues` node with id=`best-to-others` not found.")
  }
  if(is.null(criteriaValuesList$othersToWorst)){
    putProgramExecutionResult(xmcdaMessages, errors = "`criteriaValues` node with id=`others-to-worst` not found.")
  }
  bestToOthers <- criteriaValuesList$bestToOthers
  othersToWorst <- criteriaValuesList$othersToWorst
  return(list(criteria = list(ids = criteria$criteriaIDs, names = criteriaNames), bestToOthers = bestToOthers, othersToWorst = othersToWorst))
}
