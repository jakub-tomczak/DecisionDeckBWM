#********************helpers.R********************

assert <- function(expression, message)
{
  if(!all(expression))
  {
    stop(if(is.null(message)) "Error" else message)
  }
}


#********************model.R********************

validateData <- function(bestToOthers, worstToOthers, criteriaNames){
  assert(length(bestToOthers) > 1, "Length of the best-to-others or worst-to-others vector should have at least 2 elements.")
  assert(length(bestToOthers) == length(worstToOthers), "Lengths of best-to-others and others-to-worst vectors must be the same.")
  assert(length(bestToOthers) == length(criteriaNames), "Lengths of best-to-others and criteriaNames must be the same.")
  bestToOthersOneIndex <- match(1, bestToOthers)
  worstToOthersOneIndex <- match(1, worstToOthers)
  assert(!is.na(bestToOthersOneIndex) && !is.na(worstToOthersOneIndex), "bestToOthers and worstToOthers vectors must contain number `1`.")
  list(bestToOthers = bestToOthers, worstToOthers = worstToOthers, criteriaNames = criteriaNames)
}

isConsistent <- function(model){
  worstCriterionIndex <- match(1, model$worstToOthers)
  bestOverWorstPreferenceValue <- model$bestToOthers[worstCriterionIndex]

  # a_bj x a_jw = a_bw for all j
  list(isConsistent = all(bestToOthers*worstToOthers == bestOverWorstPreferenceValue), a_bw = bestOverWorstPreferenceValue)
}
# tries to combine constraint, if constraint already belongs to the constraints set then
# it resturns constraints and a flag that indicates that constraints' state hasn't been changed
combineConstraints <- function(constraints, constraint){
  index <- length(constraints)+1
  #return when such constraint is already in constraints list
  for(x in constraints){
    if( length(setdiff(x, constraint)) == 0 ){
      return(list(constraints = constraints, added = FALSE))
    }
  }

  constraints[[index]] <- constraint
  list(constraints = constraints, added = TRUE)
}

# complementary constraint that should be added in case of abs
absConstraint <- function(constraint){
  lhs <- constraint$lhs
  lhs[length(lhs)] <- lhs[length(lhs)] * -1
  abs <- list(lhs = lhs,
              dir = ifelse(constraint$dir == "<=", ">=", ifelse(constraint$dir == ">=", "<=", "==")),
              rhs = constraint$rhs * (-1))
}

# creates constraints, for each j, for w_b - a_bj*w_j or for w_j-a_jw*w_w
# first equation referes to the best-to-others vector, the second one to the others-to-worst vector
createBaseModelConstraints <- function(model, constraints, vectorType, dir, rhs = 0, ksiIndexValue = 0){
  assert(vectorType %in% c("best", "worst"), "vectorType should be either 'best' or 'worst'.")
  vector <- if(vectorType == "best") model$bestToOthers else model$worstToOthers

  # weight that has a number 1 on its index in the vector
  # should be ommited
  weightWithOneIndex <- match(1, vector)

  # number of added constraints is
  # useful for creating constraints opposite to these ones
  numberOfAddedConstraints <-0

  for(j in seq(length(vector))){
    if(j != weightWithOneIndex){
      lhs <- rep(0, length(vector) + 1)

      if(vectorType == "best"){
        # add w_b - a_bj*w_j = 0
        lhs[weightWithOneIndex] <- 1
        lhs[j] <- -vector[j]
      } else {
        # add w_j - a_jw*w_w = 0
        lhs[weightWithOneIndex] <- -vector[j]
        lhs[j] <- 1
      }


      lhs[model$ksiIndex] <- ksiIndexValue
      result <- combineConstraints(constraints, list(lhs = lhs, dir = dir, rhs = rhs))
      if(result$added){
        constraints <- result$constraints
        numberOfAddedConstraints <- numberOfAddedConstraints + 1
      }
    }
  }
  list(constraints = constraints, addedNumber = numberOfAddedConstraints)
}

#constraints for weights' sum and their minimal value (w >= 0)
buildBasicConstraints <- function(model){
  # n variables for weights, 1 for ksi index
  numberOfVariables <- length(model$bestToOthers) + 1

  lhs <- rep(0, numberOfVariables)
  # sum up all weights to 1
  lhs[1:length(lhs)-1] <- 1
  dir <- "=="
  rhs <- 1

  constraints <- list()
  constraints <- combineConstraints(constraints, list(lhs = lhs, dir = dir, rhs = rhs))$constraints
  # all weights must be >= 0
  for(j in seq(length(model$bestToOthers))){
    lhs <- rep(0, numberOfVariables)
    lhs[j] <- 1
    constraints <- combineConstraints(constraints, list(lhs = lhs, direction = ">=", rhs = 0))$constraints
  }
  constraints
}

addConstraintsFromResult <- function(constraints, result){
  if(result$addedNumber > 0){
    constraints <- result$constraints
    #add constraints that arise from removing abs
    #get all constraints that have just been added and multiply them by -1
    constraintsToScale <- tail(constraints, n=result$addedNumber)
    lapply(constraintsToScale, function(x){
      constraints <<- combineConstraints(constraints, absConstraint(x))$constraints # '<<-' refers to outer scope
    })
  }
  constraints
}

constraintsListToMatrix <- function(constraints){
  result <- list()
  #format constraints
  result$lhs <- t(sapply(constraints, function(x){
    x$lhs
  }))
  result$dir <- sapply(constraints, function(x){
    x$dir
  })
  result$rhs <- unlist(sapply(constraints, function(x){
    x$rhs
  }))
  result
}

createModelsObjective <- function(model, objectiveIndex, objectiveValue = 1){
  objective <- rep(0, length(model$bestToOthers) + 1)
  objective[objectiveIndex] <- objectiveValue
  objective
}

