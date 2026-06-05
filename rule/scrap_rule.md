# Data Scraping Rules

This document outlines the requirements for scraping used car data from various websites using R.

---

### 1. Target Websites

1.  **Chợ Tốt**
    -   URL: `https://xe.chotot.com/mua-ban-oto`
    -   Method: **API**
    -   Endpoint: `https://gateway.chotot.com/v1/public/ad-listing-video?cg=2010&st=s%2Ck&source=listing&limit=20&o=0`

2.  **Carpla**
    -   URL: `https://carpla.vn/mua-xe`
    -   Method: **API**
    -   Endpoint: `https://api-ecom.carpla.vn/app-server/search/car?offset=0&limit=15&saleState=1&type=1`

3.  **Bán Xe Hơi Cũ**
    -   URL: `https://banxehoicu.vn/ban-oto-cu`
    -   Method: **HTML Parsing** (No API)

4.  **Oto.com.vn**
    -   URL: `https://oto.com.vn/mua-ban-xe`
    -   Method: **HTML Parsing** (No API)

---

### 2. Data Schema

Each scraped record must be structured into a data frame with the following 18 columns.

| Column Name   | Data Type | Description                                             |
|---------------|-----------|---------------------------------------------------------|
| `brand`       | String    | Car brand (e.g., Toyota, Mercedes, Kia)                 |
| `model`       | String    | Car model name (e.g., Vios, Carnival, Raize)            |
| `trim`        | String    | Specific version/trim of the model (e.g., G, Luxury)    |
| `year`        | Integer   | Year of manufacture                                     |
| `body_type`   | String    | Body style (e.g., Sedan, SUV, Crossover, Minivan)       |
| `fuel_type`   | String    | Fuel type (e.g., Petrol, Diesel, Hybrid)                |
| `transmission`| String    | Transmission type (e.g., Automatic, Manual, CVT)        |
| `engine_size` | Float     | Engine displacement in liters (e.g., 1.5, 2.0)          |
| `seat_count`  | Integer   | Number of seats                                         |
| `drivetrain`  | String    | Drive system (e.g., FWD, RWD, AWD, 4WD)                 |
| `price`       | Integer   | Current selling price in VND                            |
| `mileage`     | Integer   | Odometer reading in kilometers                          |
| `origin`      | String    | Origin of the car ("Trong nước", "Nhập khẩu")           |
| `color`       | String    | Exterior color                                          |
| `city`        | String    | Province/City where the car is sold                     |
| `posted_date` | Date      | The date the listing was posted                         |
| `source`      | String    | The source website (e.g., xe.chotot.com, carpla.vn)     |
| `url`         | String    | Direct URL to the car listing                           |

---

### 3. Scraping Rules & Process

1.  **File & Directory Structure**:
    -   Each website must have its own scraping script: `script/scrap_{website_name}.R`.
    -   The output must be a CSV file saved to the `data/` directory.
    -   The output filename must be: `data_{website_name}_raw.csv` (e.g., `data_chotot_raw.csv`).

2.  **Data Handling**:
    -   If a value for a specific field cannot be found, it must be set to `NA`.
    -   Ensure all text data is handled with UTF-8 encoding.
    -   Do not include any icons or special characters in the data.

3.  **Scraping Logic**:
    -   **Step A (Listing Page)**: From the main listing page, collect all URLs leading to individual car posts.
    -   **Step B (Detail Page)**: Iterate through the collected list of URLs. For each URL, visit the page and scrape the 18 required data fields.
    -   **Step C (Pagination)**: After processing all URLs on the current page, proceed to the next page (or trigger the "Load More" button) and repeat from Step A.
    -   **Duplicate Prevention for "Load More"**: For websites using "Load More" buttons, the script must keep track of URLs it has already processed in the current session to avoid re-scraping the same items.
