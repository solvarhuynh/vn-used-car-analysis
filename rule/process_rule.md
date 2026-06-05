# Data Processing Workflow

This document outlines the end-to-end pipeline for scraping, cleaning, and processing used car data from various sources. The entire process should be orchestrated by a main script (`run_pipeline.R`).

---

### Step 1: Data Scraping

1.  **Objective**: Scrape raw data from each target website.
2.  **Scripts**: For each website, a dedicated R script named `scrap_{website_name}.R` will be created and placed in the `script/` directory.
3.  **Rules**: Each script must adhere to the guidelines defined in `scrap_rule.md`.
4.  **Output**: Upon successful execution, each script will generate a raw data file named `data_{website_name}_raw.csv` in the `data/` directory.
5.  **Logging**: The script must log the start time, end time, number of records scraped, and any errors encountered.

---

### Step 2: Data Cleaning

1.  **Objective**: Clean and standardize the raw data from each source.
2.  **Scripts**: For each raw dataset, a corresponding cleaning script named `clean_{website_name}.R` will be executed. These scripts are located in the `script/` directory.
3.  **Rules**: The cleaning process must follow the rules specified in `clean_rule.md`.
4.  **Output**: Each script will produce a clean data file named `data_{website_name}_clean.csv` in the `data/` directory.
5.  **Logging**: Log the start, completion, number of rows processed, and any data quality issues found.

---

### Step 3: Data Merging

1.  **Objective**: Combine all clean datasets into a single master dataset.
2.  **Script**: A script named `merge_data.R` will be used for this step.
3.  **Process**: The script will read all `*_clean.csv` files from the `data/` directory, combine them, and handle any final deduplication or schema alignment.
4.  **Output**: A final, consolidated file named `master_data.csv` will be saved in the `data/` directory.
5.  **Logging**: Log the merging process, including the number of files merged and the total number of records in the final dataset.

---

### Step 4: Database Storage

1.  **Objective**: Convert and manage the consolidated data in a robust database system.
2.  **Process**: Read the `master_data.csv` and import all records into a local `.db` file (e.g., SQLite `master_data.db`) for easier querying, management, and preparing for real-time updates.

---

### Step 5: Real-time Execution

1.  **Objective**: Continuously update the database with the latest car listings in near real-time.
2.  **Rules**: The process must strictly follow the rules defined in `realtime_rule.md`.
3.  **Process**: The script is scheduled to trigger at short intervals, scraping only the newest data from the first pages, and injecting it directly into the `.db` file using delta fetching logic.

---

### General Rule: Logging

-   **File**: All process notifications and events must be appended to the `log.txt` file located in the project's root directory.
-   **Format**: Each log entry should be timestamped and include the script name and a descriptive message (e.g., `[YYYY-MM-DD HH:MM:SS] [scrap_chotot.R] - INFO: Successfully scraped 520 records.`).
