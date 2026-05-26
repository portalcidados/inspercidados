#' Open or download the R script for a dataset
#'
#' Downloads a companion R script for a dataset from GitHub and optionally
#' opens it in your editor. Two script types are available:
#'
#' - `"analysis"` (default): a getting-started script demonstrating how to
#'   load, explore, and work with the dataset.
#' - `"replication"`: the production pipeline that generated the dataset.
#'   These scripts document the full data-processing workflow for
#'   reproducibility; they typically require internal resources (private
#'   databases, dimension tables) and **cannot be run by external users**.
#'
#' @param dataset An alias registered in the package registry
#'   (see [list_datasets()]). Full DOIs are not supported here because scripts
#'   are stored by alias.
#' @param type One of `"analysis"` (default) or `"replication"`. See Details.
#' @param open Logical. If `TRUE` (default), open the script in your editor
#'   after downloading. In RStudio the file opens in a proper editor tab; in
#'   other environments `utils::file.edit()` is used.
#'
#' @return The local path to the downloaded script file (invisible). You can
#'   `source()` it directly if you prefer not to open it in an editor.
#'
#' @export
#' @examples
#' \dontrun{
#' # Open an analysis script in editor
#' get_script("embarques_mensais")
#'
#' # Open the replication script (documents how the data was produced)
#' get_script("embarques_mensais", type = "replication")
#'
#' # Download only and source it
#' path <- get_script("embarques_mensais", open = FALSE)
#' source(path)
#' }
get_script <- function(dataset, type = c("analysis", "replication"), open = TRUE) {
  type <- match.arg(type)
  reg  <- read_registry()

  if (!dataset %in% names(reg)) {
    cli::cli_abort(c(
      "Dataset {.val {dataset}} not found in the registry.",
      "i" = "Run {.run inspercidados::list_datasets()} to see available aliases.",
      "i" = "{.fn get_script} only accepts aliases, not DOIs."
    ))
  }

  url_field  <- if (type == "replication") "replication_url" else "script_url"
  script_url <- reg[[dataset]][[url_field]]

  if (is.null(script_url) || !nzchar(script_url)) {
    type_label <- if (type == "replication") "replication script" else "analysis script"
    cli::cli_abort(c(
      "No {type_label} is available for {.val {dataset}} yet.",
      "i" = "Scripts are added over time as datasets are documented."
    ))
  }

  suffix <- if (type == "replication") "_replication" else ""
  tmp    <- tempfile(pattern = paste0(dataset, suffix, "_"), fileext = ".R")
  utils::download.file(script_url, destfile = tmp, quiet = TRUE, mode = "wb")

  cli::cli_inform(c("v" = "Script downloaded to {.path {tmp}}"))

  if (open) {
    open_in_editor(tmp)
  }

  invisible(tmp)
}

open_in_editor <- function(path) {
  if (rlang::is_installed("rstudioapi") && rstudioapi::isAvailable()) {
    rstudioapi::navigateToFile(path)
  } else {
    utils::file.edit(path)
  }
}
