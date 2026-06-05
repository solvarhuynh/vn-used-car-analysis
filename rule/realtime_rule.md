# Real-time Processing Rules

This document defines the rules and logic for continuous, near real-time scraping and updating of the used car database.

### 1. Automated Scheduling (Task Scheduler)

-   **Scheduling**: Configure the system (local machine or server) to automatically trigger the main scraping script every 5 or 10 minutes.
-   **Implementation**: In R, utilize the `taskscheduleR` package (for Windows) or the `cronR` package (for Linux) to set up these cron jobs directly within the script environment.

### 2. Database Integration (Moving from CSV to DB)

-   **Storage Shift**: Continuously writing to or overwriting a CSV file is inefficient and can lead to data loss or bloated files. Replace `write_csv()` operations with direct Database connections.
-   **Tools**: Use a Database system (such as SQLite for a local `.db` file, MySQL, or PostgreSQL) connected via the `DBI` and `RSQLite`/`RMySQL`/`RPostgres` packages.
-   **Upsert Logic**: For every newly scraped car, check its `url` or `id` against the database. 
    -   If it does not exist: Perform an `INSERT`. 
    -   If it already exists: Perform an `UPDATE` (e.g., update the price) or ignore it.

### 3. Real-time Scraping Logic (Delta Fetching)

-   **Targeting the Latest**: In real-time mode, only scrape Page 1 of the listings (e.g., the 20 newest cars) to capture newly posted vehicles. Do not iterate through multiple pages.
-   **Break Condition**: When fetching Page 1 (whether via API JSON or HTML parsing), extract the list of the latest cars and iterate through them one by one:
    -   *Case 1*: The record's URL/ID is NOT in the DB -> Save/Insert.
    -   *Case 2*: The record's URL/ID IS in the DB -> Immediately **STOP (break)** the loop.
-   **Rationale**: Encountering an existing record means all older records have already been scraped previously. Halting the script prevents duplicate scraping, saves bandwidth, and protects historical data.