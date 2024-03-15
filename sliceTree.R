#!/usr/bin/env Rscript
options(stringsAsFactors=FALSE)

library(argparser)

#process command line arguments
p <- arg_parser(
  "Slice file system tree into slices of desired size",
  name="diskSlicer.R"
)
p <- add_argument(p, "--maxDepth", help="maximum tree depth",default=4L)
p <- add_argument(p, "--sliceSize", help="Maximum size of tree slice",default="18T")
p <- add_argument(p, "baseDir", help="base directory for search", default=".")
# args <- list(maxDepth=4L,sliceSize="10G",baseDir="/home/jweile")
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
  brNames <- names(tree)[names(tree)!="/"]
  if (length(brNames) > 0) {
    #sort branches by size
    brSizes <- sapply(brNames,\(b) tree[[b]][["/"]])
    brNames <- brNames[order(brSizes,decreasing=TRUE)]
    branches <- brNames |> lapply(\(b) sortTree(tree[[b]])) |> setNames(brNames)
    return(c(branches,`/`=tree[["/"]]))
  } else {
    return(tree)
  }
}

# fetchSubtree <- function(tree,path) {
#   for (node in path) {
#     if (node %in% names(tree)) {
#       tree <- tree[[node]]
#     } else {
#       stop("Path does not exist!")
#     }
#   }
#   return(tree)
# }

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

# fixSizes <- function(tree) {
#   if ("/" %in% names(tree) && length(tree[["/"]]) > 0 && !is.na(tree[["/"]])) {
#     return(tree)
#   } 
#   branchNames <- names(tree)[which(names(tree)!="/")]
#   if (length(branchNames) > 0) {
#     tree <- lapply(branchNames, \(b) fixSizes(tree[[b]])) |> setNames(branchNames)
#     tree[["/"]] <- sum(sapply(tree[branchNames],`[[`,"/"))
#   }
#   return(tree)
# }

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

# seizePath <- function(node,maxSize,path=NULL) {
#   if (node[["/"]] > maxSize) {
#     branches <- names(node)[which(names(node)!="/")]
#     if (length(branches) > 0) {
#       return(seizePath(node[[branches[[1]]]],maxSize,c(path,branches[[1]])))
#     } else {
#       return(NA)
#     }
#   } else {
#     return(path)
#   }
# }

# removeSubtree <- function(tree,path) {
#   if (length(path) > 1) {
#     prunedBranch <- removeSubtree(tree[[path[[1]]]],path[[-1]])
#     removedSize <- tree[[path[[1]]]][["/"]] - prunedBranch[["/"]]
#     tree[[path[[1]]]] <- prunedBranch
#   } else {#i.e. we've reached the end of the path
#     removedSize <- tree[[path]][["/"]]
#     tree <- tree[-which(names(tree)==path)]
#   }
#   tree[["/"]] <- tree[["/"]] - removedSize
#   return(tree)
# }

# sliceTree <- function(tree,targetSize) {
#   tree <- tree[[1]]
#   remainingSpace <- targetSize
#   paths <- list()
#   while (remainingSpace > 0) {
#     path <- seizePath(tree,remainingSpace)
#     print(path)
#     if (any(is.na(path))) {
#       #then no more paths fit within the remaining Space
#       break
#     }
#     paths <- c(paths,path)
#     subtree <- fetchSubtree(tree,path)
#     remainingSpace <- remainingSpace-subtree[["/"]]
#     tree <- removeSubtree(tree,path)
#   }
#   list(paths=paths,size=targetSize-remainingSpace)
# }

flattenTree <- function(tree,path=NULL,nodeName=NULL) {
  brNames <- names(tree)[names(tree)!="/"]
  if (length(brNames) > 0) {
    retList <- lapply(brNames, \(b) flattenTree(tree[[b]], path=c(path,nodeName), nodeName=b) )
    do.call(c,retList)
  } else {
    list(list(path=c(path,nodeName),size=tree[["/"]]))
  }
}

sliceFlatTree <- function(flTree, targetSize) {
  sizes <- sapply(flTree,`[[`,"size")
  paths <- flTree |> sapply(`[[`,"path") |> sapply(paste,collapse="/")
  tranches <- list()
  while(length(paths) > 0) {
    currentTranch <- integer(0)
    currentTranchSize <- 0
    i <- 1
    while (currentTranchSize < targetSize && i <= length(sizes)) {
      if (currentTranchSize + sizes[[i]] < targetSize) {
        currentTranch <- c(currentTranch,i)
        currentTranchSize <- currentTranchSize + sizes[[i]]
      }
      i <- i+1
    }
    if (length(currentTranch) == 0) {
      warning("Unable to fit all files within contraints!")
      break
    }
    tranches <- c(tranches,list(list(tranch=paths[currentTranch],size=currentTranchSize)))
    # flTree <- flTree[-currentTranch]
    sizes <- sizes[-currentTranch]
    paths <- paths[-currentTranch]
  }
  return(list(tranches=tranches,remainder=paths))
}

formatSize <- function(kb) {
  units <- c("K","M","G","T","P")
  num <- kb
  i <- 1
  while(num/1024 > 1) {
    num <- num/1024
    i <- i+1
  }
  sprintf("%.02f%s",num,units[[i]])
}

printSlices <- function(slices,absolute=FALSE) {
  for (i in 1:length(slices$tranches)) {
    tranch <- slices$tranches[[i]]
    cat(sprintf("\n\n\n############\n Slice %02d\n Size: %s\n############\n",i,formatSize(tranch$size)))
    if (absolute) {
      tranch <- sapply(tranch, \(x) paste0("/",x))
    }
    writeLines(tranch$tranch)
  }
}

cat("Scanning...\n")
incon <- pipe(sprintf("du -d %d %s",args$maxDepth, args$baseDir),open="r")
lines <- readLines(incon)
close(incon)

cat("Reconstructing filesystem tree...\n")
#absolute paths start with "/", which means strsplit will produce an emtpy element
absolute <- substr(args$baseDir,1,1)=="/"
pstart <- if (absolute) 3 else 2
tree <- list()
for (fs in strsplit(lines,"\\t|/")) {
  #convert KiB to GiB
  # size <- as.numeric(fs[[1]])/(2^20)
  size <- as.numeric(fs[[1]])
  tree <- treeInsert(tree,fs[pstart:length(fs)],size) 
}
# tree <- fixSizes(tree)

cat("Slicing...\n")

slices <- tree |> sortTree() |> flattenTree() |> sliceFlatTree(sliceSizeKB)

printSlices(slices,absolute)



