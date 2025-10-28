# ============================================================================
# 02_clean.R - Data cleaning and standardization
#
# Dataset: [DATASET NAME]
# Author: [Your Name]
# Date: [YYYY-MM-DD]
#
# This script cleans and standardizes raw data using a modular approach.
# Follow the step-by-step guide below to customize for your dataset.
# ============================================================================

# Load packages ---------------------------------------------------------------
library(dplyr)
library(tidyr)
library(stringr)
library(janitor)
library(arrow)
library(here)
library(fs)
library(cli)
library(readr)

# Setup -----------------------------------------------------------------------
dir_create(here("processed"))
dir_create(here("logs"))

log_file <- here("logs", paste0("02_clean_", Sys.Date(), ".log"))
log_con <- file(log_file, open = "wt")
sink(log_con, type = "output", split = TRUE)
sink(log_con, type = "message")

cli_h1("Data Cleaning Process")
cli_alert_info("Started at {Sys.time()}")

# Load download metadata ------------------------------------------------------
download_metadata <- readRDS(here("raw", "download_metadata.rds"))
files_to_process <- download_metadata |>
  filter(success == TRUE) |>
  pull(name)

cli_alert_info("Found {length(files_to_process)} file{?s} to process")

# ============================================================================
# Helper Functions - Customize these for your dataset
# ============================================================================

#' Standardize column names to snake_case
#' @param df Data frame
standardize_names <- function(df) {
  df |>
    janitor::clean_names()
}

# OBS: read_ functions generally allow for a name_repair or .name_repair argument
read_csv_clean <- function(file, ...) {
  readr::read_csv(
    file,
    # suppression of column type messages
    show_col_types = FALSE,
    # fix column names
    name_repair = janitor::make_clean_names,
    # additional arguments
    ...
  )
}

# note: readxl::read_excel has a .name_repair argument (note the dot)
# - haven::read_dta(..., .name_repair = ...)
# - etc

#' Simplify strings - remove accents, convert to lowercase, replace spaces with underscores
#' @param x Character vector
clean_string <- function(x) {
  x |>
    stringi::stri_trans_general(id = "Latin-ASCII") |>
    stringr::str_to_lower() |>
    stringr::str_squish() |>
    stringr::str_replace_all(" ", "_")
}

#' Parse Brazilian number format (1.234,56 -> 1234.56)
#' @param x Character vector with Brazilian number format
parse_number_br <- function(x) {
  x |>
    stringr::str_remove_all("\\.") |> # Remove thousand separators
    stringr::str_replace(",", ".") |> # Replace decimal comma
    as.numeric()
}

# May need to vectorize if input is a vector
parse_number_br <- Vectorize(parse_number_br)

# Converting factor to numeric: remember to convert to character first

as_numeric_factor <- function(x) {
  as.numeric(as.character(x))
}

#' Parse Brazilian date format (DD/MM/YYYY)
#' @param x Character vector with Brazilian date format
parse_date_br <- function(x) {
  as.Date(x, format = "%d/%m/%Y")
}

#' Validate and clean CPF (11 digits)
#' @param x Character vector with CPF
clean_cpf <- function(x) {
  x |>
    stringr::str_remove_all("[^0-9]") |>
    (\(cpf) {
      dplyr::if_else(stringr::str_length(cpf) == 11, cpf, NA_character_)
    })()
}

#' Validate and clean CNPJ (14 digits)
#' @param x Character vector with CNPJ
clean_cnpj <- function(x) {
  x |>
    str_remove_all("[^0-9]") |>
    (\(cnpj) if_else(str_length(cnpj) == 14, cnpj, NA_character_))()
}

# When importing data from Excel

readxl::read_excel(
  "terrible_excel_file.xlsx",
  sheet = readxl::excel_sheets()[4], # Select the correct sheet
  skip = 2, # Skip header rows
  # range = "B3:Z1000",               # or specify data range
  na = c("#VALOR!"), # Add Excel NA values
)

#' Import Excel file with common NA values and clean column names
#' @param file Excel file path
#' @param ... Additional arguments passed to readxl::read_excel
import_excel <- function(file, ...) {
  na_excel <- c(
    "",
    "NA",
    "#N/A",
    "#N/D",
    "#DIV/0!",
    "#VALUE!",
    "#VALOR!",
    "#REF!",
    "#NAME?",
    "#NOME?",
    "#NUM!",
    "#NÚM!",
    "#NULL!",
    "#NULO!"
  )

  readxl::read_excel(
    file,
    na = na_excel,
    .name_repair = janitor::make_clean_names,
    ...
  )
}


# ============================================================================
# CUSTOMIZE THIS SECTION
# ============================================================================

