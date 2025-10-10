# Insper CiDados

<div align="center">

![GitHub](https://img.shields.io/github/license/insper-cidades/inspercidados)
![R Version](https://img.shields.io/badge/R-%3E%3D%204.0.0-blue)
![GitHub Stars](https://img.shields.io/github/stars/insper-cidades/inspercidados?style=social)

**[English](#english) | [Português](#português)**

</div>

---

### About

The **inspercidados** R package facilitates standardized and reproducible access to Brazilian public datasets. All available datasets have been processed by researchers at Insper Cidades and utilized in published academic papers. This repository provides processing scripts, comprehensive documentation, and streamlined access to the final datasets, ensuring complete transparency and scientific reproducibility.

- Automatic download of official datasets.
- Consistent standardization and cleaning.
- Complete academic citation system.
- Detailed metadata.
- Reproducible data pipelines.

### 🚀 Quick Installation

```r
# Install 'remotes' if necessary
# install.packages("remotes")
remotes::install_github("insper-cidades/inspercidados")
```

### Available Data

| Dataset | Descrição | Anos | Tamanho |
|---------|-----------|------|---------|
| `iptu_sp` | Imposto Predial e Territorial Urbano | 2010-2024
| `itbi_sp` | Imposto sobre Transmissão de Bens Imóveis | 2010-2024
| `alvaras_sp` | Alvarás de Construção | 2015-2024
| `pemob` | Pesquisa de Mobilidade (SIMU) | 2019-2024 
| `pod_sp` | Pesquisa Origem-Destino | 2017, 2022

### Usage Example

```r
library(inspercidados)
library(tidyverse)

# Load São Paulo property tax data for 2024
iptu <- get_dataset("iptu_sp", year = 2024)

# Generate citation for your paper
cite_dataset("iptu_sp", year = 2024, format = "bibtex")
```

### Documentation

- [Quick Start Guide](https://insper-cidades.github.io/inspercidados/articles/quick-start.html)
- [Function Reference](https://insper-cidades.github.io/inspercidados/reference/)
- [Research Best Practices](./RESEARCH_GUIDELINES.md)
- [Contributing Guide](./CONTRIBUTING.md)

--

### Sobre

O **inspercidados** é um pacote de R que facilita o acesso a dados públicos urbanos brasileiros de forma padronizada e reprodutível. Os conjuntos de dados disponíveis foram processados por pesquisadores do Insper Cidades e utilizados em trabalhos acadêmicos publicados. Este repositório oferece os scripts de processamento, documentação completa e acesso simplificado aos dados finais, garantindo total transparência e reprodutibilidade científica.

Desenvolvido pelo [Insper Cidades](https://www.insper.edu.br/pt/pesquisa/centro-de-estudos-das-cidades), o pacote oferece:

- Download automático de datasets tratados.
- Sistema completo de citação acadêmica.
- Metadados e documentação detalhados.
- Pipelines de dados reprodutíveis.

### Instalação Rápida

```r
# Via GitHub (recomendado)
remotes::install_github("insper-cidades/inspercidados")
```

### Dados Disponíveis

#### São Paulo (SP)
| Dataset | Descrição | Anos |
|---------|-----------|------|
| `iptu_sp` | Imposto Predial e Territorial Urbano | 2010-2024
| `itbi_sp` | Imposto sobre Transmissão de Bens Imóveis | 2010-2024
| `alvaras_sp` | Alvarás de Construção | 2015-2024
| `pemob` | Pesquisa de Mobilidade (SIMU) | 2019-2024 
| `pod_sp` | Pesquisa Origem-Destino | 2017, 2022

### Exemplo de Uso

```r
library(inspercidados)

# Carregar IPTU de São Paulo 2024
iptu <- get_dataset("iptu_sp", year = 2024)

# Gerar citação para artigo
cite_dataset("iptu_sp", year = 2024, format = "bibtex")
```

---

## Licença | License

MIT © [Insper Cidades](https://www.insper.edu.br/cidades)

## Agradecimentos | Acknowledgments

Agradecemos a todos os pesquisadores que compartilharam seus scripts e conhecimento para tornar os dados públicos mais acessíveis.

*We thank all researchers who shared their scripts and knowledge to make public data more accessible.*

---

<div align="center">

**Insper**
São Paulo, Brasil 🇧🇷

[Website](https://insper.edu.br/cidades) • [Email](mailto:cidades@insper.edu.br) • [Twitter](https://twitter.com/inspercidades)

</div>
