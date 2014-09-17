#' VPC function for survival-type data 
#' 
#' Creates a VPC plot and/or plotting data from observed and simulation data
#' @param sim 
#' @param obs
#' @return A VPC object 
#' @export
#' @examples
#' ## Example for repeated) time-to-event data
#' ## with NONMEM-like data (e.g. simulated using a dense grid)
#' data(rtte_obs_nm) 
#' data(rtte_sim_nm) 
#' 
#' # treat RTTE as TTE, no stratification
#' vpc_tte(rtte_sim_nm, rtte_obs_nm, 
#'         rtte = FALSE, bin_method="obs",
#'         sim_dv = "dv", obs_idv = "t", sim_idv = "t", n_sim = 100)
#' 
#' # stratified for covariate and study arm
#' vpc_tte(rtte_sim_nm, rtte_obs_nm, 
#'         stratify = c("sex","drug"), 
#'         rtte = FALSE, bin_method = "spread", n_bins=16,
#'         sim_dv = "dv", obs_idv = "t", sim_idv = "t", n_sim = 100)
#' 
#' # stratified per event number (we'll only look at first 3 events) and stratify per arm
#' vpc_tte(rtte_sim_nm, rtte_obs_nm,
#'         rtte = TRUE, occasions = c(1:3),
#'         stratify = c("drug"), bin_method="obs", 
#'         sim_dv = "dv", obs_idv = "t", sim_idv = "t", n_sim = 100)
vpc_tte <- function(sim, 
                    obs, 
                    rtte = FALSE,
                    rtte_flag = "rtte",
                    occasions = NULL,
                    bin_method = "obs",
                    filter_rtte = "rtte",
                    n_bins = 32,
                    n_sim = "auto",
                    sim_dense_grid = FALSE,
                    auto_bin_type = "simple",
                    obs_dv = "dv",
                    sim_dv =  "sdv",
                    obs_idv = "time",
                    sim_idv = "time",
                    obs_id = "id",
                    sim_id = "id",
                    pi_med = FALSE, 
                    nonmem = FALSE,
                    stratify = NULL,
                    ci = c(0.05, 0.95),
                    plot = TRUE,
                    xlab = NULL, 
                    ylab = NULL,
                    title = NULL,
                    smooth = FALSE,
                    theme = "default",
                    custom_theme = NULL,
                    facet = "wrap") {
  if(nonmem) { # set options common to NONMEM
    colnames(obs) <- tolower(colnames(obs))
    colnames(sim) <- tolower(colnames(sim))
    sim_dense_grid <- TRUE
    filter_rtte <- "rtte"
    sim.dv <- "dv"
  }
  if (!is.null(rtte_flag) & rtte_flag %in% names(sim)) {
    sim$rtte_flag <- sim[[rtte_flag]]
    sim <- sim %>% filter(rtte_flag == 1)
  }
  
  if(!is.null(stratify)) {
    if(rtte) {
      if (length(stratify) > 1) {
        cat ("Sorry, with repeated time-to-event data, stratification on more than 1 variables is currently not supported!")
        return()
      }
    } else {
      if (length(stratify) > 2) {
        cat ("Sorry, stratification on more than 2 variables is currently not supported!")
        return()
      }
    }    
  }

  # format obs data
  obs$time <- obs[[obs_idv]]
  obs <- relative_times(obs)
  if (rtte) {
    obs <- relative_times(obs)    
    obs <- obs %>% group_by(id) %>% mutate(rtte = cumsum(dv != 0)) 
    stratify <- c(stratify, "rtte")
  } else {
    obs$rtte <- 1
  }
  
  # add stratification column and comput KM curve for observations
  obs <- add_stratification(obs, stratify)
  obs_km <- compute_kaplan(obs, strat = "strat")
    
  # format sim data and compute KM curve CI for simulations
  # first get the number of simulations (req'd if sim# is not specified)
  sim$time <- sim[[sim_idv]]
  sim_id <- unique(sim$id)
  sim$id_shift <- c(sim$id[2:length(sim$id)], 0) 
  idx <- c(1, (1:length(sim$id))[sim$id == tail(sim_id,1) & sim$id_shift == sim_id[1]], length(sim$id)+1)
  sim$sim <- 0
  for (i in 1:(length(idx)-1)) {
    sim$sim[idx[i] : (idx[i+1]-1)] <- i 
  }
  
  all <- c()
  obs_strat <- as.character(unique(obs$strat))
  bins <- list() 
  for (i in seq(obs_strat)) {
      bins[[obs_strat[i]]] <- sort(unique(obs[as.character(obs$strat) == obs_strat[i],]$time))
  }
  for (i in 1:n_sim) {
    tmp <- sim %>%
      filter(sim == i) %>%
        convert_from_dense_grid(.)   ## convert the simulation dataset to hold only the observations, not the whole grid
    if (rtte) {
      tmp <- tmp %>% group_by(id) %>% mutate(rtte = cumsum(dv != 0))       
    }
    tmp2 <- add_stratification(tmp %>% arrange(id, time), stratify)
#    bins <- unique(obs$time)    
#    bins <- bins[order(bins)]
    tmp3 <- compute_kaplan(tmp2, strat = "strat")
    tmp3[,c("bin", "bin_min", "bin_max", "bin_mid")] <- 0 
    for (j in seq(obs_strat)) {
      tmp3_spl <- tmp3[tmp3$strat == obs_strat[j],]
      if (length(tmp3_spl[,1]) > 0) {
        tmp_bins <- unique(c(0, bins[[obs_strat[j]]], max(tmp3_spl$time)))
        tmp3[tmp3$strat == obs_strat[j],] <- within(tmp3_spl, {
          bin <- cut(time, breaks = tmp_bins, labels = FALSE, right = TRUE)
          bin_min <- tmp_bins[bin] 
          bin_max <- tmp_bins[bin+1] 
          bin_mid <- (bin_min + bin_max) / 2
        })        
      }
    }
    all <- rbind(all, cbind(i, tmp3))
  }
   
#   if (bin_method == "obs") {
#     bins <- unique(obs$time)    
#     bins <- bins[order(bins)]
#   } else {
#     bins <- seq(from = 0, max(all$time)*1.04, by = diff(range(all$time))/(n_bins))
#   }  
#   all$bin <- cut(all$time, breaks = bins, labels = FALSE, right = TRUE)
#   all$bin_min <- bins[all$bin] 
#   all$bin_max <- bins[all$bin+1] 
#   all$bin_mid <- (all$bin_min + all$bin_max)/2 
  
  sim_km <- all %>% 
    group_by (bin, strat) %>% 
    summarise (bin_mid = head(bin_mid,1), bin_min = head(bin_min,1), bin_max = head(bin_max,1), 
               qmin = quantile(surv, 0.05), qmax = quantile(surv, 0.95), qmed = median(surv),
               step = 0)
  if (rtte) {
    sim_km$rtte <- as.num(gsub(".*rtte=(\\d.*).*", "\\1", sim_km$strat, perl = TRUE))
    obs_km$rtte <- as.num(gsub(".*rtte=(\\d.*).*", "\\1", obs_km$strat, perl = TRUE))
    if (!is.null(occasions)) {
      sim_km <- sim_km %>% filter(rtte %in% occasions)
      obs_km <- obs_km %>% filter(rtte %in% occasions)
      # redefine strat factors, since otherwise empty panels will be shown
      sim_km$strat <- factor(sim_km$strat, levels = unique(sim_km$strat))
      obs_km$strat <- factor(obs_km$strat, levels = unique(obs_km$strat))
    }    
  }
  
  if (smooth) {
    geom_line_custom <- geom_line
  } else {
    geom_line_custom <- geom_step
  }
  if (!is.null(stratify)) {
    if (length(stratify) > 1) {
      sim_km$strat1 <- unlist(strsplit(as.character(sim_km$strat), ", "))[(1:length(sim_km$strat)*2)-1]
      sim_km$strat2 <- unlist(strsplit(as.character(sim_km$strat), ", "))[(1:length(sim_km$strat)*2)]
      obs_km$strat1 <- unlist(strsplit(as.character(obs_km$strat), ", "))[(1:length(obs_km$strat)*2)-1]
      obs_km$strat2 <- unlist(strsplit(as.character(obs_km$strat), ", "))[(1:length(obs_km$strat)*2)]   
    }
  }  
  pl <- ggplot(sim_km, aes(x=bin_mid, y=qmed)) 
  if (smooth) {
    pl <- pl + geom_ribbon(aes(min = qmin, max=qmax, y=qmed), fill = themes[[theme]]$med_area, alpha=0.5)
  } else {
    pl <- pl + geom_rect(aes(xmin=bin_min, xmax=bin_max, ymin=qmin, ymax=qmax), alpha=themes[[theme]]$med_area_alpha, fill = themes[[theme]]$med_area)   
  }
  if (pi_med) {
    pl <- pl + geom_line_custom(linetype="dashed")
  }
  show_obs <- TRUE
  if (show_obs) {
    chk_tbl <- obs_km %>% group_by(strat) %>% summarise(t = length(time))
    if (sum(chk_tbl$t <= 1)>0) { # it is not safe to use geom_step, so use 
      pl <- pl + geom_line(data = obs_km, aes(x=time, y=surv))
      cat ("Warning, some strata in the observed data had zero or one observations, using line instead of step plot. Consider using less strata (e.g. using the 'rtte_show_occasions' argument).")
    } else {
      pl <- pl + geom_step(data = obs_km, aes(x=time, y=surv))     
    }    
  }
  if (!is.null(stratify)) {
    if (length(stratify) == 1) {
      if(facet == "wrap") {
        pl <- pl + facet_wrap(~ strat)      
      } else {
        if(length(grep("row", facet))>0) {
          pl <- pl + facet_grid(strat ~ .)                
        } else {
          pl <- pl + facet_grid(. ~ strat)                
        }
      }      
    } else {
      if ("strat1" %in% colnames(sim_km)) {
        if(length(grep("row", facet))>0) {
          pl <- pl + facet_grid(strat1 ~ strat2)                
        } else {
          pl <- pl + facet_grid(strat2 ~ strat1)                
        }        
      } else {
        cat ("Stratification unsuccesful.")
        return(list(obs = obs_km, sim = sim_km, pl = pl))
      }
    }
  }
  if (!is.null(title)) {
    pl <- pl + ggtitle(title)  
  }
  if (!is.null(custom_theme)) {  
    pl <- pl + custom_theme()    
  } else {
    if (!is.null(theme)) {
      pl <- pl + theme_plain()
    } 
  }
  if(!is.null(xlab)) {
    pl <- pl + xlab(xlab)
  } else {
    pl <- pl + xlab("Time")
  }
  if(!is.null(ylab)) {
    pl <- pl + ylab(ylab)
  } else {
    pl <- pl + ylab("Survival (%)")
  }
  if(plot) {
    print(pl)
  }
  return(
    list(
      obs = obs_km, 
      sim = sim_km,
      bins = bins, 
      pl = pl
    )
  )
}