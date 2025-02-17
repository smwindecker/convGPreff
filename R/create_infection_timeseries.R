create_infection_timeseries <- function(n_jurisdictions,
                                        n_days_infection,
                                        effect_type = "growth_rate") {

    # kernel hyperparams
    gp_lengthscale <- greta::lognormal(0, 1) #inverse_gamma(187/9,1157/18)
    gp_variance <- greta::normal(0, 4, truncation = c(0, Inf))
    gp_kernel <- greta.gp::mat52(gp_lengthscale, gp_variance)

    #define gp
    gp <- greta.gp::gp(
        x = seq_len(n_days_infection),
        kernel = gp_kernel,
        n = n_jurisdictions,
        tol = 1e-4
    )

    #compute infections from gp
    infections_timeseries <- compute_infections(
        log_effect = gp,
        effect_type = effect_type
    )

    greta_arrays <- module(
        gp,
        infections_timeseries,
        gp_lengthscale,
        gp_variance,
        gp_kernel
    )

    return(greta_arrays)
}

#' WIP function to compute the # of infections per day, given a log-scaled initial # of infections
#' and a time-varying random effect controlling the trend of infections over time. The random effect
#' is defined as a Gaussian Process (GP), and can be applied to the infection # through three
#' different formulations. (see vignette for details here or something). Note that this random
#' effect over time is not explicitly specified as an epidemiologically defined quantity like the
#' growth rate or the reproduction number. Rather, these quantities are to be calculated from
#' posterior samples. The function uses an uninformative prior for the initial # of infections ---
#' currently there are no plans to make this an input param.
#'
#' @param log_effect
#' @param effect_type
#'
#' @return
#' @export
#'
#' @examples
compute_infections <- function(
        log_effect,
        effect_type = c("infections", "growth_rate", "growth_rate_derivative"))
{

    effect_type <- match.arg(effect_type)

    #prior for initial # of infections on log scale
    inits <- lognormal(0, 1, dim = ncol(log_effect))

    #specify the formula for infections
    if (effect_type == "infections") {
        f <- function(inits, z) exp(sweep(z, 2, inits, FUN = "+"))
        N <- f(inits, log_effect)
    }

    if (effect_type == "growth_rate") {
        f <- function(inits, z) {
            log_rt <- z
            exp(sweep(greta::apply(log_rt, 2, "cumsum"), 2, inits, FUN = "+"))
        }
        N <- f(inits, log_effect)
    }

    if (effect_type == "growth_rate_derivative") {
        f <- function(inits, z) {
            log_rt_diff <- z
            log_rt <- greta::apply(log_rt_diff, 2, "cumsum")
            exp(sweep(greta::apply(log_rt, 2, "cumsum"), 2, inits, FUN = "+"))
        }
        N <- f(inits, log_effect)
    }

    return(N)
}

