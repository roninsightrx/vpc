% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_vpc.R
\name{plot_vpc}
\alias{plot_vpc}
\title{VPC plotting function}
\usage{
plot_vpc(
  db,
  show = NULL,
  vpc_theme = NULL,
  smooth = TRUE,
  log_x = FALSE,
  log_y = FALSE,
  xlab = NULL,
  ylab = NULL,
  title = NULL,
  verbose = FALSE
)
}
\arguments{
\item{db}{object created using the `vpc` function}

\item{show}{what to show in VPC (obs_dv, obs_ci, pi, pi_as_area, pi_ci, obs_median, sim_median, sim_median_ci)}

\item{vpc_theme}{theme to be used in VPC. Expects list of class vpc_theme created with function vpc_theme()}

\item{smooth}{"smooth" the VPC (connect bin midpoints) or show bins as rectangular boxes. Default is TRUE.}

\item{log_x}{Boolean indicting whether x-axis should be shown as logarithmic. Default is FALSE.}

\item{log_y}{Boolean indicting whether y-axis should be shown as logarithmic. Default is FALSE.}

\item{xlab}{label for x axis}

\item{ylab}{label for y axis}

\item{title}{title}

\item{verbose}{show debugging information (TRUE or FALSE)}
}
\description{
This function performs no parsing of data, it just plots the already calculated statistics generated using one of the
`vpc` functions.
}
\examples{
## See vpc.ronkeizer.com for more documentation and examples

library(vpc)
vpc_db <- vpc(sim = simple_data$sim, obs = simple_data$obs, vpcdb = TRUE)
plot_vpc(vpc_db, title = "My new vpc", x = "Custom x label")
}
\seealso{
\link{vpc_cens}, \link{vpc_tte}, \link{vpc_cat}
}
