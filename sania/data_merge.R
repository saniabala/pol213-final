# merge data along country and year

required_packages <- c("tidyverse", "WDI", "countrycode")
missing_packages <- required_packages[!required_packages %in% installed.packages()[, "Package"]]
if (length(missing_packages) > 0) install.packages(missing_packages, repos = "https://cloud.r-project.org")

library(tidyverse)
library(WDI)
library(countrycode)

# load VDEM data 
vdem <- read_csv("VDEM.csv")

# load OECD DAC2A data
oecd_raw <- read_csv("OECD DAC2A.csv")

# standardize OECD country names to match VDEM
oecd_clean <- oecd_raw %>%
  mutate(Recipient = recode(Recipient,
    "Myanmar"                                        = "Burma/Myanmar",
    "Cabo Verde"                                     = "Cape Verde",
    "China (People's Republic of)"                   = "China",
    "Côte d'Ivoire"                                  = "Ivory Coast",
    "Lao People's Democratic Republic"               = "Laos",
    "Democratic People's Republic of Korea"          = "North Korea",
    "Palestinian Authority or West Bank and Gaza Strip" = "Palestine/West Bank",
    "Congo"                                          = "Republic of the Congo",
    "Syrian Arab Republic"                           = "Syria",
    "Gambia"                                         = "The Gambia",
    "Viet Nam"                                       = "Vietnam"
  ))

# aggregate OECD to total ODA received per recipient country per year
oecd <- oecd_clean %>%
  group_by(Recipient, TIME_PERIOD) %>%
  summarise(total_oda_usd_millions = sum(OBS_VALUE, na.rm = TRUE), .groups = "drop") %>%
  rename(country_name = Recipient, year = TIME_PERIOD)

# merge on country_name and year
merged <- vdem %>%
  left_join(oecd, by = c("country_name", "year"))

# --- compute democratic backsliding variable ---
# delta_polyarchy = v2x_polyarchy(t) - v2x_polyarchy(t-1), grouped by country
# a negative value means the country became less democratic that year (backsliding)
# a positive value means it became more democratic (democratization)
# computed here on the full dataset before subsetting so that 2010 observations
# can draw their lag from 2009 — if we filtered to 2010-2020 first, all 2010
# lags would be NA

merged <- merged %>%
  arrange(country_name, year) %>%
  group_by(country_name) %>%
  mutate(delta_polyarchy = v2x_polyarchy - lag(v2x_polyarchy)) %>%
  ungroup()

# --- subset to analysis variables and 2010-2020 ---

analysis <- merged %>%
  filter(year >= 2010, year <= 2020) %>%
  select(
    country_name,
    year,
    total_oda_usd_millions,
    v2x_polyarchy,    # democracy level — kept as a control to isolate the effect
                      # of change from the effect of overall democratic standing
    delta_polyarchy,  # year-over-year change in democracy — the key predictor
                      # for the backsliding hypothesis
    v2x_corr,         # political corruption index
    v2x_rule,         # rule of law index
    v2xcl_rol         # civil liberties / equality before the law
  )

# --- pull GDP per capita and population from World Bank (2010-2020) ---

wdi_raw <- WDI(
  indicator = c(gdp_per_capita = "NY.GDP.PCAP.KD",
                population     = "SP.POP.TOTL"),
  start = 2010, end = 2020,
  extra = FALSE
)

# convert WDI ISO2 codes to country names matching VDEM via countrycode
wdi <- wdi_raw %>%
  mutate(country_name = countrycode(iso2c, origin = "iso2c",
                                    destination = "country.name")) %>%
  filter(!is.na(country_name)) %>%
  select(country_name, year, gdp_per_capita, population)

analysis <- analysis %>%
  left_join(wdi, by = c("country_name", "year"))

# --- convert ODA to integer count (round to nearest million; floor negatives to 0) ---

analysis <- analysis %>%
  mutate(oda_count = pmax(0, round(total_oda_usd_millions))) %>%
  select(-total_oda_usd_millions)

# --- drop rows missing outcome or key predictor ---

analysis <- analysis %>%
  filter(!is.na(oda_count), !is.na(v2x_polyarchy))

# --- save analysis-ready merged dataset ---

write_csv(analysis, "sania/analysis_merged.csv")

# --- save cleaned and aggregated OECD dataset ---

write_csv(oecd, "sania/oecd_clean.csv")

# --- Poisson model ---
# log(population) included as offset so the outcome scales with country size

poisson_model <- glm(
  oda_count ~ v2x_polyarchy + v2x_corr + v2x_rule + v2xcl_rol +
              log(gdp_per_capita) + offset(log(population)),
  data   = analysis,
  family = poisson(link = "log")
)

summary(poisson_model)

