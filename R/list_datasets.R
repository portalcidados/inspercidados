#' List available datasets
#'
#' Returns a tibble of all datasets available in the `inspercidados` registry.
#' Data comes from the local registry (`inst/datasets.json`) — no network call
#' is made.
#'
#' @param search A character string to filter results. Matched case-insensitively
#'   against alias, title, description, keywords, theme, and region. Pass `NULL`
#'   (default) to return all datasets.
#'
#' @return A [tibble][tibble::tibble] with columns:
#'   \describe{
#'     \item{alias}{Short name used with [get_dataset()], [cite_dataset()], etc.}
#'     \item{title}{Full dataset title (in Portuguese).}
#'     \item{description}{Brief description of the dataset.}
#'     \item{theme}{Thematic category (e.g. `"Habitação"`, `"Mobilidade"`).}
#'     \item{region}{Geographic scope (e.g. `"São Paulo"`, `"Rio de Janeiro"`).}
#'     \item{keywords}{Semicolon-separated keywords.}
#'     \item{doi}{Bare DOI, e.g. `"10.60873/FK2/TOXCRF"`.}
#'   }
#'
#' @export
#' @examples
#' # List all datasets
#' list_datasets()
#'
#' # Search by keyword or theme
#' list_datasets("metro")
#' list_datasets("IPTU")
#' list_datasets("Mobilidade")
list_datasets <- function(search = NULL) {
  reg <- read_registry()

  out <- tibble::tibble(
    alias       = names(reg),
    title       = vapply(reg, function(x) x[["title"]]       %||% NA_character_, character(1)),
    description = vapply(reg, function(x) x[["description"]] %||% NA_character_, character(1)),
    theme        = vapply(reg, function(x) x[["theme"]]        %||% NA_character_, character(1)),
    region      = vapply(reg, function(x) x[["region"]]      %||% NA_character_, character(1)),
    keywords    = vapply(reg, function(x) x[["keywords"]]    %||% NA_character_, character(1)),
    doi         = vapply(reg, function(x) x[["doi"]]         %||% NA_character_, character(1))
  )

  if (!is.null(search)) {
    keep <- grepl(search, out$alias,       ignore.case = TRUE) |
            grepl(search, out$title,       ignore.case = TRUE) |
            grepl(search, out$description, ignore.case = TRUE) |
            grepl(search, out$theme,        ignore.case = TRUE) |
            grepl(search, out$region,      ignore.case = TRUE) |
            grepl(search, out$keywords,    ignore.case = TRUE)
    out <- out[keep, ]
    if (nrow(out) == 0) {
      cli::cli_inform("No datasets matched {.val {search}}.")
    }
  }

  out
}
