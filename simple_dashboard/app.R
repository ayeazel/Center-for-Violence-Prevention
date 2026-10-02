# Intimate partner violence by state, NIBRS 2025 -- a first Shiny dashboard.
#
# Run from the repository root (after prepare_data.R):
#   shiny::runApp("simple_dashboard")
#
# The app reads two small CSVs made by prepare_data.R. It does no heavy data
# work itself, so it starts quickly.

library(shiny)
library(bslib)
library(dplyr)
library(readr)
library(ggplot2)
library(plotly)

# ---- Data -------------------------------------------------------------------

states   <- read_csv("processed/state_summary_2025.csv", show_col_types = FALSE)
offenses <- read_csv("processed/ipv_by_state_offense_2025.csv", show_col_types = FALSE)

offense_order <- c("Murder", "Sex offense", "Kidnapping", "Aggravated assault",
                   "Simple assault", "Intimidation (incl. stalking)")

low_coverage <- 0.80   # below this share of population covered, flag the state
slider_max   <- ceiling(max(states$ipv_victims) / 5000) * 5000

fmt_n   <- function(x) format(round(x), big.mark = ",")
fmt_pct <- function(x) ifelse(x > 0 & x < 0.005, "<1%", paste0(round(100 * x), "%"))

# ---- UI ---------------------------------------------------------------------

ui <- page_sidebar(
  title = "Intimate partner violence reported to the FBI, 2025",
  theme = bs_theme(version = 5, primary = "#9b2335"),
  fillable = FALSE,   # let cards keep their set heights and the page scroll

  sidebar = sidebar(
    width = 300,
    sliderInput("threshold", "Highlight states with at least this many intimate partner victimizations:",
                min = 0, max = slider_max, value = 10000, step = 1000, sep = ",", ticks = FALSE),
    selectInput("state", "Show offense types for:",
                choices = c("All states" = "ALL", setNames(states$state, states$state_name))),
    hr(),
    p(class = "small text-muted",
      "Counts include only police agencies that reported all 12 months of 2025. ",
      "States marked ⚠ had less than ", fmt_pct(low_coverage), " of their population covered by those agencies, ",
      "so their counts are likely too low.")
  ),

  layout_columns(
    fill = FALSE,
    value_box("States at or above the threshold", textOutput("n_states")),
    value_box("Victimizations in those states", textOutput("n_victims")),
    value_box("U.S. population covered by full-year reporting",
              fmt_pct(sum(states$population_covered) / sum(states$population_total)))
  ),

  layout_columns(
    col_widths = c(7, 5),
    card(card_header("States meeting the threshold (hover for details)"),
         plotlyOutput("map", height = "380px")),
    card(card_header(textOutput("offense_title")),
         plotOutput("offense_chart", height = "380px"))
  ),

  card(card_header("States meeting the threshold"),
       p(class = "small text-muted mb-1",
         "Bigger states have more victimizations simply because more people live there. ",
         "The rate per 100,000 residents makes states of different sizes comparable."),
       tableOutput("state_table"))
)

# ---- Server -----------------------------------------------------------------

server <- function(input, output, session) {

  # Every element below reacts to the slider through this one table.
  highlighted <- reactive(filter(states, ipv_victims >= input$threshold))

  output$n_states  <- renderText(paste(nrow(highlighted()), "of", nrow(states)))
  output$n_victims <- renderText(fmt_n(sum(highlighted()$ipv_victims)))

  output$map <- renderPlotly({
    d <- states |>
      mutate(meets = ipv_victims >= input$threshold,
             hover = paste0("<b>", state_name, "</b>",
                            "<br>Victimizations: ", fmt_n(ipv_victims),
                            "<br>Rate per 100,000: ", round(rate_per_100k),
                            "<br>Population covered: ", fmt_pct(pct_covered),
                            ifelse(pct_covered < low_coverage, " ⚠", "")))

    plot_geo(locationmode = "USA-states") |>
      add_trace(data = filter(d, meets), type = "choropleth", locations = ~state,
                z = ~ipv_victims, text = ~hover, hoverinfo = "text",
                colorscale = list(c(0, "#f4c7c3"), c(1, "#9b2335")),
                colorbar = list(title = "Victimizations", len = 0.6),
                marker = list(line = list(color = "white", width = 0.5))) |>
      add_trace(data = filter(d, !meets), type = "choropleth", locations = ~state,
                z = 0, text = ~hover, hoverinfo = "text", showscale = FALSE,
                colorscale = list(c(0, "#e6e6e6"), c(1, "#e6e6e6")),
                marker = list(line = list(color = "white", width = 0.5))) |>
      layout(geo = list(scope = "usa", projection = list(type = "albers usa")),
             margin = list(l = 0, r = 0, t = 0, b = 0))
  })

  output$offense_title <- renderText({
    if (input$state == "ALL") "Most serious offense, all states"
    else paste("Most serious offense,", states$state_name[states$state == input$state])
  })

  output$offense_chart <- renderPlot({
    d <- if (input$state == "ALL") offenses else filter(offenses, state == input$state)
    d <- d |>
      group_by(offense_type) |>
      summarise(victims = sum(victims)) |>
      mutate(share = victims / sum(victims),
             offense_type = factor(offense_type, levels = rev(offense_order)))

    ggplot(d, aes(share, offense_type)) +
      geom_col(fill = "#9b2335", width = 0.7) +
      geom_text(aes(label = paste0(fmt_pct(share), "  (", trimws(fmt_n(victims)), ")")),
                hjust = -0.08, size = 3.4) +
      scale_x_continuous(limits = c(0, 1.25), expand = c(0, 0)) +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_size = 12) +
      theme(panel.grid = element_blank(), axis.text.x = element_blank())
  }, res = 96)

  output$state_table <- renderTable({
    highlighted() |>
      arrange(desc(ipv_victims)) |>
      transmute(State = paste0(state_name, ifelse(pct_covered < low_coverage, " ⚠", "")),
                `Victimizations` = fmt_n(ipv_victims),
                `Rate per 100,000 residents` = fmt_n(rate_per_100k),
                `Population covered` = fmt_pct(pct_covered))
  }, striped = TRUE, hover = TRUE, width = "100%")
}

shinyApp(ui, server)
