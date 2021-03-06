#### Fitting #####
hidden_calc_vals <- function(counts) {
        if (sum(counts < 0) >0) {stop("Expression matrix contains negative values! Please provide raw UMI counts!")}
	if ( sum(counts >= 1) != sum(counts > 0) ) {stop("Error: Expression matrix is not integers! Please provide raw UMI counts.")}
#        if (sum(!is.integer(counts)) >0) {stop("Expression matrix is not integers! Please provide a matrix (not data.frame) raw UMI counts!")}

        tjs <- rowSums(counts, na.rm=T) # Total molecules/gene
	if (sum(tjs <= 0) > 0) {stop("Error: all genes must have at least one detected molecule.")}
        tis <- colSums(counts, na.rm=T) # Total molecules/cell
	if (sum(tis <= 0) > 0) {stop("Error: all cells must have at least one detected molecule.")}
        djs <- ncol(counts)-rowSums(counts > 0, na.rm=T) # Observed Dropouts per gene
        dis <- nrow(counts)-colSums(counts > 0, na.rm=T) # Observed Dropouts per cell
        nc <- length(counts[1,]) # Number of cells
        ng <- length(counts[,1]) # Number of genes
        total <- sum(tis, na.rm=T) # Total molecules sampled
        return(list(tis=tis, tjs=tjs, dis=dis, djs=djs, total=total,nc=nc,ng=ng));
}

NBumiConvertToInteger <- function(mat) {
        mat <- ceiling(as.matrix(mat))
        storage.mode(mat) <- "integer"
        mat <- mat[rowSums(mat) > 0,]
        return(mat)
}

NBumiFitModel <- function(counts) {
	vals <- hidden_calc_vals(counts);
#	mus <- (vals$tjs) %*% t(vals$tis/vals$total)
	
	convergence <- 0.001
#	max_size <- max(mus)^2;
	min_size <- 10^-10;
#	size <- sapply(1:vals$ng,function(j) {
#		 bg__fit_size_to_var(var(counts[j,]-mus[j,]), mus[j,], max_size=max_size, min_size=10^-10, convergence=0.001)
#		})
	my_rowvar <- sapply(1:nrow(counts), function(i){
				mu_is <- vals$tjs[i]*vals$tis/vals$total
				var(as.vector(unlist(counts[i,]))-mu_is)
			})
#	my_rowvar <- vector(length=nrow(counts));
#	for (i in 1:nrow(counts)) {
#		mu_is <- vals$tjs[i]*vals$tis/vals$total
#		my_rowvar[i] <- var(as.vector(unlist(counts[i,]))-mu_is)
#	}
		
	size <- vals$tjs^2*(sum(vals$tis^2)/vals$total^2)/((vals$nc-1)*my_rowvar-vals$tjs) # for this to work with sparse matrices might need to implement in C
	max_size <- 10*max(size);
	size[size < 0] <- max_size;
	size[size < min_size] <- min_size;
#	size[size > max_size] <- max_size;

	return(list(var_obs=my_rowvar, sizes=size, vals=vals))
}

NBumiFitBasicModel <- function(counts) {
	vals <- hidden_calc_vals(counts);
	mus <- vals$tjs/vals$nc
	v <- rowVars(counts)
	errs <- v < mus;
	v[errs] <- mus[errs]+10^-10;
	size <- mus^2/(v-mus)
	max_size <- max(mus)^2;
	size[errs] <- max_size;
	my_rowvar <- vector(length=nrow(counts));
	for (i in 1:nrow(counts)) {
		my_rowvar[i] <- var(counts[i,]-mus[i])
	}
	#mus_mat <- matrix(rep(mus, times=vals$nc), ncol=vals$nc, byrow=FALSE)
	return(list(var_obs=my_rowvar, sizes=size, vals=vals))
}

NBumiCheckFit <- function(counts, fit, suppress.plot=FALSE) {
	vals <- fit$vals;
	size_mat <- matrix(rep(fit$sizes, times=vals$nc), ncol=vals$nc, byrow=FALSE)
#	vs <- vector(length=nrow(counts));
	row_ps <- vector(length=nrow(counts))
	col_ps <- rep(0, times=ncol(counts))
	for (i in 1:nrow(counts)) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total
		p_is <- (1+mu_is/fit$size[i])^(-fit$size[i]);
		row_ps[i] <- sum(p_is);
		col_ps <- col_ps+p_is;
#		vs[i] <- mean(mu_is+mu_is*mu_is/fit$size[i])
	}
