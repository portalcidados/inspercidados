
<!-- README.md is generated from README.Rmd. Please edit that file -->

# inspercidados

<!-- badges: start -->

<!-- badges: end -->

**inspercidados** provides simple, reproducible access to curated
Brazilian urban research datasets hosted on [Insper’s
Dataverse](https://dataverse.datascience.insper.edu.br). It is a
lightweight wrapper around the
[`dataverse`](https://github.com/IQSS/dataverse-client-r) package that
lets researchers discover, download, and cite datasets with a few short
commands.

## Installation

You can install the development version of inspercidados from
[GitHub](https://github.com/portalcidados/inspercidados) with:

``` r
# install.packages("pak")
pak::pak("portalcidados/inspercidados")
```

## Core functions

| Function          | Purpose                                         |
|-------------------|-------------------------------------------------|
| `list_datasets()` | List or search available datasets               |
| `get_dataset()`   | Download a dataset into R                       |
| `cite_dataset()`  | Generate a citation for a dataset               |
| `get_script()`    | Open a companion analysis or replication script |

## Browse available datasets

`list_datasets()` returns a tibble of all datasets in the package
registry. No network call is made.

``` r
library(inspercidados)

list_datasets()
#> # A tibble: 22 × 7
#>    alias                  title          description theme region keywords doi  
#>    <chr>                  <chr>          <chr>       <chr> <chr>  <chr>    <chr>
#>  1 itbi_sp                Imposto sobre… "Registros… Habi… São P… Residên… 10.6…
#>  2 iptu_sp                Cadastro de i… "Informaçõ… Habi… São P… Residên… 10.6…
#>  3 alvaras_sp             Alvarás de li… "Informaçõ… Habi… São P… Residên… 10.6…
#>  4 censo_setores_sp       População e D… "Dados pro… Habi… São P… CENSO; … 10.6…
#>  5 densidade_vertical_sp  Densidade Pop… "Dados do … Habi… São P… Habitaç… 10.6…
#>  6 iptu_verticalizacao_sp IPTU e Vertic… "Dados dem… Habi… São P… Habitaç… 10.6…
#>  7 densidade_imoveis_sp   Densidade Pop… "Cruzament… Habi… São P… Habitaç… 10.6…
#>  8 geoses_sp              Índice GeoSES… "Índice so… Mult… São P… Índice … 10.6…
#>  9 mortalidade_sp         Mortalidade p… "Medidas d… Saúde São P… Mortali… 10.6…
#> 10 ubs_sp                 Gastos com UB… "Gastos co… Saúde São P… Saúde P… 10.6…
#> # ℹ 12 more rows
```

You can filter by alias, title, theme, region, or keywords:

``` r
list_datasets("Mobilidade")
#> # A tibble: 11 × 7
#>    alias                title            description theme region keywords doi  
#>    <chr>                <chr>            <chr>       <chr> <chr>  <chr>    <chr>
#>  1 geoses_sp            Índice GeoSES [… Índice soc… Mult… São P… Índice … 10.6…
#>  2 pemob_anual          [Anual] Pesquis… Base munic… Mobi… Brasil Mobilid… 10.6…
#>  3 pemob_harmonizada    [Harmonizada] P… A base har… Mobi… Brasil Mobilid… 10.6…
#>  4 embarques_hora       Embarques a cad… Embarques … Mobi… Brasil Transpo… 10.6…
#>  5 embarques_diarios    Embarques diári… Total de e… Mobi… Brasil Transpo… 10.6…
#>  6 embarques_mensais    Médias mensais … Média de e… Mobi… Brasil Transpo… 10.6…
#>  7 embarques_integracao Embarques mensa… Embarques … Mobi… Salva… Transpo… 10.6…
#>  8 estacoes_motiva      Linhas e Estaçõ… Tabela de … Mobi… Brasil Transpo… 10.6…
#>  9 faixa_azul_sp        Trechos com Fai… Localizaçã… Mobi… São P… Mobilid… 10.6…
#> 10 sinistros_sp         Sinistros de Tr… Sinistros … Mobi… São P… Sinistr… 10.6…
#> 11 sinistros_via_sp     Sinistros de Tr… Localizaçã… Mobi… São P… Sinistr… 10.6…
```

## Download a dataset

Datasets can be identified by their short alias, a bare DOI, or a full
DOI URL:

``` r
# By alias
embarques <- get_dataset("embarques_mensais")

# By DOI
embarques <- get_dataset("10.60873/FK2/BPYHFB")

# Filter by year for multi-year datasets
pemob_2023 <- get_dataset("pemob_anual", year = 2023)

# Request a specific file or pattern
geo <- get_dataset("iptu_sp", filename = "iptu_2024.gpkg")
```

Pass `docs = TRUE` to return the dataset together with its
documentation:

``` r
result <- get_dataset("iptu_sp", docs = TRUE)
result$data
result$docs
```

## Cite a dataset

`cite_dataset()` fetches metadata from Dataverse and returns a citation
in plain text (default), BibTeX, or RIS:

``` r
cite_dataset("embarques_mensais")
cite_dataset("embarques_mensais", format = "bibtex")
cite_dataset("embarques_mensais", format = "ris")
```

## Companion R scripts

Some datasets ship with a companion script that demonstrates how to load
and explore the data, or documents the production pipeline that
generated it:

``` r
# Open the analysis script in your editor
get_script("embarques_mensais")

# Open the replication pipeline (typically not runnable by external users)
get_script("embarques_mensais", type = "replication")
```

## Learn more

- `vignette("getting-started", package = "inspercidados")`
- Full reference: <https://portalcidados.github.io/inspercidados>
- Data source: <https://dataverse.datascience.insper.edu.br>
