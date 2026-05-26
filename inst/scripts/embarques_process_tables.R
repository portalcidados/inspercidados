# =============================================================================
# REPLICATION SCRIPT — Motiva Boarding Tables
#
# Datasets produced:
#   embarques_hora        doi:10.60873/FK2/9MZGJL
#   embarques_diarios     doi:10.60873/FK2/UTGQ0I
#   embarques_mensais     doi:10.60873/FK2/BPYHFB
#   embarques_integracao  doi:10.60873/FK2/UOKFMF
#
# PURPOSE
#   This script documents how the Motiva boarding datasets were produced.
#   It is provided for transparency and reproducibility. External users
#   cannot run it directly — it requires access to Insper's private
#   Motiva database and local dimension tables.
#
# REQUIREMENTS (Insper internal only)
#   - Database connection via connect_server("motiva")
#   - Dimension tables: data/dim_station.rds, data/dim_line.rds
#   - Helper scripts:   R/connect_server.R, R/export_table.R
#
# Contact: cidades@insper.edu.br
# =============================================================================

# Process Motiva datasets ------------------------------------------------
# Tables: emb_diarios, emb_mensais, emb_modo, emb_media
# Tables 1-4

# Setup ------------------------------------------------------------------

## Libraries -------------------------------------------------------------
library(dplyr)
library(dbplyr)
library(stringr)
import::from(tidyr, pivot_longer)
import::from(janitor, clean_names)
import::from(readr, parse_date, read_rds)
import::from(lubridate, make_date)
import::from(here, here)

source(here("R/connect_server.R"))
source(here("R/export_table.R"))

## Helper functions -------------------------------------------------------

# Get all station names quickly
get_station_names <- function(dat) {
  get_stn_names <- lapply(tabelas, \(x) {
    if ("station_name" %in% names(x)) {
      return(unique(x$station_name))
    } else {
      return(NA_character_)
    }
  })
}

# Fix stations names
fix_station_names <- function(x) {
  # Manually swap names
  swap_stations <- c(
    "Aguas Claras" = "Águas Claras / Cajazeiras",
    "AC NORTE" = "Acesso Norte",
    "BOM JUA" = "Bom Juá",
    "Bom Jua" = "Bom Juá",
    "PERNAMBUES" = "Pernambués",
    "Pernambues" = "Pernambués",
    "IMBUI" = "Imbuí",
    "PITUACU" = "Pituaçu",
    "Pituacu" = "Pituaçu",
    "PÓLVORA" = "Campo Da Pólvora",
    "CAMPO DA POLVORA" = "Campo Da Pólvora",
    "Campo da Polvora" = "Campo Da Pólvora",
    "Detran" = "DETRAN",
    "RODOVIARIA" = "Rodoviária",
    "Rodoviaria" = "Rodoviária",
    "Imbui" = "Imbuí",
    "PIRAJA" = "Pirajá",
    "Piraja" = "Pirajá",
    "BONOCO" = "Bonocô",
    "Bonoco" = "Bonocô",
    "SP - MORUMBI" = "São Paulo - Morumbi",
    "MORUMBI" = "Morumbi - Claro",
    "BARRA FUNDA" = "Palmeiras - Barra Funda",
    "JAGUARÉ" = "Villa Lobos - Jaguaré",
    "CHACARA KLABIN" = "Chácara Klabin",
    "HEBRAICA REBOUCAS" = "Hebraica - Rebouças",
    "CAPAO REDONDO" = "Capão Redondo",
    "JURUBATUBA" = "Jurubatuba - Senac",
    "HOSPITAL SAO PAULO" = "Hospital São Paulo",
    "INTERLAGOS" = "Primavera - Interlagos",
    "MENDES - VILA NATAL" = "Bruno Covas - Mendes - Vila Natal",
    "ANTÔNIO JOÃO" = "Antonio João",
    "HEBRAICA REBOUÇAS" = "Hebraica - Rebouças",
    "JAGUARÉ" = "Villa Lobos - Jaguaré",
    "AACD - SERVIDOR" = "AACD - Servidor"
  )

  # Add exceptions that should remiain capitalized
  keep_caps <- c("^DETRAN$", "^CAB$")
  pat_caps <- paste(keep_caps, collapse = "|")

  str_to_title_mod <- Vectorize(function(x) {
    if (str_detect(x, pat_caps)) {
      return(x)
    } else {
      return(str_to_title(x))
    }
  })

  # Replace names
  y <- str_replace_all(x, swap_stations)
  # Add whitespace between letters and -
  y <- str_replace_all(y, "([A-z])-([A-z])", "\\1 - \\2")
  # Apply str_to_title with exceptions
  y <- str_to_title_mod(y)

  return(y)
}