#	thing <- fit$var_obs
#	plot(thing, vs, log="xy", xlab="Observed", ylab="Expected", main="Gene-specific Variance")
#	abline(a=0, b=1, col="red")

#	exp_ps <- (1+fit$mus/size_mat)^(-size_mat)
	if (!suppress.plot) {
		plot(vals$djs, row_ps, xlab="Observed", ylab="Fit", main="Gene-specific Dropouts")
		abline(a=0, b=1, col="red")

		plot(vals$dis, col_ps, xlab="Observed", ylab="Expected", main="Cell-specific Dropouts")
		abline(a=0, b=1, col="red")
	}

	invisible(list(gene_error = sum((vals$djs-row_ps)^2), cell_error = sum((vals$dis-col_ps)^2), rowPs=row_ps, colPs=col_ps));
}

NBumiCheckFitFS <- function(counts, fit, suppress.plot=FALSE) {
	vals <- fit$vals;
	size_coeffs <- NBumiFitDispVsMean(fit, suppress.plot=TRUE) 
	smoothed_size <- exp( size_coeffs[1] + size_coeffs[2]*log(vals$tjs/vals$nc) )
#	size_mat <- matrix(rep(smoothed_size, times=vals$nc), ncol=vals$nc, byrow=FALSE)

# Matrix compatibility
#	vs <- vector(length=nrow(counts));
	row_ps <- vector(length=nrow(counts))
	col_ps <- rep(0, times=ncol(counts))
	for (i in 1:nrow(counts)) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total
		p_is <- (1+mu_is/smoothed_size[i])^(-smoothed_size[i]);
		row_ps[i] <- sum(p_is);
		col_ps <- col_ps+p_is;
#		vs[i] <- mean(mu_is+mu_is*mu_is/fit$size[i])
	}
#	thing <- fit$var_obs;
#	plot(thing, vs, log="xy", xlab="Observed", ylab="Expected", main="Gene-specific Variance")
#	abline(a=0, b=1, col="red")

#	exp_ps <- (1+fit$mus/size_mat)^(-size_mat)
	if (!suppress.plot) {
		plot(vals$djs, row_ps, xlab="Observed", ylab="Fit", main="Gene-specific Dropouts")
		abline(a=0, b=1, col="red")

		plot(vals$dis, col_ps, xlab="Observed", ylab="Expected", main="Cell-specific Dropouts")
		abline(a=0, b=1, col="red")
	}

	invisible(list(gene_error = sum((vals$djs-row_ps)^2), cell_error = sum((vals$dis-col_ps)^2), rowPs=row_ps, colPs=col_ps));
}


NBumiCompareModels <- function(counts, size_factor=(colSums(counts)/median(colSums(counts)))) {
	norm <- NBumiConvertToInteger(t(t(counts)/size_factor));
	counts <- counts[rownames(counts) %in% rownames(norm),]; # necessary for plotting
	fit_adjust <- NBumiFitModel(counts);
	fit_basic <- NBumiFitBasicModel(norm);
	check_adjust <- NBumiCheckFitFS(counts, fit_adjust, suppress.plot=TRUE)
	check_basic <- NBumiCheckFitFS(norm, fit_basic, suppress.plot=TRUE)
	nc = fit_adjust$vals$nc

	plot( fit_adjust$vals$tjs/nc, fit_adjust$vals$djs/nc, col="black", pch=16, xlab="Expression", log="x", ylab= "Dropout Rate", cex=0.75)
#	points( fit_adjust$vals$tjs/nc, fit_basic$vals$djs/nc, col="black", pch=16, cex=0.75)
	points( fit_adjust$vals$tjs/nc, check_adjust$rowPs/nc, col="goldenrod1", pch=16, cex=0.5 )
	points( fit_adjust$vals$tjs/nc, check_basic$rowPs/nc, col="purple", pch=16, cex=0.5 )

	err_adj <- sum(abs(check_adjust$rowPs/nc-fit_adjust$vals$djs/nc))
#	err_bas <- sum(abs(rowSums(check_basic$exp_ps)/nc-fit_basic$vals$djs/nc))
	err_bas <- sum(abs(check_basic$rowPs/nc-fit_adjust$vals$djs/nc))
	legend("bottomleft", paste(c("Depth-Adjusted\nError:", "Basic\nError:"), round(c(err_adj, err_bas)), c("\n","\n")), col=c("goldenrod1","purple"), pch=16, bty="n", cex=0.75)
	out <- c(err_adj, err_bas); names(out) <- c("Depth-Adjusted", "Basic");
	return(out)
}

