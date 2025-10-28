# ============================================================================
# 01_download.R - Download raw data
#
# Dataset: [DATASET NAME]
# Author: [Your Name]
# Date: [YYYY-MM-DD]
#
# This script downloads raw data from the original source.
# ============================================================================

# Load packages ---------------------------------------------------------------
library(httr2)
library(here)
library(fs)
library(cli)

# Setup -----------------------------------------------------------------------
dir_create(here("data/raw"))
cli_h1("Download Process")
cli_alert_info("Started at {Sys.time()}")

# Caution --------------------------------------------------------------------------
# Before trying to download or webscrape files check if:
# 1. The data is available on some API
# 2. The data is available in some R package (sidrar, rbcb, geobr, censobr, etc.)

# ============================================================================
# CUSTOMIZE THIS SECTION
# ============================================================================

# Define source URLs for each year/file you need
urls <- list(
  # Example:
  # "2024" = "https://dados.gov.br/dataset/example/2024.zip",
  # "2023" = "https://dados.gov.br/dataset/example/2023.zip"
)

# Download configuration
config <- list(
  timeout = 600, # Seconds (10 minutes)
  retries = 3,
  retry_delay = 5, # Seconds between retries
  user_agent = "inspercidados R Package (cidades@insper.edu.br)"
)

# ============================================================================
# Helper Functions
# ============================================================================

#' Download a single file with retry logic using httr2
#' @param url Source URL
#' @param dest_path Destination file path
#' @param retries Number of retry attempts
download_file <- function(url, dest_path, retries = 3) {
  for (attempt in seq_len(retries)) {
    cli_alert_info("Attempt {attempt}/{retries}: {.file {basename(dest_path)}}")

    result <- tryCatch(
      {
        request(url) |>
          req_timeout(config$timeout) |>
          req_user_agent(config$user_agent) |>
          req_retry(max_tries = 1) |>
          req_perform(path = dest_path)

        TRUE
      },
      error = \(e) {
        cli_alert_warning("Download failed: {e$message}")
        FALSE
      }
    )

    if (result) {
      size_mb <- file_size(dest_path) |> as.numeric() / 1024^2
      cli_alert_success(
        "Downloaded {.file {basename(dest_path)}} ({round(size_mb, 1)} MB)"
      )
      return(TRUE)
    }

    if (attempt < retries) {
      cli_alert_info("Retrying in {config$retry_delay} seconds...")
      Sys.sleep(config$retry_delay)
    }
  }

  cli_alert_danger(
    "Failed after {retries} attempts: {.file {basename(dest_path)}}"
  )
  FALSE
}

#' Extract zip file if needed
#' @param file_path Path to file
#' @param extract_dir Directory to extract to
extract_if_zip <- function(file_path, extract_dir) {
  if (path_ext(file_path) == "zip") {
    cli_alert_info("Extracting {.file {basename(file_path)}}...")
    dir_create(extract_dir)
    unzip(file_path, exdir = extract_dir, junkpaths = FALSE)
    cli_alert_success("Extracted to {.path {extract_dir}}")
  }
}

# ============================================================================
# Main Download Process
# ============================================================================

if (length(urls) == 0) {
  cli_alert_warning(
    "No URLs configured. Please add URLs to the {.var urls} list."
  )
  cli_alert_info("See the CUSTOMIZE THIS SECTION above.")
  sink(type = "message")
  sink(type = "output")
  close(log_con)
  stop("No URLs to download", call. = FALSE)
}

cli_h2("Downloading {length(urls)} file{?s}")

download_status <- list()

for (name in names(urls)) {
  dest_file <- here("raw", paste0("data_", name, path_ext(urls[[name]])))

  success <- download_file(
    url = urls[[name]],
    dest_path = dest_file,
    retries = config$retries
  )

  download_status[[name]] <- success

  if (success) {
    extract_if_zip(dest_file, here("raw", name))
  }
}

# ============================================================================
# Summary
# ============================================================================

cli_h2("Download Summary")

successful <- sum(unlist(download_status))
failed <- sum(!unlist(download_status))

cli_alert_success("{successful} file{?s} downloaded successfully")
if (failed > 0) {
  cli_alert_danger("{failed} file{?s} failed to download")
  cli_ul(names(download_status)[!unlist(download_status)])
}

# Save download metadata
download_metadata <- tibble::tibble(
  name = names(download_status),
  success = unlist(download_status),
  download_date = Sys.time()
)

saveRDS(download_metadata, here("raw", "download_metadata.rds"))

# ============================================================================
# Cleanup
# ============================================================================

cli_alert_info("Completed at {Sys.time()}")
cli_alert_info("Log saved to {.file {log_file}}")

sink(type = "message")
sink(type = "output")
close(log_con)

if (failed > 0) {
  stop("Some downloads failed. Check log file for details.", call. = FALSE)
}