# Wrapper around fix_station_names
# Adds some more exceptions
clean_station_names <- function(dat) {
  if ("station_name" %in% names(dat)) {
    dat |>
      mutate(
        fixed_station_name = case_when(
          # OBS: there is no clear dim_table for VLT Carioca stations
          business_unit == "VLT Carioca" ~ str_to_upper(station_name),
          # Easier to fix like this
          station_name == "AACD - SERVIDOR" ~ "AACD - Servidor",
          # Add NAs where there is no station name
          station_name == "" ~ NA_character_,
          TRUE ~ fix_station_names(station_name)
        )
      )
  } else {
    return(dat)
  }
}

# Wrapper around clean_station_names
# Drastically increases speed
# Creates a lookup table to fix names and joins with original table
# Returns cleaned table with new names
clean_table_station_names <- function(dat) {
  if (!"station_name" %in% names(dat)) {
    return(dat)
  }

  tbl_replace_names <- dat |>
    distinct(business_unit, station_name) |>
    clean_station_names()

  clean_dat <- dat |>
    left_join(tbl_replace_names, by = join_by(business_unit, station_name)) |>
    select(-station_name) |>
    rename(station_name = fixed_station_name) |>
    mutate(
      station_name = if_else(station_name == "", NA_character_, station_name)
    )

  return(clean_dat)
}

# Fix business unit names
fix_bunames <- function(x) {
  # Manually swap names
  swap_bunames <- c(
    "METROBAHIA" = "Metrô Bahia",
    "Metrobahia" = "Metrô Bahia",
    "VIAQUATRO" = "ViaQuatro",
    "VIAMOBILIDADE_L5" = "ViaMobilidade - Linha 5",
    "VIAMOBILIDADE_L8E9" = "ViaMobilidade - Linhas 8 e 9",
    "VLTCARIOCA" = "VLT Carioca"
  )
  # Replace names
  return(stringr::str_replace_all(x, swap_bunames))
}

# Wrapper around collect
collect_table <- function(table_name) {
  if (!table_name %in% DBI::dbListTables(con)) {
    cli::cli_abort("Table {table_name} not found.")
  }

  cli::cli_alert_info("Downloading table {table_name}.")
  # Download all data locally and clean names using janitor
  dat <- dplyr::collect(dplyr::tbl(con, table_name))
  dat <- janitor::clean_names(dat)
  return(dat)
}

## Dimension tables -------------------------------------------------------

### Useful tables for joins

### Make sure these tables are compatible with the data

dim_station <- readr::read_rds(here::here("data/dim_station.rds"))

dim_station <- dim_station |>
  mutate(
    business_unit = case_when(
      system_name == "ViaMobilidade" & line_id == 5 ~ "ViaMobilidade - Linha 5",
      system_name == "ViaMobilidade" ~ "ViaMobilidade - Linhas 8 e 9",
      system_name == "MetroBahia" ~ "Metrô Bahia",
      system_name == "VLT" ~ "VLT Carioca",
      TRUE ~ system_name
    ),
    station_name = case_when(
      station_name == "Campo da Pólvora" ~ "Campo Da Pólvora",
      station_name == "Bairro da Paz" ~ "Bairro Da Paz",
      station_name == "Detran" ~ "DETRAN",
      station_name == "Vila Lobos - Jaguaré" ~ "Villa Lobos - Jaguaré",
      station_name == "AACD Servidor" ~ "AACD - Servidor",
      str_detect(station_name, '( de )|( do )|( da )|( das )') ~ str_to_title(
        station_name
      ),
      TRUE ~ station_name
    ),
    system_name = if_else(system_name == "VLT", "VLT Carioca", system_name),
    system_name = if_else(
      system_name == "MetroBahia",
      "Metrô Bahia",
      system_name
    )
  )

dim_station <- dim_station |>
  mutate(
    station_name = str_replace_all(
      station_name,
      "([A-z])-([A-z])",
      "\\1 - \\2"
    ),
    station_name = str_squish(station_name)
  ) |>
  select(
    system_name,
    business_unit,
    line_id,
    station_name,
    line_order
  ) |>
  arrange(system_name, line_id, line_order)

dim_line <- readr::read_rds(here::here("data/dim_line.rds"))

dim_line <- dim_line |>
  mutate(
    system_name = if_else(system_name == "VLT", "VLT Carioca", system_name),
    business_unit = case_when(
      system_name == "ViaMobilidade" & line_id == 5 ~ "ViaMobilidade - Linha 5",
      system_name == "ViaMobilidade" ~ "ViaMobilidade - Linhas 8 e 9",
      TRUE ~ system_name
    )
  ) |>
  select(
    system_name,
    business_unit,
    line_id,
    line_name,
    line_name_full
  )

# OBS: no way to reliably create a key for VLT stations

# Import -----------------------------------------------------------------

# Connect to database
con <- connect_server("motiva")

# Import all tables
emb_diarios <- collect_table("onms_tabela1")
emb_mensais <- collect_table("onms_tabela2")
emb_modo <- collect_table("onms_tabela3")
emb_media <- collect_table("onms_tabela4")

