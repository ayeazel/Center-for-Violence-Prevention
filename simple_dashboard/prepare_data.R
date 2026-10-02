# prepare_data.R
# Turns the raw NIBRS 2025 master file (~6 GB) into two small tables for the
# dashboard. Run once, from the repository root:
#
#   Rscript simple_dashboard/prepare_data.R
#
# Output (simple_dashboard/processed/):
#   ipv_by_state_offense_2025.csv  intimate partner victimizations, by state and offense type
#   state_summary_2025.csv         one row per state: victimizations, coverage, rate
#   data_funnel_2025.csv           how many records each step kept (for the report)
#
# The raw file is fixed-width: every field sits at fixed character positions.
# Positions come from data/help/NIBRS Record Description.pdf.

library(dplyr)
library(readr)

raw_file <- "data/nibrs-2025.txt"
out_dir  <- "simple_dashboard/processed"
dir.create(out_dir, showWarnings = FALSE)

# ---- Definitions ------------------------------------------------------------

# Intimate partner = the victim was the offender's current or former partner.
ipv_codes <- c(SE = "Spouse", CS = "Common-law spouse", XS = "Ex-spouse",
               BG = "Boyfriend/girlfriend", XR = "Ex-boyfriend/girlfriend")

# Violent crimes against a person. Each victim is counted once, under their
# most serious offense (lowest `severity`).
offense_types <- tribble(
  ~code, ~offense_type,                    ~severity,
  "09A", "Murder",                          1,
  "11A", "Sex offense",                     2,
  "11B", "Sex offense",                     2,
  "11C", "Sex offense",                     2,
  "11D", "Sex offense",                     2,
  "100", "Kidnapping",                      3,
  "13A", "Aggravated assault",              4,
  "13B", "Simple assault",                  5,
  "13C", "Intimidation (incl. stalking)",   6
)

# Read only the lines that match a pattern, using grep, so R never has to hold
# the whole 6 GB file in memory.
read_matching_lines <- function(pattern) {
  readLines(pipe(sprintf("LC_ALL=C grep -E %s %s", shQuote(pattern), shQuote(raw_file))))
}
count_matching_lines <- function(pattern) {
  as.numeric(system(sprintf("LC_ALL=C grep -cE %s %s", shQuote(pattern), shQuote(raw_file)),
                    intern = TRUE))
}

# ---- Step 1: agencies -------------------------------------------------------
# "BH" (batch header) lines describe each law enforcement agency, including
# agencies that sent no data in 2025. This lets us measure reporting coverage.

bh <- read_matching_lines("^BH")
bh <- bh[substr(bh, 3, 4) != "98"]   # drop federal agencies: they have no state or population

agencies <- tibble(
  ori             = substr(bh, 5, 13),                  # agency ID
  state           = substr(bh, 72, 73),
  # Population served is spread over up to five county slots; add them up.
  population      = as.numeric(substr(bh, 106, 114)) + as.numeric(substr(bh, 130, 138)) +
                    as.numeric(substr(bh, 154, 162)) + as.numeric(substr(bh, 178, 186)) +
                    as.numeric(substr(bh, 202, 210)),
  months_reported = as.integer(substr(bh, 228, 229))
) |>
  mutate(state = recode(state, NB = "NE")) |>          # the FBI file uses NB for Nebraska
  filter(state %in% c(state.abb, "DC"))                  # 50 states + DC (drops territories)

# ---- Step 2: victims of intimate partner violence ---------------------------
# "04" lines are victim records. grep keeps a line only if:
#   - it is a victim record (starts with 04),
#   - the victim is an individual person (character 67 is "I"), and
#   - at least one of the up-to-10 victim-offender relationships (4-character
#     pairs starting at character 84) has an intimate partner code.

ipv_pattern <- sprintf("^04.{64}I.{16}(.{4}){0,9}..(%s)", paste(names(ipv_codes), collapse = "|"))
v <- read_matching_lines(ipv_pattern)

victims <- tibble(
  ori           = substr(v, 5, 13),
  offenses      = substr(v, 37, 66),     # up to 10 offense codes, 3 characters each
  relationships = substr(v, 84, 123)     # up to 10 relationship pairs, 4 characters each
)
rm(v)

# Re-check the grep filter in R: some relationship pair has an IPV code.
rel_codes <- sapply(0:9, \(k) substr(victims$relationships, 4 * k + 3, 4 * k + 4))
stopifnot(all(rowSums(matrix(rel_codes %in% names(ipv_codes), ncol = 10)) > 0))

# Most serious in-scope offense for each victim.
offense_codes <- sapply(0:9, \(k) substr(victims$offenses, 3 * k + 1, 3 * k + 3))
severity <- matrix(offense_types$severity[match(offense_codes, offense_types$code)], ncol = 10)
victims$severity <- suppressWarnings(apply(severity, 1, min, na.rm = TRUE))  # Inf = none in scope

ipv <- victims |>
  filter(is.finite(severity)) |>
  left_join(distinct(offense_types, severity, offense_type), by = "severity") |>
  inner_join(agencies, by = "ori")

# Only agencies that reported all 12 months: a partial year would undercount.
ipv_full_year <- filter(ipv, months_reported == 12)

# ---- Step 3: summarise by state ---------------------------------------------

by_state_offense <- ipv_full_year |>
  count(state, offense_type, name = "victims")

coverage <- agencies |>
  group_by(state) |>
  summarise(population_total   = sum(population),
            population_covered = sum(population[months_reported == 12]),
            agencies_total     = n(),
            agencies_reporting = sum(months_reported == 12)) |>
  mutate(pct_covered = population_covered / population_total)

state_summary <- coverage |>
  left_join(count(ipv_full_year, state, name = "ipv_victims"), by = "state") |>
  mutate(ipv_victims = coalesce(ipv_victims, 0L),
         rate_per_100k = 1e5 * ipv_victims / population_covered,
         state_name = c(state.name, "District of Columbia")[match(state, c(state.abb, "DC"))]) |>
  relocate(state, state_name, ipv_victims, rate_per_100k)

# ---- Step 4: record what each step kept -------------------------------------

funnel <- tibble(
  step = c("Victim records in the 2025 file",
           "Victims who are individual people",
           "...with an intimate partner relationship to an offender",
           "...and a violent crime against the person",
           "...in one of the 50 states or DC",
           "...reported by an agency with all 12 months of data"),
  records = c(count_matching_lines("^04"),
              count_matching_lines("^04.{64}I"),
              nrow(victims),
              sum(is.finite(victims$severity)),
              nrow(ipv),
              nrow(ipv_full_year))
)

write_csv(by_state_offense, file.path(out_dir, "ipv_by_state_offense_2025.csv"))
write_csv(state_summary,    file.path(out_dir, "state_summary_2025.csv"))
write_csv(funnel,           file.path(out_dir, "data_funnel_2025.csv"))
print(funnel)
