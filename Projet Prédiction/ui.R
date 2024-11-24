ui <- fluidPage(
  titlePanel("Analyse et prédiction du cours des actions"),
  hr(),
  actionButton('help','Instruction Book'),
  actionButton('yahoo','Yahoo', onclick = "window.open('https://fr.finance.yahoo.com/', '_blank')"),
  br(),
  br(),
  sidebarLayout(
    sidebarPanel(
      selectizeInput(
        inputId = "entreprise",
        label = "Tapez et sélectionnez :",
        choices = unique(df1$Description),
        options = list(
          placeholder = "Commencez à taper...",
          create = TRUE
        )
      ),
      uiOutput('dynamic_var'),
      
      selectInput('period', "Choice your periode", choices = c('Jour', 'Semaine', 'Mois', 'Trimestre', 'An')),
      
      uiOutput('dynamic_period')
      
    ),
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Global",
          tabsetPanel(
            tabPanel(
              'Plot',
              br(),
              plotOutput("plot")
            ),
            tabPanel(
              'Table',
              br(),
              DT::DTOutput("table")
            )
          )
        ),
        tabPanel(
          "Prévision",
          tabsetPanel(
            tabPanel(
              "Exponentiel",
              br(),
              plotOutput("expo")
            ),
            tabPanel(
              "Action",
              br(),
              plotOutput("action")
            )
          )
        )
      )
    )
  )
)