#' Load and clean a single file
#'
#' This is where you customize the cleaning logic for your specific dataset.
#' Follow these steps:
#'
#' 1. Load the raw data file
#' 2. Standardize column names
#' 3. Select and rename relevant columns
#' 4. Apply data type conversions
#' 5. Clean text fields
#' 6. Handle missing values
#' 7. Create derived variables
#' 8. Add metadata columns (year, source, etc.)
#'
#' @param file_name Name/year identifier from download metadata
#' @return Cleaned data frame
clean_single_file <- function(file_name) {
  cli_h2("Processing: {file_name}")

  # Step 1: Load raw data
  # TODO: Update the file path pattern to match your downloaded files
  raw_file <- here("raw", file_name, "data.csv")

  if (!file_exists(raw_file)) {
    cli_alert_danger("File not found: {.file {raw_file}}")
    return(NULL)
  }

  cli_alert_info("Reading {.file {basename(raw_file)}}...")

  df_raw <- read_csv(
    raw_file,
    locale = locale(encoding = "UTF-8"),
    show_col_types = FALSE,
    # Add specific column types if needed:
    # col_types = cols(
    #   valor = col_character(),
    #   data = col_character()
    # )
  )

  cli_alert_success("Loaded {nrow(df_raw)} rows × {ncol(df_raw)} columns")

  # Step 2: Standardize column names
  df <- df_raw |> standardize_names()

  # Step 3-7: Apply your cleaning transformations
  # TODO: Customize this section for your specific dataset
  df_clean <- df |>
    # Example: Select and rename columns
    # select(
    #   id = codigo_id,
    #   date = data_transacao,
    #   value = valor,
    #   description = descricao
    # ) |>

    # Example: Parse Brazilian format numbers
    # mutate(
    #   value = parse_br_number(value)
    # ) |>

    # Example: Parse dates
    # mutate(
    #   date = parse_br_date(date)
    # ) |>

    # Example: Clean text fields
    # mutate(
    #   across(where(is.character), clean_text)
    # ) |>

    # Example: Clean document numbers
    # mutate(
    #   cpf = clean_cpf(cpf),
    #   cnpj = clean_cnpj(cnpj)
    # ) |>

    # Example: Handle missing values
    # mutate(
    #   value = if_else(value < 0, NA_real_, value)
    # ) |>

    # Step 8: Add metadata
    mutate(
      ano = file_name, # or extract from file_name if it's a year
      data_processamento = Sys.Date()
    )

  # Quality check
  cli_alert_info("Cleaned: {nrow(df_clean)} rows × {ncol(df_clean)} columns")

  missing_pct <- df_clean |>
    summarise(across(everything(), \(x) mean(is.na(x)) * 100)) |>
    pivot_longer(everything()) |>
    filter(value > 0) |>
    nrow()

  if (missing_pct > 0) {
    cli_alert_warning("{missing_pct} column{?s} with missing values")
  }

  return(df_clean)
}

# ============================================================================
# Main Cleaning Process
# ============================================================================

cli_h2("Cleaning {length(files_to_process)} file{?s}")

all_data <- list()

for (file_name in files_to_process) {
  df_clean <- clean_single_file(file_name)

  if (!is.null(df_clean)) {
    # Save individual file
    output_file <- here("processed", paste0("clean_", file_name, ".parquet"))
    write_parquet(df_clean, output_file)

    size_mb <- file_size(output_file) |> as.numeric() / 1024^2
    cli_alert_success(
      "Saved {.file {basename(output_file)}} ({round(size_mb, 1)} MB)"
    )

    all_data[[file_name]] <- df_clean
  }

  # Memory management for large datasets
  gc(verbose = FALSE)
}

# ============================================================================
# Combine All Files (if applicable)
# ============================================================================

if (length(all_data) > 1) {
  cli_h2("Combining all files")

  df_combined <- bind_rows(all_data)

  cli_alert_info(
    "Combined dataset: {nrow(df_combined)} rows × {ncol(df_combined)} columns"
  )

  if ("ano" %in% names(df_combined)) {
    year_summary <- df_combined |>
      summarise(n = n(), .by = ano) |>
      arrange(ano)

    cli_alert_info("Years: {paste(year_summary$ano, collapse = ', ')}")
  }

  # Save combined dataset
  output_combined <- here("processed", "clean_combined.parquet")
  write_parquet(df_combined, output_combined)

  size_mb <- file_size(output_combined) |> as.numeric() / 1024^2
  cli_alert_success(
    "Saved {.file {basename(output_combined)}} ({round(size_mb, 1)} MB)"
  )
}

# ============================================================================
# Data Quality Summary
# ============================================================================

cli_h2("Data Quality Summary")

if (exists("df_combined")) {
  df_for_summary <- df_combined
} else if (length(all_data) > 0) {
  df_for_summary <- all_data[[1]]
} else {
  df_for_summary <- NULL
}

if (!is.null(df_for_summary)) {
  # Missing values summary
  missing_summary <- df_for_summary |>
    summarise(across(everything(), \(x) sum(is.na(x)))) |>
    pivot_longer(everything(), names_to = "column", values_to = "n_missing") |>
    mutate(pct_missing = round(n_missing / nrow(df_for_summary) * 100, 2)) |>
    filter(n_missing > 0) |>
    arrange(desc(pct_missing))

  if (nrow(missing_summary) > 0) {
    cli_alert_warning("Columns with missing values:")
    print(missing_summary, n = 10)
  } else {
    cli_alert_success("No missing values detected")
  }

  # Data type summary
  type_summary <- tibble(
    column = names(df_for_summary),
    type = sapply(df_for_summary, \(x) class(x)[1])
  ) |>
    summarise(n = n(), .by = type)

  cli_alert_info("Column types:")
  print(type_summary)
}

# Save cleaning metadata
cleaning_metadata <- list(
  cleaning_date = Sys.time(),
  files_processed = files_to_process,
  output_files = list.files(here("processed"), pattern = "\\.parquet$")
)

saveRDS(cleaning_metadata, here("processed", "cleaning_metadata.rds"))

# ============================================================================
# Cleanup
# ============================================================================

cli_alert_info("Completed at {Sys.time()}")
cli_alert_info("Log saved to {.file {log_file}}")

sink(type = "message")
sink(type = "output")
close(log_con)

cli_alert_success("Cleaning complete!")
