#########################################
#####  tfus-comp power analysis pc  #####
#########################################

#########################################

library(Superpower)

'
https://cran.r-project.org/web/packages/Superpower/vignettes/intro_to_superpower.html#simulation-based-power-calculations
https://aaroncaldwell.us/SuperpowerBook/repeated-measures-anova.html
'

#########################################

mus <- c(41.41, 41.41, 41.41, 41.41, 36.44, 36.44, 41.41, 36.44, 36.44) # predicted cell means based on minimally interesting change in outcome
sd <- 3.67 # rough estimate of population standard deviation taken from the pilot data 
r <- 0.30 # rough estimate of correlation of repeated measures from pilot data 

#########################################

### plot_power ###
design <- ANOVA_design(design = '3w*3w', n = 24, mu = mus, sd = sd, r = r, 
                       label_list = list('target' = c('sha', 'gpe', 'tha'), 
                                         'block' = c('pre', 'pos', 'del')),
                       plot = TRUE)

design_power_sims <- plot_power(design, min_n = 12, max_n = 60, desired_power = 95, plot = TRUE)
design_power_sims_df <- design_power_sims$power_df
print(design_power_sims_df)
#write.csv(design_power_sims_df, "/Users/amber/Documents/PhD/Research/Projects/LIFUP-PCI/Analysis/Power/lz_power_simulations_df.csv", row.names = FALSE)

power_exact <- ANOVA_exact(design, alpha_level = 0.025, verbose = FALSE)
print(power_exact)

#########################################

# set up design for detailed sims #
ns <- seq(6, 60, 1)
nsims <- 5000

# create empty dataframe #
power_simulations_df <- data.frame(matrix(nrow = 0, ncol = 6))
colnames(power_simulations_df) <- c('n', 'factor', 'power', 'lower.ci', 'upper.ci', 'effect_size')

# loop over difference sample sizes and run power simulation #
for(i in ns){
  
  # design and power simulation #
  design <- ANOVA_design(design = '3w*3w', n = i, mu = mus, sd = sd, r = r, 
                         label_list = list('target' = c('sha', 'gpe', 'tha'), 
                                           'block' = c('pre', 'pos', 'del')),
                         plot = FALSE)
  
  power_simulation_thisn <- ANOVA_power(design, alpha = 0.025, nsims = nsims, seed = 1504, verbose = FALSE, emm_model = 'multivariate')
  
  # add result to df #
  rows <- list(n = c(i, i, i), factor = c('target', 'block', 'targetXblock'), power = c(power_simulation_thisn$main_result$power[1], power_simulation_thisn$main_result$power[2], power_simulation_thisn$main_result$power[3]), lower.ci = c(confint(power_simulation_thisn)$lower.ci[1], confint(power_simulation_thisn)$lower.ci[2], confint(power_simulation_thisn)$lower.ci[3]), upper.ci = c(confint(power_simulation_thisn)$upper.ci[1], confint(power_simulation_thisn)$upper.ci[2], confint(power_simulation_thisn)$upper.ci[3]), effect_size = c(power_simulation_thisn$main_result$effect_size[1], power_simulation_thisn$main_result$effect_size[2], power_simulation_thisn$main_result$effect_size[3]))
  power_simulations_df <- rbind(power_simulations_df, rows)
  
}

print(power_simulations_df)
write.csv(power_simulations_df, "/Users/amber/Documents/PhD/Research/Projects/LIFUP-PCI/Analysis/Power/pci_power_simulations_df.csv", row.names = FALSE)