#' @export
buildModel <- function(bestToOthers, worstToOthers, criteriaNames, createMultipleOptimalSolutions = FALSE, rankBasedOnCenterOfInterval = FALSE){
  model <- validateData(bestToOthers, worstToOthers, criteriaNames)
  consistency <- isConsistent(model)
  model$isConsistent <- consistency$isConsistent
  model$a_bw <- consistency$a_bw

  # when true, calculated weights are always scalars, not intervals
  model$createMultipleOptimalSolutions = createMultipleOptimalSolutions

  # flag used in getRanking function, when creating final ranking,
  # indicates whether or not to rank by the center of intervals
  # if not, rank based on the interval weights
  model$rankBasedOnCenterOfInterval <- rankBasedOnCenterOfInterval

  #weights' sum and weights' limit value (w >= 0)
  constraints <- buildBasicConstraints(model)

  # ksi index
  model$ksiIndex <- length(model$bestToOthers)+1

  if(model$isConsistent){
    #add best-to-others constraints
    result <- createBaseModelConstraints(model, constraints, vectorType = "best", dir = "==")
    if(result$addedNumber > 0){
      constraints <- result$constraints
    }
  }  else {
      #add best-to-others constraints
      result <- createBaseModelConstraints(model, constraints, vectorType = "best", dir = "<=", ksiIndexValue = -1)
      constraints <- addConstraintsFromResult(constraints, result)

      #add others-to-worst constraints
      result <- createBaseModelConstraints(model, constraints, vectorType = "worst", dir = "<=", ksiIndexValue = -1)
      constraints <- addConstraintsFromResult(constraints, result)


    if(model$createMultipleOptimalSolutions){
      # here we should calculate only ksi value that will be used to
      # create model, which is used to determine lower and upper bounds
      # of the interval weights
      # however, current implementation is wrong
      stop("Calculating weights as intervals is not implemented yet.")

      model$constraints = constraintsListToMatrix(constraints)
      model$objective <- createModelsObjective(model, model$ksiIndex)
      #minimize objective's value
      model$maximize <- FALSE

      model$ksiValue <- solveLP(model)$optimum
      # find minimal values

      #constraints sum of weights to 1, all weights non-negative
      constraints <- buildBasicConstraints(model)

      #add best-to-others constraints
      result <- createBaseModelConstraints(model, constraints, vectorType = "best", dir = "<=", rhs = model$ksiValue)
      constraints <- addConstraintsFromResult(constraints, result)

      #add others-to-worst constraints
      result <- createBaseModelConstraints(model, constraints, vectorType = "worst", dir = "<=", rhs = model$ksiValue)
      constraints <- addConstraintsFromResult(constraints, result)
    }
  }

  model$constraints = constraintsListToMatrix(constraints)
  model$objective <- createModelsObjective(model, model$ksiIndex)
  #minimize objective's value
  model$maximize <- FALSE

  model
}


#********************solver.R********************

#' @import Rglpk
#' @export
solveProblem <- function(model){
  assert(!is.null(model), 'Model cannot be null')
  consistencyIndex <- c(0, .44, 1.0, 1.63, 2.3, 3., 3.73, 4.47, 5.23)
  if(model$isConsistent || (!model$isConsistent && !model$createMultipleOptimalSolutions)){
    #unique optimal solution
    result <- solveLP(model)
    weights <- result$solution[1:model$ksiIndex-1]
    consistencyRatio <- result$solution[model$ksiIndex] / consistencyIndex[as.integer(model$a_bw)]
  } else {
    #multi-optimality, get intervals
    nrCriteria <- length(model$bestToOthers)
    # returns list of length equal to the number of the weights
    # that contains lists of two elements - lower an upper bound
    weights <- lapply(seq(nrCriteria), function(x){
      model$objective <- createModelsObjective(model, x)

      #find lower bound
      model$maximize <- FALSE
      lowerBound <- solveLP(model)$solution[x]

      #find upper bound
      model$maximize <- TRUE
      upperBound <- solveLP(model)$solution[x]

      list(lowerBound, upperBound)
    })
    consistencyRatio <- model$ksiValue / consistencyIndex[as.integer(model$a_bw)]
  }

  ranking <- getRanking(model, weights)
  result <- list(weights = weights, ranking = ranking['ix'], alternativesValues = ranking['x'], consistencyRatio = consistencyRatio)
}

getRanking <- function(model, weights){
  if(model$isConsistent || (!model$isConsistent && !model$createMultipleOptimalSolutions)){
    sorted <- sort(weights, decreasing = TRUE, index.return=TRUE)
  } else {
    if(model$rankBasedOnCenterOfInterval){
      # TODO: rank the criteria or alternatives based on the center of intervals
      stop("Ranking based on the center of intervals is not implemented")
    } else {
      #rank the criteria or alternatives based on the interval weights
      DJ_ij <- sapply(weights, function(a){
        sapply(weights, function(b){
          # a and b in numerator are exchanged, otherwise R creates transposed matrix
          ( max(0, b[[2]] - a[[1]]) - max(0, b[[1]] - a[[2]]) ) / ( (a[[2]] - a[[1]]) + (b[[2]]-b[[1]]) )
        })
      })
      P_ij <- ifelse(DJ_ij > .5, 1, 0)
      rank <- apply(P, MARGIN = 1, function(x){sum(x)})
      sorted <- sort(rank, index.return=TRUE)
    }
  }
  sorted$ix <- model$criteriaNames[sorted$ix]
  sorted
}

solveLP <- function(model){
  Rglpk_solve_LP(model$objective, model$constraints$lhs, model$constraints$dir, model$constraints$rhs, max = model$maximize)
}

