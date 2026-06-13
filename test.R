con <- DBI::dbConnect(RSQLite::SQLite(),dbname = "./web_scraping/data/master_data.db")
DBI::dbListTables(con)
DBI::dbListFields(con, "car_listings")
query <- "SELECT `price`, `source`, `url` FROM car_listings WHERE `price` > 10000000000"
test <- DBI::dbGetQuery(con,query)
print(test)
# DBI::dbDisconnect(con