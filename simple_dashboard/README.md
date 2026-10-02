# Intimate partner violence by state: a first Shiny dashboard

This is a small, deliberately focused dashboard. It shows how many incidents of intimate partner violence (IPV) police agencies in each state reported to the FBI in 2025, and how far each state's numbers can be trusted.

![Dashboard screenshot](screenshot.jpg)

**Intended audience.** Staff and partners of the Center for Violence Prevention who want a quick, honest picture of reported IPV by state. They aren't crime-data specialists. The language stays plain, the dashboard shows only a few things, and every number comes with a note on how complete it is.

## How to run it

From the repository root, in R:

```r
# Step 1 (once, about 5 minutes): turn the 6 GB raw file into small tables
source("simple_dashboard/prepare_data.R")

# Step 2: open the dashboard
shiny::runApp("simple_dashboard")
```

Step 1 needs the raw file at `data/nibrs-2025.txt`. It is too large for GitHub, so download it from the FBI Crime Data Explorer. Step 2 needs only the small files in `simple_dashboard/processed/`, which are committed.

## Where the data comes from

The **National Incident-Based Reporting System (NIBRS)** is the FBI's national collection of crime reports from local police agencies. For each incident, an agency records what happened, who the victims were, and, importantly for this project, **how each victim was related to the offender**.

The 2025 file has about 13 million victim records. It lists about 22,400 agencies in the 50 states and DC: about 15,100 sent at least some 2025 data, and about 12,900 sent all 12 months.

## How the data was processed

`prepare_data.R` makes five choices, in this order. The number of records left after each step is in `processed/data_funnel_2025.csv`:

| Step | Records left |
|---|---|
| All victim records in the 2025 file | 13,227,732 |
| Keep victims who are **individual people**, not businesses, governments or "society" (for example, in drug offenses) | 9,122,670 |
| Keep victims whose relationship to an offender was **intimate partner**: spouse, common-law spouse, ex-spouse, boyfriend/girlfriend, or ex-boyfriend/girlfriend | 1,219,223 |
| Keep victims of a **violent crime against the person**: murder, sex offenses, kidnapping, aggravated assault, simple assault, intimidation (which includes stalking) | 1,100,974 |
| Keep the **50 states and DC**. Federal agencies and territories are dropped. | 1,099,967 |
| Keep agencies that reported **all 12 months** of 2025 | **1,079,836** |

**Why each choice:**

- **Individual people only.** Relationship to the offender is only recorded for people, so other victim types can't be IPV.
- **Intimate partner codes only.** Family violence (parents, children, siblings) is a different question with different services, so it isn't mixed in.
- **Violent crimes only.** Property crimes like theft between partners are left out. Including them would make "IPV" mean something broader than most readers expect.
- **One count per victim.** A victim can be connected to several offenses in one incident, for example an assault and an intimidation. Each victim is counted once, under their **most serious** offense, in this order: murder, sex offense, kidnapping, aggravated assault, simple assault, intimidation. That way no one is counted twice.
- **Full-year agencies only.** An agency that sent only three months of reports would make its area look safer than it is. Dropping partial-year agencies removes about 2% of records but keeps the numbers comparable.

**A note on wording.** The dashboard says *victimizations* rather than *victims*. If the same person was victimized in two separate incidents, they appear twice.

## What the dashboard shows

| Element | What it tells you |
|---|---|
| **Slider** | Pick a minimum number of IPV victimizations. States at or above it are highlighted on the map and listed in the table. Everything else on the page updates with it. |
| **Three summary boxes** | How many states meet the threshold, how many victimizations they account for together, and what share of the U.S. population lives in areas whose police reported all year (85%). |
| **Map** | States meeting the threshold are shaded by their number of victimizations. States below it are grey. Hover over a state to see its count, its rate per 100,000 residents, and how much of its population is covered. |
| **Offense chart** | What kind of crime these victimizations were, for all states or for one state picked from the dropdown. About two-thirds are simple assaults. |
| **Table** | The states meeting the threshold, with their count, rate and coverage. |

## How to read it carefully

**Counts mostly reflect population.** Texas and California have the most victimizations largely because they have the most people. The **rate per 100,000 residents** in the table and the hover text is the fairer way to compare states. The slider uses counts because that's the question it answers: "where is the volume?"

**Some states' numbers are incomplete.** Not every police agency reports to NIBRS. In 11 states, agencies reporting all year serve less than 80% of the population, and those states are marked ⚠. Pennsylvania is the lowest at 47%, followed by Alaska, North Dakota and Florida at about 60–63%. Their counts are almost certainly too low. The rate is calculated using only the population those reporting agencies serve, which partly corrects for this. Even so, reporting agencies may not be typical of the whole state.

**These are reported crimes.** Much intimate partner violence is never reported to police. These numbers show what police recorded, not how much violence happened.

**One year only.** The dashboard deliberately shows no trend over time. The number of agencies reporting to NIBRS changed a lot after the FBI's 2021 switch to NIBRS. An apparent rise between years can just mean more agencies started reporting.

## Files

| File | Purpose |
|---|---|
| `prepare_data.R` | Raw FBI file → three small CSVs (run once) |
| `app.R` | The dashboard |
| `processed/state_summary_2025.csv` | One row per state: victimizations, rate, coverage |
| `processed/ipv_by_state_offense_2025.csv` | Victimizations by state and offense type |
| `processed/data_funnel_2025.csv` | Records kept at each processing step |
| `report.html` | Longer write-up with charts and checks (open in a browser) |
