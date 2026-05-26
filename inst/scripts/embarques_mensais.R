# Médias mensais de embarques diários — Sistemas Motiva (2012-2025)
# Dataset: embarques_mensais | DOI: 10.60873/FK2/BPYHFB
#
# This script demonstrates how to load and explore the monthly average daily
# boarding data for metro/train systems operated by Motiva (Metro Bahia,
# ViaQuatro, ViaMobilidade, and others).
#
# Source: Motiva / Insper Cidades
# Package: https://github.com/portalcidados/inspercidados

library(inspercidados)
library(dplyr)
library(ggplot2)

# 1. Load dataset ---------------------------------------------------------

embarques <- get_dataset("embarques_mensais")

# Basic inspection
glimpse(embarques)
head(embarques)
summary(embarques)

# 2. Explore structure ----------------------------------------------------

# How many systems are covered?
embarques |> count(sistema, sort = TRUE)

# Date range
embarques |>
  summarise(
    min_ano = min(ano),
    max_ano = max(ano)
  )

# Day types (weekday / saturday / sunday)
embarques |> distinct(dia_tipo)

# 3. Simple time series ---------------------------------------------------

# Total average boardings per year, for working days only
serie_anual <- embarques |>
  filter(dia_tipo == "Dia útil") |>
  group_by(ano, sistema) |>
  summarise(media_anual = mean(media_embarques_diarios, na.rm = TRUE), .groups = "drop")

ggplot(serie_anual, aes(x = ano, y = media_anual, colour = sistema)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Média anual de embarques diários por sistema (dias úteis)",
    x = NULL, y = "Média de embarques", colour = "Sistema"
  ) +
  theme_minimal()

# 4. Seasonality ----------------------------------------------------------

# Average boardings by month (all years combined, working days only)
sazonalidade <- embarques |>
  filter(dia_tipo == "Dia útil") |>
  group_by(mes) |>
  summarise(media = mean(media_embarques_diarios, na.rm = TRUE))

ggplot(sazonalidade, aes(x = mes, y = media)) +
  geom_col(fill = "#1a6bbf") +
  scale_x_continuous(breaks = 1:12, labels = month.abb) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Sazonalidade: média de embarques por mês (todos os anos)",
    x = NULL, y = "Média de embarques"
  ) +
  theme_minimal()

# 5. Cite the dataset -----------------------------------------------------

cite_dataset("embarques_mensais")
