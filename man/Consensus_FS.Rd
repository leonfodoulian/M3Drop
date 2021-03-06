\name{Consensus_FS}
\title{Consensus Feature Selection}
\alias{Consensus_FS}
\description{
	Performs seven different feature selection methods then calculates the consensus ranking of features from that.
}
\usage{
	Consensus_FS(counts, norm=NA, is.spike=rep(FALSE, times=nrow(counts)), pcs=c(2,3))
}
\arguments{
  \item{counts}{raw count matrix, rows=genes, cols=cells}
  \item{norm}{normalized but not log-transformed gene expression matrix, rows=genes, cols=cells}
  \item{is.spike}{logical, vector of whether each gene is/isn't a spike-in}
  \item{pcs}{which principle components to use to score genes}
}
\details{

	Performs:
	\code{NBumiFeatureSelectionCombinedDrop} (aka: DANB_drop)
	\code{NBumiFeatureSelectionHighVar} (aka: DANB_var)
	\code{BrenneckeGetVariableGenes} (aka: HVG)
	\code{M3DropFeatureSelection} (aka: M3Drop)
	\code{giniFS}
	\code{irlbaPcaFS} (with provided PCs)
	\code{corFS} ("both" direction)

	Genes are ranked by each method and the consensus (Cons) is calculated as the average of those ranks.

	Automatically removes invariant genes. If only raw counts are provided then will apply counts per million normalization (scaled to the median library size) for those methods which require normalized data.
	
}
\value{
	Table of ranking of each gene by each method including the consensus (Cons). Columns are feature selection methods named using the shorter aliases (see: Details). 
}

\examples{
library(M3DExampleData)
norm <- Mmus_example_list$data[1:1000,];
norm <- norm[rowSums(norm) > 0,];
counts <- NBumiConvertToInteger(norm);
Features_consensus<- Consensus_FS(counts, norm);
}
\keyword{single cell}
\keyword{feature selection}