obsolete__fit_size_to_drop <- function(obs, mu_vec, max_size, min_size=10^-10, convergence=0.001) {
	step_size <- 1;
        size_fit <- 1;
        last <- 0;
        last2 <- 0;
        for (iter in 1:1000) {
        	if (size_fit < min_size) {size_fit <- min_size;}
                diff <- sum( (1+mu_vec/size_fit)^(-size_fit) ) - obs;
                if (abs(diff) < convergence) {return(size_fit)}
                if (diff > 0) {
                	size_fit <- size_fit+step_size;
                        if (last < 0) {
                                step_size <- step_size/2;
                        } else {
                                if (last2 > 0){step_size <- step_size*2;}
                        }
                } else {
                        size_fit <- size_fit-step_size;
                        if (last > 0) {
                                step_size <- step_size/2;
                        } else {
                                if (last2 < 0){step_size <- step_size*2;}
                        }
                }
                last2 <- last; last <- diff;
                if (size_fit > max_size) {return(max_size);}
       }
       warning("Fitting size did not converge.");
       return(size_fit);
}

bg__fit_size_to_var <- function(obs, mu_vec, max_size, min_size=10^-10, convergence=0.001) {
	step_size <- 1;
        size_fit <- 1;
        last <- 0;
        last2 <- 0;
        for (iter in 1:1000) {
        	if (size_fit < min_size) {size_fit <- min_size;}
		expect <- mu_vec+mu_vec*mu_vec/size_fit;
                diff <- sum( expect )/(length(mu_vec)-1) - obs;
                if (abs(diff) < convergence) {return(size_fit)}
                if (diff > 0) {
                	size_fit <- size_fit+step_size;
                        if (last < 0) {
                                step_size <- step_size/2;
                        } else {
                                if (last2 > 0){step_size <- step_size*2;}
                        }
                } else {
                        size_fit <- size_fit-step_size;
                        if (last > 0) {
                                step_size <- step_size/2;
                        } else {
                                if (last2 < 0){step_size <- step_size*2;}
                        }
                }
                last2 <- last; last <- diff;
                if (size_fit > max_size) {return(max_size);}
       }
       warning("Fitting size did not converge.");
       return(size_fit);
}

#### Dispersion vs Mean & Feature Selection ####
NBumiFitDispVsMean <- function(fit, suppress.plot=TRUE) {
	vals <- fit$vals;
	size_g <- fit$sizes
	forfit <- fit$size < max(size_g) & vals$tjs > 0 & size_g > 0
	higher <- log(vals$tjs/vals$nc)/log(2) > 4; # As per-Grun et al.
	if (sum(higher == TRUE) > 2000) {
		forfit = higher & forfit;
	}
	reg <- lm( log(size_g[forfit])~ log((vals$tjs/vals$nc)[forfit]) )
	if (!suppress.plot) {
		plot(log( (vals$tjs/vals$nc)[forfit] ), log(size_g[forfit]), xlab="Log Mean Expression", ylab="Log Size" )
		abline(reg, col="red")
	}
	return(reg$coefficients)
}

hidden_shift_size <- function(mu_all, size_all, mu_group, coeffs) {
	b <- log(size_all)-coeffs[2]*log(mu_all)
	size_group <- exp(coeffs[2]*log(mu_group)+b)
	return(size_group)
}

obsolete__nbumiFeatureSelectionHighVarDist2Med <- function(fit, window_size=1000) {
	vals <- fit$vals;
	mean_order <- order(vals$tjs);
	obs_mean <- vals$tjs[mean_order]/vals$nc
	fit_disp <- fit$sizes[mean_order]
	names(fit_disp) <- names(vals$tjs)
	keep <- fit_disp < max(fit_disp)
	fit_disp <- log(fit_disp[keep])
	obs_mean <- obs_mean[keep]
	if (window_size %% 2 == 0) {
		flank <- window_size/2;
	} else {
		flank <- (window_size+1)/2;
	}
	dist_from_med <- function(x) {
		low <- max(1, x-flank);
		high <- min(length(fit_disp), x+flank);
		return(fit_disp[x]-median(fit_disp[seq(from=low, to=high, by=1)]))
	}
	score <- sapply(1:length(fit_disp), dist_from_med)
	return(sort(score))
}

