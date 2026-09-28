# loading the shiny package
library(shiny)
# Define UI for application that draws a histogram
ui <- fluidPage(
  titlePanel("Hello Shiny!"),
  sidebarLayout(
    sidebarPanel(
      sliderInput("obs",
                  "Number of observations:",
                  min = 0,
                  max = 1000,
                  value = 500)
    ),
    mainPanel(
      plotOutput("distPlot")
    )
  )
)
# Define server logic required to draw a histogram
server <- function(input, output, session) {   
}
# Run the application
shinyApp(ui = ui, server = server)
