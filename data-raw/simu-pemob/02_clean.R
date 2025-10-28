library(readxl)
library(tidyverse)
library(cli)
import::from(here, here)
import::from(readxl, read_excel)
import::from(janitor, clean_names, make_clean_names)

header_to_dictionary <- function(x) {
  as_tibble(as.data.frame(t(as.matrix(x))))
}


# Data --------------------------------------------------------------------

munis <- geobr::read_municipality(year = 2022, showProgress = FALSE)
dim_muni <- as_tibble(sf::st_drop_geometry(munis))


## Dictionaries ------------------------------------------------------------

keydict <- read_excel(here("data-raw/pemob_códigos.xlsx"))

keydict <- keydict |>
  clean_names() |>
  fill(c(bloco, secao))

keydict <- keydict |>
  rename(
    srv_block = bloco,
    srv_section = secao
  )

dict_insper <- read_excel(here("data-raw/Pemob_Renomeado_2024.xlsx"), skip = 3)

class_data <- read_excel(
  here("data-raw/Pemob_Renomeado_2024.xlsx"),
  range = "D1:NH4",
  col_names = FALSE,
  .name_repair = make_clean_names
)

class_insper <- as_tibble(as.data.frame(t(as.matrix(class_data))))
names(class_insper) <- c("tema", "subtema", "variavel", "codigo_variavel")

## PEMOB data --------------------------------------------------------------

path_excel_files <- list.files(
  here("data-raw"),
  pattern = "\\.xlsx$",
  full.names = TRUE
)

path_pemob <- path_excel_files[
  !str_detect(path_excel_files, "códigos|Renomeado")
]

na_excel <- c("#REF!", "NR", "NA", "ND", "-")

vl_names <- c(
  "code_muni" = "Código IBGE",
  "code_muni" = "CÓDIGO IBGE",
  "code_muni" = "\r\n Código IBGE",
  "code_muni" = "CÓDIGO",
  "abbrev_state" = "\r\n UF",
  "abbrev_state" = "UF",
  "name_muni" = "\r\n Município",
  "name_muni" = "Município",
  "name_muni" = "MUNICÍPIO",
  "name_muni" = "MUNICIPIO"
)

### 2019 --------------------------------------------------------------------

path_19 <- here("data-raw/Pemob2019_Municipal.xlsx")

pemob19 <- read_excel(path_19, skip = 1, na = na_excel)

id_cols <- c("code_muni", "abbrev_state", "name_muni")

pemob19 <- pemob19 |>
  rename(any_of(vl_names)) |>
  mutate(code_muni = as.numeric(code_muni))

make_clean_names_pemob <- function(x) {
  stringr::str_squish(stringr::str_remove(x, "\\.\\.\\.[0-9]{1,3}"))
}

names(pemob19) <- str_squish(str_remove(names(pemob19), "\\.\\.\\.[0-9]{1,3}"))

dict19 <- read_excel(
  path_19,
  range = "D1:QH2",
  col_names = FALSE,
  .name_repair = make_clean_names
)

dict19 <- header_to_dictionary(dict19)
names(dict19) <- c("name_variable", "code_variable")

survey19 <- read_excel(path_19, sheet = 2, .name_repair = make_clean_names)
names(survey19) <- c(
  "srv_block",
  "srv_block_name",
  "srv_section",
  "srv_section_name",
  "srv_code",
  "srv_question"
)

survey19 <- survey19 |>
  fill(everything()) |>
  mutate(across(where(is.character), str_squish))

### 2020 --------------------------------------------------------------------

path_20 <- here("data-raw/BancodeDados_PemobMunicipal_2020.xlsx")

pemob20 <- read_excel(path_20, na = na_excel)
# Nomes duplicados!
#- Acredito que 4.4.1 (repetido) deveria ser 4.5.1
#- Acredito que 4.4.2 (repetido) deveria ser 4.5.2
#- Acredito que 4.5.1 (errado) deveria ser 4.6.1
names(pemob20)[101] <- "4.5.1"
names(pemob20)[102] <- "4.5.2"
names(pemob20)[103] <- "4.6.1"

