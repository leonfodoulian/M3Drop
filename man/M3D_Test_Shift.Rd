\name{M3DropTestShift}
\alias{M3DropTestShift}
\title{Test for horizontal shift.}
\description{
	Tests whether a given set of genes are significantly shifted to the left or right of the Michaelis-Menten curve.
}
\usage{
  M3DropTestShift(expr_mat, genes_to_test, name="", background=rownames(expr_mat), suppress.plot=FALSE)
}
\arguments{
  \item{expr_mat}{a numeric matrix of normalized (not log-transformed) expression values, columns = samples, rows = genes.}
  \item{genes_to_test}{vector of gene names to test.}
  \item{name}{string used to title the plot.}
  \item{background}{vector of gene names to test against. (default = all genes)}
  \item{suppress.plot}{logical, whether to the fitted Michaelis-Menten curve and highlight the given set of genes to test.}
}
\details{Fits a Michaelis-Menten function to the dropout-rate of the provided data, then tests whether a given set of genes (eg. pseudogenes) is significantly shifted left or right of the curve. Horizontal residuals are calculated as : \deqn{\log_{10} S - \log_{10} \frac{K*(1-P)}{P}}{log_10(S) - log_10( (K * (1 - P)) / P )}. Uses a Wilcox rank-sum test/Mann-Whitney U test to compare the residuals for the given genes to the residuals for all genes.
}
\value{
A one row dataframe with columns: 
    sample (median horizontal residual of genes in the test set), 
    pop (median horizontal residual of genes in the background set), 
    p.value
}
\examples{
  library(M3DExampleData)
  gene_set <- c("Dppa2","Tdgf1","Rnf130","Tet1","Uhrf1","Pttg1","Zfp600","Stat1")
  shift_output <- M3DropTestShift(Mmus_example_list$data, gene_set)
}
\keyword{residuals}