# Results (Poisson):
# n = 1,217 country-years (2010-2020), 119 dropped due to missingness
# All coefficients are statistically significant (z-values 600-1900) but this is
# a red flag, not a good sign. Residual deviance = 36,501,834 on 1,211 df,
# far exceeding what Poisson assumes (deviance ≈ df). This indicates severe
# overdispersion — the variance in ODA is much larger than the mean, violating
# the Poisson assumption. Switched to negative binomial to address this.

# --- Model strategy ---
# Two NB models are run and can be presented side by side (Model 1 / Model 2):
#
# Model 1 (nb_model): tests whether democracy LEVELS predict aid allocation.
#   This is a well-established finding in the aid literature and serves as a
#   baseline — it confirms the model is working as expected before introducing
#   the backsliding variable.
#
# Model 2 (nb_backsliding): tests whether CHANGES in democracy (backsliding)
#   predict aid — the core hypothesis of this paper. Keeping both models allows
#   you to show that while donors respond to a country's overall democratic
#   standing, they do not appear to react quickly to year-to-year backsliding.
#   That contrast is itself a substantive finding worth discussing.

# --- Negative binomial model (accounts for overdispersion) ---

library(MASS)

nb_model <- glm.nb(
  oda_count ~ v2x_polyarchy + v2x_corr + v2x_rule + v2xcl_rol +
              log(gdp_per_capita) + offset(log(population)),
  data = analysis
)

summary(nb_model)

# Results (Negative Binomial):
# n = 1,217 country-years (2010-2020), 119 dropped due to missingness
# Theta = 0.917 (SE = 0.033) — estimated dispersion parameter, confirms
# overdispersion was present and NB is the appropriate model.
# Residual deviance = 1,425 on 1,211 df, much closer to expected, indicating
# a good fit. AIC = 26,448 (vs. 36,515,302 for Poisson).
#
# Coefficients:
#   v2x_polyarchy:    -0.991 (p < .001) — more democratic countries receive less
#                     ODA; consistent with aid being directed toward less democratic,
#                     higher-need recipients
#   v2x_corr:         -0.199 (p = .518) — corruption not significant once other
#                     governance variables are controlled for
#   v2x_rule:          1.410 (p < .001) — better rule of law associated with more
#                     ODA; donors appear to reward governance quality
#   v2xcl_rol:         0.560 (p = .030) — stronger civil liberties / equality
#                     before the law associated with more ODA
#   log(gdp_per_capita): -0.322 (p < .001) — richer countries receive less ODA,
#                     consistent with need-based aid allocation

# --- Backsliding model (negative binomial) ---
# Research question: does democratic backsliding cause countries to receive less aid?
# Key predictor: delta_polyarchy (year-over-year change in v2x_polyarchy)
#   — negative values = backsliding, positive values = democratization
# v2x_polyarchy is kept as a level control so delta_polyarchy captures the effect
# of change net of where the country already sits on the democracy scale
# Expected sign on delta_polyarchy: positive — backsliding (negative delta) should
# predict less ODA, democratization (positive delta) should predict more ODA

nb_backsliding <- glm.nb(
  oda_count ~ delta_polyarchy + v2x_polyarchy + v2x_corr + v2x_rule + v2xcl_rol +
              log(gdp_per_capita) + offset(log(population)),
  data = analysis
)

summary(nb_backsliding)

# Results (Backsliding NB model):
# n = 1,216 country-years (2010-2020), 120 dropped due to missingness
# (one extra observation lost vs. prior models due to lag computation)
# Theta = 0.916 (SE = 0.033) — very similar to the prior NB model, confirming
# overdispersion is still present and NB remains appropriate.
# Residual deviance = 1,424 on 1,209 df. AIC = 26,429 (slightly better than
# the prior NB model at 26,448, suggesting delta_polyarchy adds marginal fit).
#
# Coefficients:
#   delta_polyarchy:  0.466 (p = .537) — NOT significant. The direction is
#                     positive as hypothesized (democratization predicts more ODA,
#                     backsliding predicts less), but the effect is not
#                     distinguishable from zero. This means we cannot conclude
#                     from this model that backsliding causes aid reductions.
#   v2x_polyarchy:   -1.001 (p < .001) — democracy level remains strongly
#                     negative and significant; donors give less aid to more
#                     democratic countries (need-based allocation)
#   v2x_corr:        -0.197 (p = .522) — still not significant
#   v2x_rule:         1.402 (p < .001) — rule of law still positive and significant
#   v2xcl_rol:        0.567 (p = .028) — civil liberties still positive and significant
#   log(gdp_per_capita): -0.321 (p < .001) — richer countries still receive less ODA
#
# Interpretation: the backsliding hypothesis is not supported in this specification.
# The level of democracy is a strong predictor of ODA, but year-to-year changes
# do not appear to drive aid decisions. This could reflect donor inertia (aid
# allocations are slow to respond to political changes), or that the effect only
# emerges over longer time horizons. Adding fixed effects or a longer lag
# structure (2-3 years) may surface a delayed donor response.

