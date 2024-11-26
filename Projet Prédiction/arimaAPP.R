# Load necessary libraries
library(shiny)
library(quantmod)
library(forecast)
library(ggplot2)
library(DT)




file <- "data/NYSE.csv"
df1 <- read.csv2(file, header = TRUE, sep = ";")



df1 <- read.csv2(file, header = TRUE, sep = ";")
# Define the user interface
ui <- fluidPage(
  titlePanel("Prédiction du cours des actions avec le modèle ARIMA"),
  actionButton('help','Instruction Book'),
  actionButton('yahoo','Yahoo', onclick = "window.open('https://fr.finance.yahoo.com/', '_blank')"),
  sidebarLayout(
    sidebarPanel(
      # The textInput for symbol is commented out; we will use the selectizeInput instead
      # textInput("symbol", "Entrez le symbole de l'action :", value = "AAPL"),
      selectizeInput(
        inputId = "entreprise",
        label = "Tapez et sélectionnez :",
        choices = unique(df1$Description),
        options = list(
          placeholder = "Commencez à taper...",
          create = FALSE
        )
      ),
      dateRangeInput("dates", "Sélectionnez la période :",
                     start = Sys.Date() - 365 * 5,
                     end = Sys.Date()),
      numericInput("forecast_horizon", "Horizon de prévision (jours) :", value = 30, min = 1, max = 365),
      actionButton("goButton", "Lancer la prévision")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Données historiques", plotOutput("time_series_plot")),
        tabPanel("Prévision ARIMA", plotOutput("arima_forecast_plot")),
        tabPanel("Métriques du modèle", verbatimTextOutput("model_metrics"))
      )
    )
  )
)
# Define the server logic
server <- function(input, output) {
  # Create a reactive expression to get the symbol based on the selected company
  symbol <- reactive({
    req(input$entreprise)
    selected_row <- df1[df1$Description == input$entreprise, ]
    if (nrow(selected_row) == 0) {
      showNotification("Symbole introuvable pour l'entreprise sélectionnée.", type = "error")
      return(NULL)
    } else {
      return(selected_row$Symbol)
    }
  })
  # Reactive function to fetch stock data
  stock_data <- eventReactive(input$goButton, {
    req(symbol())
    req(input$dates)
    tryCatch({
      getSymbols(Symbols = symbol(), src = "yahoo",
                 from = input$dates[1],
                 to = input$dates[2],
                 auto.assign = FALSE)
    }, error = function(e) {
      showNotification(paste("Erreur lors de la récupération des données :", e$message), type = "error")
      return(NULL)
    })
  })
  # Plot of historical data
  output$time_series_plot <- renderPlot({
    data <- stock_data()
    req(data)
    adjusted <- Ad(data)
    plot(adjusted, main = paste("Cours de clôture ajusté de", symbol()),
         ylab = "Prix", xlab = "Date")
  })
  # ARIMA modeling and forecasting
  arima_result <- reactive({
    data <- stock_data()
    req(data)
    adjusted <- Ad(data)
    dates <- index(adjusted)
    adjusted_df <- data.frame(Date = dates, Adjusted = as.numeric(adjusted))
    n <- nrow(adjusted_df)
    if (n < 10) {
      showNotification("Pas assez de données pour construire le modèle.", type = "error")
      return(NULL)
    }
    train_size <- floor(n * 0.8)
    train_df <- adjusted_df[1:train_size, ]
    test_df <- adjusted_df[(train_size + 1):n, ]
    train_ts <- ts(train_df$Adjusted, frequency = 252)
    model <- auto.arima(train_ts)
    h <- min(input$forecast_horizon, nrow(test_df))
    forecast_values <- forecast(model, h = h)
    rmse <- if (h > 0) {
      sqrt(mean((forecast_values$mean - test_df$Adjusted[1:h])^2, na.rm = TRUE))
    } else {
      NA
    }
    # Prepare data for plotting
    forecast_df <- data.frame(Date = test_df$Date[1:h],
                              Forecast = as.numeric(forecast_values$mean),
                              Lower = forecast_values$lower[,2],
                              Upper = forecast_values$upper[,2])
    list(forecast_df = forecast_df, test_df = test_df[1:h, ], rmse = rmse, model = model)
  })
  # Plot of ARIMA forecast
  output$arima_forecast_plot <- renderPlot({
    res <- arima_result()
    req(res)
    forecast_df <- res$forecast_df
    test_df <- res$test_df
    ggplot() +
      geom_line(data = test_df, aes(x = Date, y = Adjusted), color = "blue", size = 1, linetype = "dashed") +
      geom_line(data = forecast_df, aes(x = Date, y = Forecast), color = "red", size = 1) +
      geom_ribbon(data = forecast_df, aes(x = Date, ymin = Lower, ymax = Upper), fill = "grey70", alpha = 0.5) +
      ggtitle(paste("Prévision ARIMA pour", symbol())) +
      xlab("Date") + ylab("Prix") +
      theme_minimal()
  })
  # Display model metrics
  output$model_metrics <- renderPrint({
    res <- arima_result()
    req(res)
    cat("Résumé du modèle ARIMA pour", symbol(), ":\n")
    print(summary(res$model))
    if (!is.na(res$rmse)) {
      cat("\nRMSE :", round(res$rmse, 4))
    } else {
      cat("\nRMSE non disponible (pas de données de test).")
    }
  })
}
# Run the application
shinyApp(ui = ui, server = server)