NBumiFeatureSelectionHighVar <- function(fit) {
	# Global mean-variance
	vals <- fit$vals;
	coeffs <- NBumiFitDispVsMean(fit, suppress.plot=TRUE);
	exp_size <- exp( coeffs[1] + coeffs[2]*log(vals$tjs/vals$nc) )
	res <- log(fit$size) - log(exp_size);
	return(sort(res))
}

obsolete__nbumiFeatureSelectionDropouts <- function(fit) {
	# Gene-specific variance, mean
	vals <- fit$vals;
	size_mat <- matrix(rep(fit$sizes, times=vals$nc), ncol=vals$nc, byrow=F)

	droprate_exp <- vector(length=vals$ng)
	droprate_exp_err <- vector(length=vals$ng)
	for (i in 1:vals$ng) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total
		p_is <- (1+mu_is/vals$size[i])^(-vals$size[i]);
		p_var_is <- p_is*(1-p_is);
		droprate_exp[i] <- sum(p_is)/vals$nc;
		droprate_exp_err[i] <- sqrt(sum(p_var_is)/(vals$nc^2));
	}
#	Exp_p <- (1+fit$mus/size_mat)^(-size_mat)
#	Exp_p_var <- Exp_p*(1-Exp_p)

#	droprate_exp <- rowSums(Exp_p)/vals$nc
	droprate_exp[droprate_exp < 1/vals$nc] <- 1/vals$nc # Is this necessary?
#	droprate_exp_err <- sqrt(rowSums(Exp_p_var)/(vals$nc^2))
	droprate_obs <- vals$djs/vals$nc
	droprate_obs_err <- sqrt(droprate_obs*(1-droprate_obs)/vals$nc)

	diff <- droprate_obs-droprate_exp
	combined_err <- droprate_exp_err
	Zed <- diff/combined_err
        pvalue <- pnorm(Zed, lower.tail = FALSE)
	names(pvalue) <- names(vals$tjs)
	return(sort(pvalue))
}

NBumiFeatureSelectionCombinedDrop <- function(fit, ntop=NULL, fdr=2, suppress.plot=TRUE) {
	# Global mean-variance, gene-specific mean
	vals <- fit$vals;

	coeffs <- NBumiFitDispVsMean(fit, suppress.plot=TRUE);
	exp_size <- exp( coeffs[1] + coeffs[2]*log(vals$tjs/vals$nc) )

	#size_mat <- matrix(rep(exp_size, times=vals$nc), ncol=vals$nc, byrow=F)
	#Exp_p <- (1+fit$mus/size_mat)^(-size_mat)
	#Exp_p_var <- Exp_p*(1-Exp_p)

	droprate_exp <- vector(length=vals$ng)
	droprate_exp_err <- vector(length=vals$ng)
	for (i in 1:vals$ng) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total
		p_is <- (1+mu_is/exp_size[i])^(-exp_size[i]);
		p_var_is <- p_is*(1-p_is);
		droprate_exp[i] <- sum(p_is)/vals$nc;
		droprate_exp_err[i] <- sqrt(sum(p_var_is)/(vals$nc^2));
	}

	#droprate_exp <- rowSums(Exp_p)/vals$nc
	droprate_exp[droprate_exp < 1/vals$nc] <- 1/vals$nc # Is this necessary?
	#droprate_exp_err <- sqrt(rowSums(Exp_p_var)/(vals$nc^2))
	droprate_obs <- vals$djs/vals$nc
	droprate_obs_err <- sqrt(droprate_obs*(1-droprate_obs)/vals$nc)

	diff <- droprate_obs-droprate_exp
	combined_err <- sqrt(droprate_exp_err^2+droprate_obs_err^2)
	#alt_err <- sd(diff)/sqrt(vals$nc);
	Zed <- diff/combined_err
        pvalue <- pnorm(Zed, lower.tail = FALSE)
	names(pvalue) <- names(vals$tjs)
	reorder <- order(pvalue, droprate_exp-droprate_obs) # deal with ties (e.g. lots of zero p-values)

	out <- pvalue[reorder]
	qval <- p.adjust(out, method="fdr")

	if (!suppress.plot) {
		xes <- vals$tjs/vals$nc;
		plot(xes, droprate_obs, col="black", pch=16, log="x")
		points(xes, droprate_exp, col="goldenrod1", pch=16, cex=0.5)
		if (is.null(ntop)) {
			toplot = names(out)[qval < fdr]
		} else {
			toplot = names(out)[1:ntop]
		}
		toplot = names(vals$tjs) %in% toplot
		points(xes[toplot], droprate_obs[toplot], col="purple", pch=16)
	}
	if (is.null(ntop)) {
		return(out[qval < fdr])
	} else {
		return(out[1:ntop])
	}
}