pemob20 <- pemob20 |>
  rename(any_of(vl_names)) |>
  rename_with(make_clean_names_pemob)

# Survey contém erros

survey20 <- read_excel(path_20, sheet = 2, .name_repair = make_clean_names)
names(survey20) <- c(
  "srv_block",
  "srv_block_name",
  "srv_section",
  "srv_section_name",
  "srv_code",
  "srv_question"
)

survey20 <- survey20 |>
  fill(everything()) |>
  mutate(across(where(is.character), str_squish))

### 2021 --------------------------------------------------------------------

path_21 <- here("data-raw/pemob21_municipal.xlsx")

pemob21 <- read_excel(path_21, skip = 1, na = na_excel)

pemob21 <- pemob21 |>
  rename(any_of(vl_names))

dict21 <- read_excel(
  path_21,
  range = "E1:RE2",
  col_names = FALSE,
  .name_repair = make_clean_names
)
dict21 <- header_to_dictionary(dict21)
names(dict21) <- c("name_variable", "code_variable")

# Não tem survey

### 2022 --------------------------------------------------------------------

path_22 <- here("data-raw/copy_of_pemob_municipal_2022.xlsx")

pemob22 <- read_excel(path_22, skip = 1, na = na_excel)

pemob22 <- pemob22 |>
  rename(any_of(vl_names))

dict22 <- read_excel(
  path_22,
  range = "D1:RF2",
  col_names = FALSE,
  .name_repair = make_clean_names
)
dict22 <- header_to_dictionary(dict22)
names(dict22) <- c("name_variable", "code_variable")

# Não tem survey

### 2023 --------------------------------------------------------------------

path_23 <- here("data-raw/pemob2023_municipal.xlsx")

pemob23 <- read_excel(path_23, skip = 1, na = na_excel)

pemob23 <- pemob23 |>
  rename(any_of(vl_names)) |>
  mutate(`11.2.2.B` = janitor::excel_numeric_to_date(`11.2.2.B`))


dict23 <- read_excel(
  path_23,
  range = "E1:OY2",
  col_names = FALSE,
  .name_repair = make_clean_names
)
dict23 <- header_to_dictionary(dict23)
names(dict23) <- c("name_variable", "code_variable")

### 2024 --------------------------------------------------------------------

path_24 <- here("data-raw/pemob_municipal_2024.xlsx")

pemob24 <- read_excel(path_24, skip = 1, na = na_excel)

pemob24 <- pemob24 |>
  rename(any_of(vl_names))

dict24 <- read_excel(
  path_24,
  range = "D1:RG2",
  col_names = FALSE,
  .name_repair = make_clean_names
)
dict24 <- header_to_dictionary(dict24)
names(dict24) <- c("name_variable", "code_variable")

# as_numeric_percent <- function(x) {
#
#   if (!any(str_detect(x, "%"))) {
#     return(x)
#   }
#
#   ifelse(
#     str_detect(x, "%"),
#     as.numeric(str_extract(x, ".+(?=%)")),
#     as.numeric(x)
#   )
#
# }
#
# pemob24[, sapply(pemob24, \(x) isTRUE(any(str_detect(x, "[0-9]{1}%$"))))]

## Export dictionaries -----------------------------------------------------

pemob_dictionaries <- mget(ls(pattern = "^dict[0-9]{2}"))

for (i in seq_along(pemob_dictionaries)) {
  dict <- pemob_dictionaries[[i]]
  year <- stringr::str_extract(names(pemob_dictionaries)[[i]], "[0-9]{2}")
  year <- paste0("20", year)
  name_file <- str_glue("dicionario_variaveis_pemob_{year}.csv")
  path_file <- here("data", name_file)

  if (file.exists(path_file)) {
    message("File ", name_file, " already exists. Skipping")
  } else {
    readr::write_csv(dict, path_file)
    message("Exported file to: ", path_file)
  }
}

## Harmonization -----------------------------------------------------------

