library(shiny)
library(shinyWidgets)
library(quantmod)
library(ggplot2)
library(dplyr)



source("data/bdd.R")
day <- c(1, 7, 30, 90, 365)
names(day) <- c('Jour', 'Semaine', 'Mois', 'Trimestre', 'An')

source("ui.R")

server <- function(input, output) {
  
  observeEvent(input$help, {
    showModal(modalDialog(
      title = "Mode Action",
      "Entrer le symbole du nom de l'action choisi (le nom entre parenthèse) et le nombre de trimestre pour la prévision")
    )
  })
  
  symbol <- reactive({
    if (nrow(df1[df1$Description == input$entreprise, ]) == 0) {
      input$entreprise
    } else {
      df1[df1$Description == input$entreprise, "Symbol"]
    }
  })
  
  recup <- reactive({
    df <- tryCatch(
      {
        # Code pouvant provoquer une erreur
        getSymbols(symbol(), src = "yahoo", auto.assign = FALSE)
      },
      error = function(e) {
        # Action en cas d'erreur (pas d'erreur ici mais personne connaît l'avenir)
        df1 <- df1[df1$Symbol != symbol(), ] # Supprime le symbole
        write.csv2(df1, file = file, row.names = FALSE) # Mise à jour du fichier
        
        print("Une erreur est survenue :")
        print(e$message)
        return(NULL) # Retourner une valeur par défaut
      },
      warning = function(w) {
        # Action en cas d'avertissement
        df1 <- df1[df1$Symbol != symbol(), ]
        write.csv2(df1, file = file, row.names = FALSE)
        
        print("Un avertissement est survenu :")
        print(w$message)
        return(NULL)
      },
      finally = {
        # Action à effectuer quoi qu'il arrive
        print("Fin de l'exécution.")
      }
    )
    if (is.null(df) == FALSE) {
      df <- data.frame(Date = index(df), coredata(df))
    }
    
    return(df)
  })
  
  output$dynamic_var <- renderUI({
    validate(
      need(input$entreprise != "", "\n")
    )
    if (is.null(recup()) == FALSE) {
      df <- recup()
      selectInput('var', 'Choice Y', choices = unique(colnames(df[-1])))
    }
  })
  
  # Global
  output$plot <- renderPlot({
    validate(
      need(input$entreprise != "", "Please, enter your entreprise !"),
    )
    if (is.null(recup()) == FALSE) {
      ggplot(recup(), aes(x = Date, y = .data[[input$var]])) + geom_line() + labs(title = paste("Prévision de", input$var, "pour", input$entreprise))
    } else {
      showModal(modalDialog(
        title = "Error",
        "Yahoo ne reconnaît plus cette entreprise, veuillez en entrer une autre !")
      )
    }
  })
  
  output$table <- DT::renderDataTable({
    validate(
      need(is.null(recup()) == FALSE, "Please, enter an other entreprise !")
    )
    recup()
  })
  
  
  # Prévision
  output$dynamic_period <- renderUI({
    numericInput('date', paste('Sur combien de', input$period, 'la prédiction'), value = 2, min = 1)
  })
  
  ## Exponentielle
  expo <- function(df){
    nui <- input$date * day[input$period]
    n <- ifelse(nui*16<4500, nui*16, 4500)
    nfinal <- n + nui
    y <- tail(df[[input$var]], n = n)
    x <- 1:n
    b <- exp(coef(lm(log(y) ~ x))["x"]) # Pente
    a <- exp(coef(lm(log(y) ~ x))["(Intercept)"]) # Origine
    
    Ct <- a*b^x
    Ctfinal <- a*b^(1:(nfinal))
    
    tableau <- array(y/Ct, dim = c(2, 2, n/4))
    
    
    Siprime <- function(tableau, sum = 0, Si = 0) {
      nmat <- length(tableau)/4
      for (col in 1:2) {
        for (row in 1:2) {
          for (mat in 1:nmat) {
            sum <- sum + tableau[row,col,mat]
          }
          Si <- c(Si, sum/nmat)
          sum <- 0
        }
      }
      Si <- Si[-1]
      Siprime <- Si/mean(Si)
      return(Siprime)
    }
    
    St <-  rep(Siprime(tableau), times = (n/4))
    if (nui%%4 == 0) {
      Stfinal <- rep(Siprime(tableau), times = (n/4 + nui/4))
    } else {
      Stfinal <- c(rep(Siprime(tableau), times = (n/4 + (nui-(nui%%4))/4)), Siprime(tableau)[1:(nui%%4)])
    }
    
    modele <- Ctfinal*Stfinal 
    plot((1:nfinal), modele, type = "l", ylim = range(c(modele, y)), lwd = 2)
    lines(1:n, y, col = "red")
  }
  
  output$expo <- renderPlot({
    validate(
      need(is.null(recup()) == FALSE, "Please, enter an other entreprise !")
    )
    expo(recup())
  })
  
  
  
  
  
  # Cours d'action
  modele_action <- function(df){
    nui <- input$date * day[input$period]
    n <- ifelse(nui*8<4500, nui*8, 4500)
    y <- tail(df[[input$var]], n = n)
    
    modele <- function(y, alpha) {
      x <- y[1]
      for (i in 1:length(y)) {
        x <- c(x, alpha * y[i] + (1 - alpha) * x[i])
      }
      x <- c(x, rep(x[length(y)+1], 2))
      return(x)
    }
    
    rmse <- function(y, modele) {
      return(sqrt(mean((y-modele[1:length(y)])^2)))
    }
    
    alpha <- 0.50
    end <- FALSE
    while(end == FALSE) {
      if (rmse(y, modele(y, alpha)) > rmse(y, modele(y, alpha-0.01))) {
        alpha <- alpha - 0.01
      } else if (rmse(y, modele(y, alpha)) > rmse(y, modele(y, alpha+0.01))) {
        alpha <- alpha + 0.01
      } else {
        modele <- modele(y, alpha)
        rmse <- rmse(y, modele)
        end <- TRUE
      }
    }
    
    plot(1:(n+3), modele, type = "l", ylim = range(c(modele, y)), lwd = 2)
    lines(1:n, y, col = "red", lwd = 2)
  }
  
  output$action <- renderPlot({
    validate(
      need(is.null(recup()) == FALSE, "Please, enter an other entreprise !")
    )
    modele_action(recup())
  })
  
}

shinyApp(ui = ui, server = server)