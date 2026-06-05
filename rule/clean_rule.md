# Data Cleaning Rules

This document defines the rules for cleaning and standardizing the raw scraped data across all sources to ensure consistency.

### 1. General Formatting & Standardization

-   **Missing Values**: All missing data, empty strings (`""`), or unrecognized values must be replaced with `NA`.
-   **Whitespace**: Trim all leading, trailing, and multiple internal spaces in all string columns.
-   **Capitalization**: The values in the `brand` and `model` columns must be converted to UPPERCASE.
-   **Encoding**: Ensure all text is properly encoded in UTF-8.

### 2. Specific Column Rules

-   **`price`**: Standardize to numeric VND. Convert various formats (e.g., "300.000.000", "300 triệu") into a pure integer (e.g., `300000000`). Remove currency symbols, commas, and dots.
-   **`posted_date`**: Standardize date format to `DD-MM-YYYY`.
-   **`mileage`**: Remove text like "km", commas, or dots, and convert to Integer.
-   **`engine_size`**: Extract the numeric value (Float) and remove suffixes like "L" (e.g., "1.5L" becomes `1.5`).
-   **`year`, `seat_count`**: Ensure these are strictly cast to Integer data types.
-   **`body_type`, `fuel_type`, `transmission`, `drivetrain`**: Standardize to a predefined list of string categories if possible (e.g., convert "Số tự động" to "Tự động").
-   **Units of Measurement**: Standardize any other metrics (e.g., weight to tons, fuel consumption to liters) if they appear, though they must map properly to the defined 18 columns.

### 3. Output Requirements

-   The cleaned data must strictly follow the 18 columns defined in the schema (`scrap_rule.md`).
-   Any column that does not exist in the raw data from a specific website must be added and filled with `NA`.
-   Export the final cleaned file as `data_{website_name}_clean.csv` in the `data/` directory.