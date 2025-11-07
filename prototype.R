#' Download and Extract Data from Insper Dataverse
#'
#' Downloads a ZIP file from Insper's Dataverse repository, extracts the CSV,
#' and returns the data as a tibble.
#'
#' @param name Character. Name of the ZIP file in the Dataverse repository
#' @param dataset Character. DOI of the dataset (format: "10.60873/FK2/XXXXX")
#' @return A tibble containing the extracted CSV data
#' @noRd
get_data <- function(name, dataset) {
  file_name <- gsub("\\..+", "", name)

  # Internal function to extract CSV from ZIP archive
  unzip_csv <- function(x) {
    datadir <- tempdir()

    # Extract ZIP contents to temp directory
    utils::unzip(x, exdir = datadir)

    # Find CSV file in extracted folder
    path <- list.files(
      file.path(datadir, file_name),
      pattern = "\\.csv$",
      full.names = TRUE
    )

    # Warn if multiple CSVs found
    if (length(path) > 1) {
      cli::cli_warn(
        "Multiple CSV files found in {.file {x}}. Defaulting to first."
      )
    }

    cli::cli_alert_info("Importing {.file {basename(path)}}")

    # Read and return CSV data
    data <- readr::read_csv(path[[1]], show_col_types = FALSE)
    return(data)
  }

  # Download data from Dataverse
  result <- dataverse::get_dataframe_by_name(
    name,
    dataset,
    .f = unzip_csv,
    server = "dataverse.datascience.insper.edu.br"
  )
  cli::cli_alert_success(
    "Downloaded {.file {name}} from DOI: {.url {dataset}}."
  )

  return(result)
}

# Download Recife Bus Data ----------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)
library(dataverse)

# Bus lines: Information about all bus lines in Greater Recife
# Source: Insper - Observatório Nacional de Mobilidade Sustentável
rec_buslines <- get_data(
  "4-linhas-onibus.zip",
  "10.60873/FK2/TLFP8L"
)

# Passengers: Daily passenger counts by bus line
# Source: Insper - Observatório Nacional de Mobilidade Sustentável
rec_passengers <- get_data(
  "3-passageiros-transportados.zip",
  "10.60873/FK2/JEYM0J"
)
