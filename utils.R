library(purrr)
library(stringr)

# Implements a "safe" version of a:b that returns an empty vector when b < a.
safe.colon <- function(from = 1, to = 1) {
    if (to < from) c()
    else from:to
}

# Function to generate the sign vectors of length p.
# If I is 0 we return a matrix with all ds in columns.
d <- function(p, I = 0) {
    if (I == 0) {
        (-1)^matrix(as.numeric(intToBits(1:2^p - 1)), nrow = 32)[1:p,]
    } else {
        (-1)^as.numeric(intToBits(I-1))[1:p]
    }
}

# Curries the parameter p into the d function.
d.factory <- function(p) {
    d.curried <- function(I) { d(p, I) }
    d.curried
}

# Implements the vectorized sign function so that |v|_i = v_i * sign(v)_i.
sgn <- function(vector) {
    sign(0.5 + sign(vector))
}

# Function that builds a diagonal matrix out of an input vector v or an input matrix M.
## If the input is a vector, creates a diagonal matrix with v as main diagonal.
## If the input is a matrix, creates a diagonal matrix with the same diagonal as M.
diag.matrix <- function(vM) {
    if (is.matrix(vM) && nrow(vM) > 1 && ncol(vM) > 1) vM <- diag(vM)
    else if (is.matrix(vM) && (nrow(vM) == 1 || ncol(vM) == 1)) vM <- as.vector(vM)
    diag(vM)
}

normalize <- function(v) {
    # Normalize a vector to norm 1. If the vector has a norm very close to 0 return the 0 vector.
    norm <- sqrt(v%*%v)[1,1]
    if (round(norm, digits=5) > 0) {
        v/norm
    } else {
        0*v
    }
}

# Implements the modified Gram-Schmidt orthogonalization process (the modified alorithm introduces less floating-point errors).
# The input vectors must be the columns of the input matrix.
gram.schmidt <- function(vector.matrix) {
    result <- matrix(0, ncol = ncol(vector.matrix), nrow = nrow(vector.matrix))
    for (i in safe.colon(1, ncol(vector.matrix))) {
        v <- vector.matrix[,i]
        for (k in safe.colon(1, i-1)) {
            v <- v - (v%*%result[,k])[1,1]*result[,k]
        }
        result[, i] <- normalize(v)
    }
    result
}

# Returns a matrix P such that Pv is orthogonal to any of the column vectors of the input matrix.
orthogonal.projection.matrix <- function(vector.matrix) {
    result <- diag(nrow(vector.matrix))
    for (i in safe.colon(1, ncol(vector.matrix))) {
        result <- result - vector.matrix[, i]%*%t(vector.matrix[, i])
    }
    result
}

# Helper function to set the axis of the plots
stretch.axis <- function(axis) {
    axis.range <- axis[2] - axis[1]
    delta <- 0.1*axis.range
    return(c(axis[1]-delta, axis[2]+delta))
}

# Helper function to plot two variables, one VS the other
plot.VS <- function(C, R, vars, border = NULL, saveToPDF = "", ...) {
    # Plots the vars[1] variable VS vars[2].
    xaxis <- stretch.axis(c(
        min(C[, vars[1]]-abs(R[, vars[1]])),
        max(C[, vars[1]]+abs(R[, vars[1]]))
    ))
    yaxis <- stretch.axis(c(
        min(C[, vars[2]]-abs(R[, vars[2]])),
        max(C[, vars[2]]+abs(R[, vars[2]]))
    ))
    if (nchar(saveToPDF) > 0) pdf(saveToPDF)
    plot(
        xaxis,
        yaxis,
        xlab = colnames(C)[vars[1]],
        ylab = colnames(C)[vars[2]],
        ...
    )
    rect(
        xleft = C[, vars[1]]-R[, vars[1]],
        ybottom = C[, vars[2]]-R[, vars[2]],
        xright = C[, vars[1]]+R[, vars[1]],
        ytop = C[, vars[2]]+R[, vars[2]],
        border = border
    )
    if (nchar(saveToPDF) > 0) dev.off()
    #legend("topright", legend=as.character(clevels), fill=colours, title="relay")
}

# Helper function to plot interval variables
plot.interval <- function(C, R, var, col = NULL, saveToPDF = "") {
    # Plots the intervals of the variable var.
    xaxis <- stretch.axis(c(
        min(C[, var]-abs(R[, var])),
        max(C[, var]+abs(R[, var]))
    ))
    plot_height <- max(R[, var]) - min(R[, var])
    if (nchar(saveToPDF) > 0) pdf(saveToPDF)
    plot(
        xaxis,
        c(
            min(R[, var]),
            max(R[, var])
        ),
        xlab = colnames(C)[var],
        ylab = "Range",
        ...
    )
    rect(
        xleft = C[, var]-R[, var],
        ybottom = R[, var]-plot_height/100,
        xright = C[, var]+R[, var],
        ytop = R[, var]+plot_height/100,
        density = 50,
        col = col
    )
    if (nchar(saveToPDF) > 0) dev.off()
}

# Computes the ratio of variance explained by the consecutive variables
var.explained <- function(vars) {
    vars <- sort(vars, decreasing = TRUE)
    cumsum(vars)/sum(vars)
}

# Ensures a vector or a row/column matrix is a column matrix
to.column <- function(v) {
    matrix(v, nrow=length(v), ncol=1)
}

to.tex.row <- function(vector, pad.with = NULL) {
    if (!is.null(pad.with)) {
        for (i in 1:length(vector)) {
            vector[i] <- str_pad(vector[i], pad.with, side = "left")
        }
    }
    paste(vector, sep = "", collapse = " & ")
}

to.tex.numeric.table.row <- function(vector, pad.with = NULL) {
    if (!is.null(pad.with)) pad.with <- 2 + pad.with
    to.tex.row(paste0("$", vector, "$"), pad.with = pad.with)
}

to.tex.table <- function(matrix) {
    result <- rep(NA, nrow(matrix))
    max.width <- max(map_int(c(matrix), nchar))
    for (i in 1:nrow(matrix)) result[i] <- to.tex.row(matrix[i, ], pad.with = max.width)
    paste(result, collapse = " \\\\\n")
}

to.tex.numeric.table <- function(matrix) {
    result <- rep("", nrow(matrix))
    max.width <- max(map_int(c(matrix), nchar))
    for (i in 1:nrow(matrix)) {
        result[i] <- to.tex.numeric.table.row(matrix[i, ], pad.with = max.width)
    }
    # Use `writeLines` to print the result decently
    paste(result, collapse = " \\\\\n")
}