PoissonUMIFeatureSelectionDropouts <- function(fit) {
	# Poisson distribution
	vals <- fit$vals
	#Exp_p <- exp(-fit$mus)
	#Exp_p_var <- Exp_p*(1-Exp_p)
	droprate_exp <- vector(length=vals$ng)
	droprate_exp_err <- vector(length=vals$ng)
	for (i in 1:vals$ng) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total
		p_is <- exp(-mu_is);
		p_var_is <- p_is*(1-p_is);
		droprate_exp[i] <- sum(p_is)/vals$nc;
		droprate_exp_err[i] <- sqrt(sum(p_var_is)/(vals$nc^2));
	}

	#droprate_exp <- rowSums(Exp_p)/vals$nc
	droprate_exp[droprate_exp < 1/vals$nc] <- 1/vals$nc # Is this necessary?
	#droprate_exp_err <- sqrt(rowSums(Exp_p_var)/(vals$nc^2))
	droprate_obs <- vals$djs/vals$nc
	droprate_obs_err <- sqrt(droprate_obs*(1-droprate_obs)/vals$nc)

	diff <- droprate_obs-droprate_exp
	combined_err <- droprate_exp_err
	Zed <- diff/combined_err
        pvalue <- pnorm(Zed, lower.tail = FALSE)
	names(pvalue) <- names(vals$tjs)
	return(sort(pvalue))
}

#PoissonUMIFeatureSelectionCV <- function(counts, fit) {
#	# Poisson distribution
#	vals <- fit$vals
#	g_means <- vals$tjs/vals$nc
#	CVexp <- 1/sqrt(g_means) # expected
#	CVobs <-  sqrt(apply(counts-fit$mus, 1, var))/g_means;
#
#	CVexp_log <- log(CVexp)
#	CVobs_log <- log(CVobs)
#	mean_log <- log(g_means)
#
#	res <- CVobs_log-CVexp_log;
#	res_sd <- sd(res);
#
#	# Variance of sample variance from http://mathworld.wolfram.com/SampleVarianceDistribution.html
#	# Kenney and Keeping 1951, p. 164; Rose and Smith 2002, p. 264
#	u4 <- g_means*(1+3*g_means) # central moment
#	u2 <- g_means
#	N <- vals$nc
#	V <- (N-1)^2/N^3*u4-(N-1)*(N-3)/N^3*u2^2
#
#	Zed <- (CVobs-CVexp)/sqrt(V)
#        pvalue <- pnorm(Zed, lower.tail = FALSE)
#	names(pvalue) <- names(vals$tjs)
#	return(sort(pvalue))
#}
#### Differential Expression #####

# HERE HERE HERE - editing for Matrix sparse-matrix compatibility #

