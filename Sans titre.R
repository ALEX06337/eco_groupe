library(shiny)
library(quantmod)
library(ggplot2)
library(DT)

ui <- fluidPage(
  titlePanel("Analyse et prédiction du cours des actions"),
  hr(),
  actionButton('help', 'Mode action'),
  actionButton('nom_entreprise', 'Find ton entreprise'),
  br(),
  sidebarLayout(
    sidebarPanel(
      textInput('entreprise', 'Write ton entreprise', value = "AAPL"),
      numericInput('date', 'Sur combien de trimestre la prédiction', value = 0)
    ),
    mainPanel(
      tabsetPanel(
        tabPanel('Plot', 
                 uiOutput("dynamic_label"),  # Génération dynamique de selectInput
                 plotOutput("plot")),
        tabPanel('Table', dataTableOutput("table"))
      )
    )
  )
)

server <- function(input, output, session) {
  # Fonction réactive pour récupérer les données
  recup <- reactive({
    req(input$entreprise)  # S'assurer qu'une entreprise est entrée
    df <- getSymbols(input$entreprise, src = "yahoo", auto.assign = FALSE)
    data.frame(Date = index(df), coredata(df))
  })
  
  # Met à jour dynamiquement le selectInput pour choisir la variable à afficher
  output$dynamic_label <- renderUI({
    df <- recup()
    selectInput("var", "Choississez le label", choices = names(df)[-1], selected = names(df)[2])
  })
  
  # Génération du graphique avec ggplot2
  output$plot <- renderPlot({
    req(input$var)  # S'assurer qu'une variable est sélectionnée
    df <- recup()
    ggplot(df, aes(x = Date, y = .data[[input$var]])) + 
      geom_line(color = "blue") + 
      labs(title = paste("Évolution de", input$var, "pour", input$entreprise),
           x = "Date", y = "Valeur") +
      theme_minimal()
  })
  
  # Génération de la table avec DT
  output$table <- DT::renderDataTable({
    recup()
  })
}

# Lancement de l'application
shinyApp(ui = ui, server = server)
