# ============================================================
# FILE: Cleaning_Data.R
# Run first: clean data_mau.csv and export cleaned dataset
# ============================================================

INPUT_FILE <- "data/data_mau.csv"
OUTPUT_DIR <- "data/output_probability_statistics"
CLEAN_FILE <- file.path(OUTPUT_DIR, "00_data_da_lam_sach.csv")
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

to_number <- function(x) suppressWarnings(as.numeric(as.character(x)))

clean_text <- function(x) {
  x <- trimws(as.character(x))
  x[x == "" | toupper(x) == "NA" | toupper(x) == "N/A"] <- NA
  x
}

normalize_transmission <- function(x) {
  x <- tolower(clean_text(x))
  out <- rep(NA_character_, length(x))

  out[x %in% c("manual", "mt")] <- "Manual"
  out[x %in% c("automatic", "auto", "at")] <- "Automatic"
  out[x %in% c("cvt")] <- "CVT"
  out[x %in% c("robot", "robotic")] <- "Robot"

  out
}

data_raw <- read.csv(
  INPUT_FILE,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA", "N/A", "null")
)

required_cols <- c(
  "brand", "model", "year", "price", "mileage",
  "transmission", "fuel_type", "city", "source"
)

missing_cols <- setdiff(required_cols, names(data_raw))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}

data_clean <- data_raw

data_clean$brand <- clean_text(data_clean$brand)
data_clean$model <- clean_text(data_clean$model)
data_clean$city <- clean_text(data_clean$city)
data_clean$fuel_type <- clean_text(data_clean$fuel_type)
data_clean$source <- clean_text(data_clean$source)

data_clean$year <- to_number(data_clean$year)
data_clean$price_raw <- to_number(data_clean$price)
data_clean$mileage <- to_number(data_clean$mileage)

data_clean$transmission_raw <- clean_text(data_clean$transmission)
data_clean$transmission <- normalize_transmission(data_clean$transmission_raw)

data_clean$price_scale <- ifelse(
  data_clean$price_raw < 1000,
  "Small scale x100000",
  "Original scale"
)

data_clean$price <- ifelse(
  data_clean$price_raw < 1000,
  data_clean$price_raw * 100000,
  data_clean$price_raw
)

valid_rows <-
  !is.na(data_clean$brand) &
  !is.na(data_clean$year) &
  data_clean$year >= 1980 &
  data_clean$year <= CURRENT_YEAR + 1 &
  !is.na(data_clean$price) &
  data_clean$price > 0 &
  !is.na(data_clean$mileage) &
  data_clean$mileage >= 0 &
  !is.na(data_clean$transmission)

data_clean <- data_clean[valid_rows, ]

if (nrow(data_clean) == 0) {
  stop("No valid rows after cleaning. Please check input data.")
}

data_clean$age <- CURRENT_YEAR - data_clean$year

data_clean$age_group <- cut(
  data_clean$age,
  breaks = c(-Inf, 3, 7, 12, Inf),
  labels = c("0-3 nam", "4-7 nam", "8-12 nam", "Tren 12 nam"),
  right = TRUE
)

price_q75 <- quantile(data_clean$price, 0.75, na.rm = TRUE)
mileage_q75 <- quantile(data_clean$mileage, 0.75, na.rm = TRUE)

data_clean$is_high_price <- data_clean$price >= price_q75
data_clean$is_high_mileage <- data_clean$mileage >= mileage_q75

overview <- data.frame(
  metric = c(
    "Rows before cleaning",
    "Rows after cleaning",
    "Rows removed",
    "Unique brands",
    "Unique transmissions",
    "Min year",
    "Max year",
    "High price threshold Q75",
    "High mileage threshold Q75"
  ),
  value = c(
    nrow(data_raw),
    nrow(data_clean),
    nrow(data_raw) - nrow(data_clean),
    length(unique(data_clean$brand)),
    length(unique(data_clean$transmission)),
    min(data_clean$year, na.rm = TRUE),
    max(data_clean$year, na.rm = TRUE),
    round(as.numeric(price_q75), 2),
    round(as.numeric(mileage_q75), 2)
  )
)

write.csv(data_clean, CLEAN_FILE, row.names = FALSE, fileEncoding = "UTF-8")
write.csv(overview, file.path(OUTPUT_DIR, "00_tong_quan_lam_sach.csv"), row.names = FALSE)

cat("\n=== CLEANING DATA DONE ===\n")
print(overview, row.names = FALSE)
cat("\nCleaned data saved to: ", CLEAN_FILE, "\n", sep = "")