### Functions and dictionary ------------------------------------------------

lkey <- keydict |>
  pivot_longer(cols = starts_with("x"), names_to = "year", values_to = "key")

lkey <- lkey |>
  mutate(year = as.numeric(str_remove(year, "^x")))

pemobs <- list(pemob24, pemob23, pemob22, pemob21, pemob20, pemob19)
names(pemobs) <- rev(paste0("year_", 2019:2024))
sel_cols <- rev(paste0("x", 2019:2024))

get_inds <- function(dat) {
  inds <- dat |>
    select(all_of(sel_cols)) |>
    as.matrix() |>
    t() |>
    as.character()

  return(inds)
}

pemob_get_variable <- function(var) {
  # browser()
  # Validate input
  cli_h1("Retrieving Variable: {var}")

  # Find row in keydict
  row <- subset(keydict, x2024 == var)

  # Enhanced error checking with cli
  if (nrow(row) == 0) {
    cli_abort("Variable {.val {var}} not found in keydict")
  }

  if (nrow(row) > 1) {
    cli_abort("Multiple entries found for variable {.val {var}}")
  }

  # Get indicators
  inds <- get_inds(row)
  ref_col_name <- row[["x2024"]]

  # Extract data with progress tracking
  ls <- map2(pemobs, inds, \(x, y) {
    if (is.na(y)) {
      return(NULL)
    } else {
      dat <- select(x, code_muni, any_of(y))
    }

    if (ncol(dat) == 2) {
      return(dat)
    } else {
      return(NULL)
    }
  })

  # Handle missing years with cli warning
  missing_years <- names(ls[sapply(ls, is.null)])

  if (length(missing_years) > 0) {
    cli_warn(c(
      "Variable has missing years",
      "*" = "Missing in years: {str_remove(missing_years, 'year_')}"
    ))
  }

  # Filter out NULL entries
  ls <- ls[!sapply(ls, is.null)]

  ref_class <- class(ls$year_2024[[var]])

  if (is.POSIXct(ls$year_2024[[var]])) {
    ref_class <- "character"
  }

  # Rename columns
  stacked <- map2(ls, names(ls), \(x, y) {
    names(x)[2] <- y
    x[[2]] <- do.call(paste0("as.", ref_class), list(x[[2]]))
    return(x)
  })

  # Join and reshape
  tbl <- reduce(stacked, left_join, by = "code_muni")

  result <- tbl |>
    pivot_longer(
      cols = starts_with("year"),
      names_to = "year",
      values_to = ref_col_name
    ) |>
    mutate(year = as.numeric(str_remove(year, "year_"))) |>
    arrange(code_muni, year)

  # Final cli message
  cli_alert_success("Successfully retrieved {.val {var}} data")

  return(result)
}


safe_pemob_get_variable <- function(var) {
  # Wrap the original function with safely()
  safe_func <- safely(pemob_get_variable)

  # Execute with cli progress and error handling
  cli_progress_step("Processing {.val {var}}")

  result <- safe_func(var)

  # Check for errors
  if (!is.null(result$error)) {
    cli_alert_danger("Error processing {.val {var}}:")
    cli_text(result$error$message)
    return(NULL)
  }

  return(result$result)
}


### Harmonize datasets ------------------------------------------------------

# Create the full list with error handling
iter_pemob <- map(keydict$x2024, safe_pemob_get_variable)

# Check for errors
prob_inds <- which(sapply(iter_pemob, is.null))
if (length(prob_inds) > 0) {
  warning("Null results: ", paste(prob_inds, collapse = ", "))
}

# Combine list into a single table
full_pemob <- reduce(iter_pemob, full_join, by = c("code_muni", "year"))

# Add identification columns for PEMOB
id_cols <- names(dim_muni)

full_pemob <- full_pemob |>
  left_join(dim_muni, by = "code_muni") |>
  select(all_of(id_cols), everything())

# Export
readr::write_excel_csv2(full_pemob, "data/pemob_harmonizada_2024.csv")
