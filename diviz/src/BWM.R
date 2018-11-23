BWM <- function(inputs)
{
  library(Rglpk)
  output <- calculateWeights(inputs$criteria$names, inputs$bestToOthers, inputs$othersToWorst)
  return(output$result)
}