# Clean ------------------------------------------------------------------

# Standardize column names
rename_cols <- c(
  "business_unit" = "nome_unidade",
  "station_name" = "nmestacao"
)

## Table 1: emb_diarios --------------------------------------------------
emb_diarios <- emb_diarios |>
  rename(any_of(rename_cols)) |>
  mutate(
    hora = as.integer(hora),
    data = readr::parse_date(data, format = "%d-%m-%Y"),
    business_unit = fix_bunames(business_unit)
  )

## Table 2: emb_mensais --------------------------------------------------
emb_mensais <- emb_mensais |>
  rename(any_of(rename_cols)) |>
  mutate(
    business_unit = fix_bunames(business_unit),
    data = readr::parse_date(data, format = "%Y-%m-%d"),
    tipo_embarque = str_to_title(tipo_embarque),
    tipo_embarque = if_else(
      tipo_embarque == "" | tipo_embarque == "-",
      NA_character_,
      tipo_embarque
    )
  )

## Table 3: emb_modo -----------------------------------------------------
emb_modo <- emb_modo |>
  rename(any_of(rename_cols)) |>
  mutate(
    business_unit = fix_bunames(business_unit),
    data = lubridate::make_date(ano, mes, 01),
    tipo_integracao = str_to_title(tipo_integracao)
  ) |>
  select(
    business_unit,
    data,
    tipo_integracao,
    embarques,
    ano,
    mes
  )

## Table 4: emb_media ----------------------------------------------------
emb_media <- emb_media |>
  rename(any_of(rename_cols)) |>
  mutate(
    business_unit = fix_bunames(business_unit),
    data = lubridate::make_date(ano, mes, 01)
  )

emb_media <- emb_media |>
  pivot_longer(
    cols = c(media_du, media_sab, media_dom),
    names_to = "tipo_dia",
    values_to = "embarques_diarios_media"
  ) |>
  mutate(
    tipo_dia = case_when(
      tipo_dia == "media_du" ~ "Dias Úteis",
      tipo_dia == "media_sab" ~ "Sábado",
      tipo_dia == "media_dom" ~ "Domingo"
    ),
    tipo_dia = factor(
      tipo_dia,
      levels = c("Dias Úteis", "Sábado", "Domingo")
    )
  )


## Fix station names -----------------------------------------------------

tabelas <- list(
  "emb_diarios" = emb_diarios,
  "emb_modo" = emb_modo,
  "emb_mensais" = emb_mensais,
  "emb_media" = emb_media
)

# referencia do numero correto
# A tibble: 5 × 2
#   business_unit                    n
#   <chr>                        <int>
# 1 MetroBahia                      21
# 2 VLT                             31
# 3 ViaMobilidade - Linha 5         17
# 4 ViaMobilidade - Linhas 8 e 9    42
# 5 ViaQuatro                       11

tabelas <- furrr::future_map(tabelas, clean_table_station_names)

# Export -----------------------------------------------------------------

## Select columns and export ---------------------------------------------

sel_cols <- list(
  "emb_diarios" = c(
    "business_unit",
    "station_name",
    "data",
    "hora",
    "embarques"
  ),

  "emb_mensais" = c(
    "business_unit",
    "station_name",
    "data",
    "tipo_embarque",
    "embarques"
  ),

  "emb_media" = c(
    "business_unit",
    "station_name",
    "data",
    "tipo_dia",
    "embarques_diarios_media",
    "ano",
    "mes"
  ),

  "emb_modo" = c(
    "business_unit",
    "data",
    "tipo_integracao",
    "embarques",
    "ano",
    "mes"
  )
)

tabelas$emb_diarios <- tabelas$emb_diarios |>
  select(all_of(sel_cols$emb_diarios))

tabelas$emb_mensais <- tabelas$emb_mensais |>
  select(all_of(sel_cols$emb_mensais))

tabelas$emb_modo <- tabelas$emb_modo |>
  select(all_of(sel_cols$emb_modo))

tabelas$emb_media <- tabelas$emb_media |>
  select(all_of(sel_cols$emb_media))

## Export ----------------------------------------------------------------

out_dir <- here("data/processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for (i in seq_along(tabelas)) {
  tabela <- tabelas[[i]]
  export_table(
    tabela,
    out_dir = out_dir,
    file_name = names(tabelas)[i],
    extension = c("csv", "rds", "parquet", "xlsx")
  )
}

readr::write_rds(
  tabelas$emb_diarios,
  here("data/processed/emb_diarios.rds"),
  compress = "gz"
)

export_table(
  dim_station,
  out_dir = out_dir,
  file_name = "dim_station",
  c("csv", "rds", "xlsx")
)

export_table(
  dim_line,
  out_dir = out_dir,
  file_name = "dim_line",
  c("csv", "rds", "xlsx")
)
