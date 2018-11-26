# TODO depending on whether the file was generated from a description based on
# XMCDA v2 or v3, only one list is correct, either XMCDA_v2_TAG_FOR_FILENAME
# or XMCDA_v3_TAG_FOR_FILENAME: check them to determine which one should be
# adapted.

XMCDA_v2_TAG_FOR_FILENAME <- list(
  # output name -> XMCDA v2 tag
  criteriaWeights = "criteriaValues",
  messages = "methodMessages"
)

XMCDA_v3_TAG_FOR_FILENAME <- list(
  # output name -> XMCDA v3 tag
  criteriaWeights = "criteriaValues",
  messages = "programExecutionResult"
)

xmcda_v3_tag <- function(outputName){
  return (XMCDA_v3_TAG_FOR_FILENAME[[outputName]])
}

xmcda_v2_tag <- function(outputName){
  return (XMCDA_v2_TAG_FOR_FILENAME[[outputName]])
}

convertCriteriaWeights <- function(results, programExecutionResult){
  xmcda <- .jnew("org/xmcda/XMCDA")
  criteriaValues <-.jnew("org/xmcda/CriteriaValues")
  for (i in 1:length(results$criteriaIDs)){
    criterion <- .jnew("org/xmcda/Criterion",results$criteriaIDs[i], results$criteriaNames[i])
    criteriaValues$put(criterion, .jnew("java/lang/Double", results$criteriaWeights[i]))
  }
  xmcda$criteriaValuesList$add(criteriaValues)
  xmcda
}

convert <- function(results, programExecutionResult) {
 list(criteriaValues = convertCriteriaWeights(results, programExecutionResult)) 
}
