load_all()

doi <- c(
  # GeoSES
  "10.60873/FK2/7IXFPX",
  # Ilhas de Calor
  "10.60873/FK2/NQA7LY",
  # População e domicilios (censo)
  "10.60873/FK2/GTO7DD"
)

# Devolve erro
get_dataset(doi[1])
inspercidados::get_dataset_info(doi[1])

get_dataset_info(doi[3])

get_dataset(doi[3])

list_available_datasets()

# get_dataset(doi)
