#!/usr/bin/env Rscript
options(stringsAsFactors=FALSE)

library(argparser)

#process command line arguments
p <- arg_parser(
  "Slice file system tree into slices of desired size",
  name="diskSlicer.R"
)
p <- add_argument(p, "--maxDepth", help="maximum tree depth",default=2L)
p <- add_argument(p, "--sliceSize", help="Maximum size of tree slice",default="18T")
args <- parse_args(p)

ssRaw <- as.numeric(substr(args$sliceSize,1,nchar(args$sliceSize)-1))
sliceUnit <- substr(args$sliceSize,nchar(args$sliceSize),nchar(args$sliceSize))
sliceSizeKB <- switch(toupper(sliceUnit),
  # K=sliceSize*1024,
  M=ssRaw*2^10,
  G=ssRaw*2^20,
  T=ssRaw*2^30,
  P=ssRaw*2^40,
  stop("Slice size: Unrecognized Unit")
)

treeInsert <- function(tree,path,leaf) {
  if (length(path)==0) {
    tree[["/"]] <- leaf
  } else {
    cn <- path[[1]]
    if (cn %in% names(tree)) {
      tree[[cn]] <- treeInsert(tree[[cn]],path[-1],leaf) 
    } else {
      tree[[cn]] <- treeInsert(list(),path[-1],leaf)
    }
  }
  return(tree)
}

sortTree <- function(tree) {
  branches <- names(tree)[names(tree)!="/"]
  if (length(branches) > 0) {
    #sort branches by size
    brSizes <- sapply(branches,function(branch)tree[[branch]][["/"]])
    branches <- branches[order(brSizes,decreasing=TRUE)] |> lapply(\(b) sortTree(tree[[b]])) |> setNames(branches)
    return(c(branches,`/`=tree[["/"]]))
  } else {
    return(tree)
  }
}

fetchSubtree <- function(tree,path) {
  for (node in path) {
    if (node %in% names(tree)) {
      tree <- tree[[node]]
    } else {
      stop("Path does not exist!")
    }
  }
  return(tree)
}

printTree <- function(tree,level=0) {
  leaf <- which(names(tree)=="/")
  spacer <- paste(rep("    ",level),collapse="")
  if (length(leaf)==0) { 
    branches <- names(tree)
  } else {
    branches <- names(tree)[-leaf]
  }
  if (length(branches) > 0) {
    for (branch in branches) {
      brSize <- tree[[branch]][["/"]]
      cat(sprintf("%s%s    %dK\n",spacer,branch,brSize))
      printTree(tree=tree[[branch]],level=level+1)
    }
  }
}

# recalculateSizes <- function(tree) {
#   branchNames <- names(tree)[which(names(tree)!="/")]
#   if (length(branchNames) > 0) {
#     newTree <- lapply(branchNames,\(b) recalculateSizes(tree[[b]])) |> setNames(branchNames)
#     newTree[["/"]] <- sum(sapply(newTree,`[[`,"/"))
#     if (newTree[["/"]] != tree[["/"]]) {
#       cat(sprintf("%d\n",newTree[["/"]]-tree[["/"]]))
#     }
#     return(newTree)
#   } else {
#     return(tree)
#   }
# }

seizePath <- function(node,maxSize,path=NULL) {
  if (node[["/"]] > maxSize) {
    branches <- names(node)[which(names(node)!="/")]
    if (length(branches) > 0) {
      return(seizePath(node[[branches[[1]]]],maxSize,c(path,branches[[1]])))
    } else {
      return(NA)
    }
  } else {
    return(path)
  }
}

removeSubtree <- function(tree,path) {
  if (length(path) > 1) {
    prunedBranch <- removeSubtree(tree[[path[[1]]]],path[[-1]])
    removedSize <- tree[[path[[1]]]][["/"]] - prunedBranch[["/"]]
    tree[[path[[1]]]] <- prunedBranch
  } else {#i.e. we've reached the end of the path
    removedSize <- tree[[path]][["/"]]
    tree <- tree[-which(names(tree)==path)]
  }
  tree[["/"]] <- tree[["/"]] - removedSize
  return(tree)
}


sliceTree <- function(tree,sliceSizeKB) {
  tree <- tree[[1]]
  remainingSpace <- sliceSizeKB
  paths <- list()
  while (remainingSpace > 0) {
    path <- seizePath(tree,remainingSpace)
    print(path)
    if (any(is.na(path))) {
      #then no more paths fit within the remaining Space
      break
    }
    paths <- c(paths,path)
    subtree <- fetchSubtree(tree,path)
    remainingSpace <- remainingSpace-subtree[["/"]]
    tree <- removeSubtree(tree,path)
  }
  list(paths=paths,size=sliceSizeKB-remainingSpace)
}

cat("Scanning...\n")
incon <- pipe(sprintf("du -d %d",args$maxDepth),open="r")
lines <- readLines(incon)
close(incon)

cat("Analyzing data...\n")
tree <- list()
for (fs in strsplit(lines,"\\t|/")) {
  #convert KiB to GiB
  # size <- as.numeric(fs[[1]])/(2^20)
  size <- as.numeric(fs[[1]])
  tree <- treeInsert(tree,fs[2:length(fs)],size)
}
#remove small details
# tree <- pruneTree(tree)

cat("Result:\n\n")

printTree(tree)


