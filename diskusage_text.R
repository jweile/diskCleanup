#!/usr/bin/env Rscript
options(stringsAsFactors=FALSE)

library(argparser)

#process command line arguments
p <- arg_parser(
  "Show breakdown of largest files",
  name="diskusage_text.R"
)
p <- add_argument(p, "--maxDepth", help="maximum tree depth",default=2L)
p <- add_argument(p, "--sizeThreshold", help="Only report files greater than this (in MB)",default=100L)
args <- parse_args(p)

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
  tree
}

pruneTree <- function(tree) {
  if (length(tree)==1 && names(tree)[[1]]=="/"){
    return(tree)
  }

  leaf <- which(names(tree)=="/")
  if (length(leaf)==1) {
    treeSize <- tree[[leaf]]
    branches <- names(tree)[-leaf]
    branchSizes <- sapply(branches,function(branch)tree[[branch]][["/"]])
    keep <- which(branchSizes > 0.01*treeSize)
    tree <- c(tree[leaf],tree[branches[keep]])
    for (branch in branches) {
      tree[[branch]] <- pruneTree(tree[[branch]])
    }
  } else {
    for (branch in names(tree)) {
      tree[[branch]] <- pruneTree(tree[[branch]])
    }
  }
  return(tree)
}


fetchPath <- function(tree,path) {
  for (node in path) {
    if (node %in% names(tree)) {
      tree <- tree[[node]]
    } else {
      stop("Path does not exist!")
    }
  }
  tree
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
    #sort branches by size
    brSizes <- sapply(branches,function(branch)tree[[branch]][["/"]])
    branches <- branches[order(brSizes,decreasing=TRUE)]

    for (branch in branches) {
      brSize <- tree[[branch]][["/"]]
      cat(sprintf("%s%s    %.01fG\n",spacer,branch,brSize))
      # cat(spacer,branch,"    ",brSize,"\n")
      printTree(tree=tree[[branch]],level=level+1)
    }
  }
}

cat("Scanning...\n")
incon <- pipe(sprintf("du -d %d -t %dM",args$maxDepth,args$sizeThreshold),open="r")
lines <- readLines(incon)
close(incon)

cat("Analyzing data...\n")
tree <- list()
for (fs in strsplit(lines,"\\t|/")) {
  #convert KiB to GiB
  size <- as.numeric(fs[[1]])/(2^20)
  tree <- treeInsert(tree,fs[3:length(fs)],size)
}
#remove small details
tree <- pruneTree(tree)

cat("Result:\n\n")

printTree(tree)