# =============================================================================
# ROBUSTNESS CHECKS
# =============================================================================

# --- Robustness check 1: Alternative democracy measures ---
# Why: v2x_polyarchy measures electoral democracy specifically. If the backsliding
# finding (or null result) is real, it should hold across different conceptualizations
# of democracy. We test two alternatives:
#   v2x_libdem    — liberal democracy index (adds judicial constraints and civil
#                   liberties on top of electoral democracy)
#   v2x_partipdem — participatory democracy index (emphasizes direct participation
#                   and civil society engagement)
# If delta_polyarchy is insignificant but delta_libdem or delta_partipdem is
# significant, that would suggest donors respond to a specific dimension of
# democratic change rather than electoral democracy per se.

# compute deltas for alternative measures from full merged dataset (pre-filter)
# so that 2010 observations have valid lags from 2009
analysis_robust <- merged %>%
  arrange(country_name, year) %>%
  group_by(country_name) %>%
  mutate(
    delta_libdem    = v2x_libdem - lag(v2x_libdem),
    delta_partipdem = v2x_partipdem - lag(v2x_partipdem)
  ) %>%
  ungroup() %>%
  filter(year >= 2010, year <= 2020) %>%
  dplyr::select(country_name, year, v2x_libdem, v2x_partipdem,
                delta_libdem, delta_partipdem) %>%
  left_join(analysis, by = c("country_name", "year"))

# liberal democracy backsliding model
nb_libdem <- glm.nb(
  oda_count ~ delta_libdem + v2x_libdem + v2x_corr + v2x_rule + v2xcl_rol +
              log(gdp_per_capita) + offset(log(population)),
  data = analysis_robust
)

summary(nb_libdem)

# participatory democracy backsliding model
nb_partipdem <- glm.nb(
  oda_count ~ delta_partipdem + v2x_partipdem + v2x_corr + v2x_rule + v2xcl_rol +
              log(gdp_per_capita) + offset(log(population)),
  data = analysis_robust
)

summary(nb_partipdem)

# Results (Alternative measures):
# Both models tell the same story as the main backsliding model — the null
# result on the delta variable is consistent across all three democracy indices.
#
# Liberal democracy (nb_libdem):
#   delta_libdem:   0.185 (p = .840) — not significant; backsliding in liberal
#                   democracy does not predict aid changes
#   v2x_libdem:    -1.290 (p < .001) — level effect remains strongly negative,
#                   consistent with the main model
#   AIC = 26,429 — identical fit to the main backsliding model
#
# Participatory democracy (nb_partipdem):
#   delta_partipdem: 1.326 (p = .266) — not significant; direction is positive
#                    as expected but effect is not distinguishable from zero
#   v2x_partipdem:  -2.616 (p < .001) — level effect strongly negative and
#                    larger in magnitude than the other indices, suggesting donors
#                    may be especially sensitive to low participatory democracy
#   AIC = 26,399 — marginally better fit than the other models
#
# Overall: the null result on backsliding is robust across all three
# conceptualizations of democracy (electoral, liberal, participatory). This
# consistently points to donor inertia — aid allocations respond to where a
# country sits on the democracy scale, not to how fast it is moving.

# --- Robustness check 2: Extended time window ---
# Why: a longer panel would provide more backsliding episodes and more statistical
# power to detect a donor response. However, the OECD DAC2A data in this project
# only covers 2010-2020, making it impossible to extend the window further back
# without obtaining additional OECD data. This check should be revisited if the
# full OECD time series (available from stats.oecd.org going back to the 1960s)
# is downloaded and added to the project.
#
#
# =============================================================================
# --- Potential model improvements (in priority order) ---
# =============================================================================
#
# 1. LAG THE PREDICTORS
#    Currently democracy scores and ODA are measured in the same year, which
#    raises reverse causality: does democracy predict aid, or does aid promote
#    democracy? Lagging v2x_polyarchy and all controls by one year (t-1) makes
#    the causal direction cleaner — last year's democracy score predicts this
#    year's aid. Can be done with dplyr::lag() grouped by country.
#
# 2. COUNTRY + YEAR FIXED EFFECTS
#    Panel data (same countries over 11 years) means unobserved country-level
#    factors (colonial history, geographic proximity to donors, bilateral
#    relationships) could confound estimates. Country fixed effects absorb all
#    time-invariant country characteristics. Year fixed effects absorb global
#    shocks affecting all countries simultaneously. Add with factor(country_name)
#    and factor(year) as predictors, or use the fixest package for efficiency.
#
# 3. CHECK FOR ZERO INFLATION
#    If many country-years have zero ODA, a standard NB model may underfit those
#    zeros. A zero-inflated negative binomial (ZINB) models zeros separately —
#    useful if zeros arise from two processes (e.g., country never receives aid
#    vs. country received no aid that particular year). Check with:
#    table(analysis$oda_count == 0) before deciding.