bg__nbumiGroupDE <- function(counts, fit, groups) {
	# Global mean-variance, gene-specific variance & mean
	vals <- fit$vals;
	size_g <- fit$sizes
	group_specific_factor <- aggregate(t(counts), by=list(groups), sum)
	rownames(group_specific_factor) <- group_specific_factor[,1]
	group_specific_factor <- group_specific_factor[,-1]
	group_specific_factor <- t(group_specific_factor)
	group_specific_tjs <- group_specific_factor; 
	group_total <- colSums(group_specific_tjs)
	group_specific_factor <- t(t(group_specific_tjs)/group_total) / (vals$tjs/vals$total) # Relative expression level in group vs across whole dataset.
	group_specific_factor[vals$tjs == 0,] <- rep(1, length(group_specific_factor[1,]))

	coeffs <- NBumiFitDispVsMean(fit, suppress.plot=TRUE);

	pvals <- vector(length=vals$ng)
	for (j in 1:vals$ng) {
		prob_null <- 0;
		prob_test <- 0;
		for (i in 1:vals$nc) {
			group <- which(colnames(group_specific_factor) == groups[i])
			mu_ji <- vals$tjs[j]*vals$tis[i]/vals$total
			p1 <- dnbinom(counts[j,i], mu=mu_ji, size=size_g[j], log=TRUE)
			group_mu <- mu_ji*group_specific_factor[j,group]
			shifted_size <- hidden_shift_size(mu_ji,size_g[j],group_mu,coeffs);
			p2 <- dnbinom(counts[j,i], mu=group_mu, size=shifted_size, log=TRUE)
			# Collect ps across i
			prob_null <- prob_null+p1
			prob_test <- prob_test+p2
		}
		# Perform log-likehood test for this gene
		D <- -2*(prob_null-prob_test)
		df <- length(unique(groups))-1
		pval <- pchisq(D, df=df, lower.tail=FALSE)
		pvals[j] <- pval;
	}
	# Format output.
	output <- cbind(group_specific_factor, pvals, p.adjust(pvals, method="fdr"));
	rownames(output) <- rownames(counts);
	colnames(output) <- c(colnames(group_specific_factor), "p.value","q.value")
	return(output);
}


broken__nbumiCGroupDE <- function(counts, fit, groups) {
	# Seg faults!
	if (!is.factor(groups)) {
		groups <- factor(groups);
	}
	vals <- fit$vals;
	size_g <- fit$sizes
	nc = length(counts[1,]);
	ng = length(counts[,1]);
	group_specific_factor <- aggregate(t(counts), by=list(groups), sum)
	rownames(group_specific_factor) <- group_specific_factor[,1]
	group_specific_factor <- group_specific_factor[,-1]
	group_specific_factor <- t(group_specific_factor)
	group_specific_tjs <- group_specific_factor; 
	group_total <- colSums(group_specific_tjs)
	group_specific_factor <- t(t(group_specific_tjs)/group_total) / (vals$tjs/vals$total) # Relative expression level in group vs across whole dataset.
	group_specific_factor[vals$tjs == 0,] <- rep(1, length(group_specific_factor[1,]))

	coeffs <- NBumiFitDispVsMean(fit, suppress.plot=TRUE);
	pvals <- rep(-0.1, times=vals$ng);

	out <- .C("loglikehood_nbumi", as.integer(as.matrix(round(counts))), as.double(fit$mus), as.integer(groups), as.double(group_specific_factor), as.double(size_g), as.integer(nc), as.integer(ng), as.double(coeffs[2]), as.double(pvals));

	pvals = out[[5]];
	# Format output.
	output <- cbind(group_specific_factor, pvals, p.adjust(pvals, method="fdr"));
	rownames(output) <- rownames(counts);
	colnames(output) <- c(colnames(group_specific_factor), "p.value","q.value")
	return(output);
}

hidden_nbumiImputeZeros <- function(counts, fit) {
	vals <- fit$vals
	for (i in 1:nrow(counts)) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total
		low <- counts[i,] < mu_is
		counts[i,low] <- counts[i,low]+mu_is[low]
	}
	return(counts);
}

NBumiImputeNorm <- function(counts, fit, total_counts_per_cell=median(fit$vals$tis)) {
	# find p-value for current fit NB Umi
	# adjust parameters of the NB
	# determine value of equivalent p-value under new NB
	coeffs <- NBumiFitDispVsMean(fit, suppress.plot=TRUE);
	vals <- fit$vals;
	norm <- counts;
	normed_ti <- total_counts_per_cell;
	normed_mus <- vals$tjs/vals$total;
	# TODO modify so adjusts size to new mean expression level
	#normed_size <- fit$size;
	for (i in 1:nrow(counts)) {
		mu_is <- vals$tjs[i]*vals$tis/vals$total;
		p_orig <- pnbinom(counts[i,], mu=mu_is, size=fit$sizes[i]);
		new_size <- hidden_shift_size(mean(mu_is), fit$sizes[i], normed_mus[i]*normed_ti, coeffs)
		normed <- qnbinom(p_orig, mu=normed_mus[i]*normed_ti, size=new_size);
		norm[i,] <- normed;
	}
	return(norm);
}

## Cell-type DANB ##
# fit variances with contribution from global mean~var relationship for small clusters. 
