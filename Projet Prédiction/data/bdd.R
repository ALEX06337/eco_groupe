file <- "data/NYSE.csv"
df1 <- read.csv2(file, header = TRUE, sep = ";")

# Ajoute un symbol et sa description (à la main, j'ai pas confiance aux utilisateurs) ok Vlad ? ;)
ajout <- c("TSLA", "Tesla")
if (nrow(df1[df1$Symbol == ajout[1], ]) == 0) {
  df1 <- rbind(df1, ajout)
  write.csv2(df1, file = file, row.names = FALSE)
}