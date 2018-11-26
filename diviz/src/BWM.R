BWM <- function(inputs)
{
  library(Rglpk)
  output <- calculateWeights(inputs$criteria$names, inputs$bestToOthers, inputs$othersToWorst)
  output$result$criteriaIDs = inputs$criteria$ids
  return(output$result)
}
