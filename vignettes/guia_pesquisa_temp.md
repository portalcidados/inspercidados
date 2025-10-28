

# Guia de Pesquisa e Boas Práticas para Ciência de Dados Urbanos

> Boas práticas para pesquisa urbana reproduzível no Insper Cidades

## Índice
1. [Organização de Projetos](#organização-de-projetos)
2. [Ambientes de Desenvolvimento (IDEs)](#ambientes-de-desenvolvimento-ides)
3. [Convenções Modernas em R](#convenções-modernas-em-r)
4. [Ferramentas de Acesso a Dados](#ferramentas-de-acesso-a-dados)
5. [Pesquisa Assistida por IA](#pesquisa-assistida-por-ia)
6. [Recursos Insper](#recursos-insper)
7. [Referências Essenciais](#referências-essenciais)
8. [Checklist de Reprodutibilidade](#checklist-de-reprodutibilidade)

---

## 🗂️ Organização de Projetos

### Estrutura Recomendada de Projeto

```
seu_projeto/
├── README.md              # Visão geral e instruções do projeto
├── .gitignore            # Arquivo de ignorar do Git
├── renv.lock             # Versões dos pacotes para reprodutibilidade
├── seu_projeto.Rproj     # Arquivo de projeto do RStudio
│
├── data/                 # Arquivos de dados (ignorados no git se grandes)
│   ├── raw/             # Dados originais, imutáveis
│   ├── processed/       # Dados limpos
│   └── final/           # Dados prontos para análise
│
├── R/                    # Scripts R
│   ├── 01_download.R    # Aquisição de dados
│   ├── 02_clean.R       # Limpeza de dados
│   ├── 03_analyze.R     # Análise
│   └── utils.R          # Funções auxiliares
│
├── notebooks/           # Análise exploratória (Quarto/RMarkdown)
│   └── exploratory.qmd
│
├── outputs/             # Resultados
│   ├── figures/        # Gráficos e plots
│   ├── tables/         # Tabelas e sumários
│   └── reports/        # Relatórios/artigos finais
│
├── docs/                # Documentação
│   ├── codebook.md     # Descrição das variáveis
│   └── methods.md      # Metodologia
│
└── tests/              # Testes unitários para funções
    └── test_utils.R
```

### Convenções de Nomenclatura de Arquivos

```r
# Bons exemplos:
01_download_iptu.R
02_limpar_censo_2010.R
03_merge_datasets.R
04_analise_regressao.R

# Evitar:
Script1.R
analise_FINAL_v2_FINAL.R
sem_titulo.R
```

### Boas Práticas de Controle de Versão

```bash
# Mensagens de commit descritivas
git commit -m "Adiciona pipeline de limpeza IPTU 2020-2024"
git commit -m "Corrige problemas de encoding em campos de endereço"

# Mensagens ruins
git commit -m "Atualizações"
git commit -m "asdfasdf"
```

Sempre use `.gitignore` para:
- Arquivos de dados grandes (use Git LFS ou armazenamento externo)
- Credenciais e chaves de API
- Arquivos do sistema operacional (.DS_Store, Thumbs.db)
- Arquivos de sessão R (.Rdata, .Rhistory)

---

## 💻 Ambientes de Desenvolvimento (IDEs)

### RStudio (Recomendado)

O **RStudio** é o IDE mais completo e estabelecido para R:

**Vantagens:**
- ✅ Interface integrada (editor, console, plots, ajuda)
- ✅ Suporte nativo para Quarto/RMarkdown
- ✅ Depurador visual
- ✅ Integração com Git
- ✅ Visualizador de dados interativo
- ✅ Autocompletar inteligente

**Download:** [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop/)

**Configurações recomendadas:**
```r
# Tools → Global Options
# - General → Workspace → Desmarcar "Restore .RData"
# - Code → Display → Marcar "Show margin" (80 caracteres)
# - Code → Saving → Encoding UTF-8
# - Appearance → Tema escuro para reduzir cansaço visual
```

### Positron (Nova Opção)

O **Positron** é o novo IDE da Posit (antiga RStudio) baseado no VS Code:

**Vantagens:**
- ✅ Mais rápido e moderno que RStudio
- ✅ Suporta múltiplas linguagens (R, Python, SQL)
- ✅ Interface familiar para usuários de VS Code
- ✅ Extensões poderosas
- ✅ Melhor para projetos multilinguagem

**Download:** [github.com/posit-dev/positron](https://github.com/posit-dev/positron)

**Quando usar Positron:**
- Projetos que combinam R e Python
- Usuários vindos de VS Code
- Trabalho com grandes bases de dados
- Desenvolvimento de pacotes

### Visual Studio Code

Para usuários que preferem um editor mais genérico:

**Extensões essenciais:**
- R Extension (REditorSupport.r)
- R Debugger
- Quarto
- Rainbow CSV

### Comparação Rápida

| Recurso | RStudio | Positron | VS Code |
|---------|---------|----------|---------|
| Facilidade para iniciantes | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Recursos específicos de R | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Velocidade | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Suporte multilinguagem | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Visualização de dados | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |

---

## 💻 Convenções Modernas em R

### Escolha Seu Framework

#### Opção 1: Tidyverse (Recomendado para maioria dos usuários)

```r
# Workflow moderno, legível, baseado em pipes
library(tidyverse)

resultado <- dados %>%
  filter(ano >= 2020) %>%
  group_by(distrito) %>%
  summarise(
    valor_medio = mean(valor, na.rm = TRUE),
    n = n()
  ) %>%
  arrange(desc(valor_medio))
```

**Pacotes principais:**
- `dplyr`: Manipulação de dados
- `ggplot2`: Visualização
- `tidyr`: Reestruturação de dados
- `readr`: I/O rápido de arquivos
- `purrr`: Programação funcional
- `stringr`: Manipulação de strings
- `lubridate`: Manipulação de datas

#### Opção 2: data.table (Para performance com big data)

```r
# Rápido, eficiente em memória para datasets grandes
library(data.table)

dt <- data.table(dados)
resultado <- dt[ano >= 2020,
                .(valor_medio = mean(valor, na.rm = TRUE), n = .N),
                by = distrito][order(-valor_medio)]
```

**Quando usar data.table:**
- Datasets > 1GB
- Necessidade de máxima performance
- Operações agrupadas complexas
- Modificações in-place

### Guia de Estilo de Código

```r
# Boas práticas ------------------------------------------------

# 1. Use nomes de variáveis significativos
valor_imovel_2024 <- read_csv("data/iptu_2024.csv")  # ✓
df <- read_csv("data.csv")  # ✗

# 2. Comente seu código
# Calcula preço por metro quadrado ajustado pela inflação
preco_m2_real <- (preco_venda / area) * indice_inflacao

# 3. Use funções para operações repetidas
calcular_gini <- function(vetor_renda) {
  # Cálculo do coeficiente de Gini
  # Retorna valor entre 0 (igualdade) e 1 (desigualdade)
  n <- length(vetor_renda)
  renda_ordenada <- sort(vetor_renda)
  cumsum_renda <- cumsum(renda_ordenada)
  (2 * sum((1:n) * renda_ordenada)) / (n * sum(renda_ordenada)) - (n + 1) / n
}

# 4. Trate valores ausentes explicitamente
renda_media <- weighted.mean(
  renda,
  weights = populacao,
  na.rm = TRUE
)

# 5. Use operações vetorizadas
# Bom - vetorizado
dados$preco_real <- dados$preco * dados$indice_inflacao

# Evitar - loops desnecessários
for(i in 1:nrow(dados)) {
  dados$preco_real[i] <- dados$preco[i] * dados$indice_inflacao[i]
}
```

### Dicas de Performance

```r
# Faça profiling do seu código
library(profvis)
profvis({
  # Seu código de análise aqui
})

# Use processamento paralelo para operações grandes
library(furrr)
plan(multisession, workers = 4)

resultados <- future_map(datasets, processar_funcao)

# Leitura eficiente de dados
library(arrow)
dados <- read_parquet("dataset_grande.parquet")  # Muito mais rápido que CSV

library(vroom)
dados <- vroom("arquivo_grande.csv")  # Leitura rápida de CSV
```

---

## 🔌 Ferramentas de Acesso a Dados

### Conexões com Bancos de Dados

#### PostgreSQL
```r
library(DBI)
library(RPostgres)

# Conexão segura (use .Renviron para credenciais)
con <- dbConnect(
  Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST"),
  port = 5432,
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD")
)

# Consultar dados
dados_iptu <- tbl(con, "iptu_2024") %>%
  filter(distrito == "PINHEIROS") %>%
  collect()

dbDisconnect(con)
```

#### Google BigQuery
```r
library(bigrquery)

# Autenticar (abrirá o navegador)
bq_auth()

# Consultar dataset público
sql <- "
  SELECT
    pickup_datetime,
    fare_amount,
    pickup_longitude,
    pickup_latitude
  FROM `bigquery-public-data.new_york_taxi.trips`
  WHERE EXTRACT(YEAR FROM pickup_datetime) = 2019
  LIMIT 10000
"

dados_taxi <- bq_table_download(
  bq_project_query("seu-projeto-id", sql)
)
```

### Integração com APIs

#### Dados do Censo (IBGE)
```r
library(httr)
library(jsonlite)

# Exemplo de API do IBGE
obter_dados_ibge <- function(indicador, ano = 2020) {
  base_url <- "https://servicodados.ibge.gov.br/api/v1"

  response <- GET(
    paste0(base_url, "/", indicador),
    query = list(ano = ano)
  )

  if (status_code(response) == 200) {
    content(response, "text") %>%
      fromJSON()
  } else {
    stop("Falha na requisição à API")
  }
}

populacao <- obter_dados_ibge("populacao/estimativas")
```

#### Integração com Google Sheets
```r
library(googlesheets4)

# Autenticar
gs4_auth()

# Ler planilha pública
url_planilha <- "https://docs.google.com/spreadsheets/d/..."
dados <- read_sheet(url_planilha)

# Escrever em planilha privada (requer autenticação)
write_sheet(
  resultados,
  ss = "id-da-sua-planilha",
  sheet = "Resultados"
)
```

### Web Scraping (Quando APIs não estão disponíveis)
```r
library(rvest)
library(polite)

# Sempre seja educado!
sessao <- bow("https://exemplo.gov.br")

# Faça scraping responsavelmente
pagina <- scrape(sessao) %>%
  html_nodes(".tabela-dados") %>%
  html_table()

# Para sites com muito JavaScript
library(RSelenium)
driver <- rsDriver(browser = "firefox")
remDr <- driver$client
remDr$navigate("https://site-interativo.com")
```

---

## 🤖 Pesquisa Assistida por IA

### Recomendações de Ferramentas de IA para R

#### 1. Claude (Anthropic) - ⭐ MELHOR PARA R

O **Claude é superior para programação em R** devido a:
- ✅ Conhecimento atualizado de pacotes R modernos
- ✅ Melhor compreensão de tidyverse e data.table
- ✅ Código mais idiomático e eficiente
- ✅ Explicações estatísticas mais precisas
- ✅ Menos erros em sintaxe R específica

**Melhor para:**
- Análise de dados complexa em R
- Debugging de scripts R
- Escrita de documentação
- Explicação de conceitos estatísticos
- Criação de visualizações com ggplot2
- Desenvolvimento de pacotes R

**Exemplo de uso efetivo:**
```r
# Prompt para Claude:
"Escreva uma função em R usando tidyverse que calcule o índice de
Moran I para autocorrelação espacial, incluindo teste de significância
por permutação. Use o pacote spdep e retorne um tibble com estatística,
p-valor e interpretação."

# Claude gerará código correto e bem estruturado
```

#### 2. ChatGPT/GPT-4 - ⚠️ CUIDADO COM R

**Limitações do ChatGPT para R:**
- ❌ Frequentemente mistura sintaxe antiga com moderna
- ❌ Confunde funções de pacotes diferentes
- ❌ Gera código R não-idiomático
- ❌ Erros em operações com data.table
- ❌ Desatualizado em pacotes recentes

**Ainda útil para:**
- Conceitos gerais de programação
- Tradução de código entre linguagens
- Ideias de visualização (mas revise o código)
- Documentação geral

**Dica:** Se usar ChatGPT para R, sempre valide o código com Claude depois.

#### 3. Windsurf - 🆓 ALTERNATIVA GRATUITA AO GITHUB COPILOT

O **Windsurf** é um editor com IA integrada, excelente alternativa gratuita:

**Vantagens:**
- ✅ **100% gratuito** (ao contrário do Copilot)
- ✅ Autocompletar em tempo real
- ✅ Sugestões contextuais
- ✅ Funciona offline após configuração
- ✅ Integração com Claude e GPT-4
- ✅ Específico para R e Python

**Instalação:**
```bash
# Download em: https://codeium.com/windsurf
# Ou via terminal:
curl -fsSL https://codeium.com/install.sh | sh
```

**Configuração para R:**
1. Instale o Windsurf
2. Abra um projeto R
3. Configure: Settings → AI → Selecione "R priority"
4. Use Ctrl+K para sugestões inline

#### 4. GitHub Copilot - 💰 PAGO MAS PODEROSO

**Vantagens:**
- ✅ Integração perfeita com RStudio/VS Code
- ✅ Sugestões em tempo real
- ✅ Aprende com seu estilo de código
- ✅ Excelente para código boilerplate

**Desvantagens:**
- ❌ Pago ($10/mês ou $100/ano)
- ❌ Às vezes sugere código desatualizado
- ❌ Requer conta GitHub

### Comparação de IAs para R

| Ferramenta | Qualidade em R | Custo | Melhor Uso |
|------------|---------------|-------|------------|
| **Claude** | ⭐⭐⭐⭐⭐ | $20/mês* | Análise complexa, debugging |
| **Windsurf** | ⭐⭐⭐⭐ | Grátis | Autocompletar, código diário |
| **Copilot** | ⭐⭐⭐⭐ | $10/mês | Integração IDE, pair programming |
| **ChatGPT** | ⭐⭐⭐ | $20/mês* | Conceitos gerais, não para R |

*Versões gratuitas disponíveis com limitações

### Boas Práticas com IA

```r
# FAÇA: Verifique código gerado por IA
# Sempre teste com inputs conhecidos
dados_teste <- data.frame(
  valor = c(100, 200, 300),
  grupo = c("A", "A", "B")
)
resultado <- funcao_gerada_ia(dados_teste)
stopifnot(all(resultado$esperado == c(150, 150, 300)))

# FAÇA: Use IA para código repetitivo
# Deixe a IA escrever a estrutura, você adiciona a lógica

# NÃO FAÇA: Confie cegamente em interpretações estatísticas
# Sempre verifique alegações estatísticas com livros-texto

# NÃO FAÇA: Compartilhe dados sensíveis
# Use dados fictícios ao pedir ajuda
```

### Engenharia de Prompts para R

```r
# Prompts efetivos incluem:

# 1. Contexto
"Estou analisando preços de imóveis em São Paulo usando regressão hedônica"

# 2. Requisitos específicos
"Usando pacotes tidyverse e fixest"

# 3. Estrutura dos dados
"Meus dados têm colunas: preco, area_m2, quartos, distrito, ano"

# 4. Saída esperada
"Retorne um tibble com efeitos fixos por distrito"

# Exemplo de prompt completo para Claude:
"Escreva uma função em R usando tidyverse que receba um dataframe de
transações imobiliárias de São Paulo com colunas (preco, area_m2,
quartos, distrito, ano) e retorne um índice de preços hedônicos
por ano, controlando por efeitos fixos de distrito usando o
pacote fixest. Inclua erros-padrão robustos e visualização
com ggplot2."
```

### Template de Prompt para Claude (R específico)

```r
# Use este template para melhores resultados com Claude:

"CONTEXTO: [Descreva seu projeto de pesquisa]

DADOS:
- Formato: [tibble/data.frame/data.table]
- Linhas: [número aproximado]
- Colunas principais: [liste as variáveis]
- Exemplo de estrutura:
  ```r
  # str(seus_dados) ou head(seus_dados)
  ```

OBJETIVO: [O que você quer alcançar]

REQUISITOS:
- Framework: [tidyverse/data.table/base R]
- Pacotes específicos: [liste pacotes necessários]
- Performance: [crítica/normal]
- Reprodutibilidade: [incluir set.seed se necessário]

SAÍDA ESPERADA: [Descreva o formato do resultado]

CÓDIGO:"
```

---

## 🎓 Recursos Insper

### Pacotes Insper

#### insperplot
```r
# Plots bonitos e consistentes seguindo a marca Insper
devtools::install_github("portalcidados/insperplot")
library(insperplot)

ggplot(dados, aes(x = ano, y = valor)) +
  geom_line() +
  theme_insper() +
  scale_color_insper()
```

#### inspertex
```r
# Templates LaTeX para artigos Insper
devtools::install_github("insper/inspertex")
library(inspertex)

# Criar artigo formatado Insper
create_insper_paper(
  title = "Desenvolvimento Urbano em São Paulo",
  author = "Seu Nome",
  type = "working_paper"
)
```

### Recursos de Dados Insper

- **Insper DataLab**: Acesso a datasets proprietários
- **Insper Dataverse**: https://dataverse.insper.edu.br
- **Portal CiDados**: Portal de dados urbanos
- **Insper GitHub**: https://github.com/insper

### Recursos Computacionais

```r
# Conectar ao RStudio Server do Insper
# https://rstudio.insper.edu.br

# Para computações grandes, use o cluster do Insper
library(future)
plan(cluster, workers = c("node1", "node2", "node3"))
```

---

## 📖 Referências Essenciais

### Livros Fundamentais de R (Gratuitos Online)

1. **[R for Data Science (2ª Edição)](https://r4ds.hadley.nz/)**
   - Autores: Wickham, Çetinkaya-Rundel, Grolemund
   - Essencial para dominar tidyverse
   - *Versão em português em desenvolvimento*

2. **[Advanced R](https://adv-r.hadley.nz/)**
   - Autor: Hadley Wickham
   - Mergulho profundo em programação R

3. **[Geocomputation with R](https://r.geocompx.org/)**
   - Autores: Lovelace, Nowosad, Muenchow
   - Análise espacial e mapeamento

4. **[Tidy Modeling with R](https://www.tmwr.org/)**
   - Autores: Kuhn, Silge
   - Abordagem moderna para modelagem estatística

5. **[R Graphics Cookbook](https://r-graphics.org/)**
   - Autor: Winston Chang
   - Guia completo de ggplot2

### Economia Urbana e Econometria

6. **[Introduction to Econometrics with R](https://www.econometrics-with-r.org/)**
   - Autores: Hanck, Arnold, Gerber, Schmelzer

7. **[Causal Inference: The Mixtape](https://mixtape.scunning.com/)**
   - Autor: Scott Cunningham
   - Métodos modernos de inferência causal

8. **[The Effect](https://theeffectbook.net/)**
   - Autor: Nick Huntington-Klein
   - Inferência causal com exemplos em R

### Recursos de Dados Brasileiros

- **[IPEA Data](http://www.ipeadata.gov.br/)**: Indicadores econômicos
- **[IBGE](https://www.ibge.gov.br/)**: Censos e pesquisas
- **[CEM USP](https://centrodametropole.fflch.usp.br/)**: Dados metropolitanos
- **[Seade](https://www.seade.gov.br/)**: Estatísticas de São Paulo
- **[DataSUS](https://datasus.saude.gov.br/)**: Dados de saúde
- **[Base dos Dados](https://basedosdados.org/)**: Dados públicos brasileiros limpos

### Documentação de Pacotes

```r
# Sempre consulte os sites dos pacotes para melhores práticas:

# Ecossistema tidyverse
browseURL("https://www.tidyverse.org/")

# data.table
browseURL("https://rdatatable.gitlab.io/data.table/")

# SF para dados espaciais
browseURL("https://r-spatial.github.io/sf/")

# fixest para econometria
browseURL("https://lrberge.github.io/fixest/")

# Rcidados - nosso pacote
browseURL("https://insper-cidades.github.io/Rcidados/")
```

---

## ✅ Checklist de Reprodutibilidade

### Antes de Iniciar Seu Projeto

- [ ] Criar novo projeto RStudio
- [ ] Inicializar repositório git
- [ ] Configurar renv: `renv::init()`
- [ ] Criar estrutura de pastas
- [ ] Escrever README inicial
- [ ] Configurar .gitignore

### Durante o Desenvolvimento

- [ ] Fazer commits regulares com mensagens significativas
- [ ] Documentar todas as fontes de dados
- [ ] Comentar seções complexas do código
- [ ] Criar funções para tarefas repetidas
- [ ] Escrever testes unitários para funções críticas
- [ ] Atualizar renv: `renv::snapshot()`

### Gestão de Dados

- [ ] Manter dados brutos imutáveis
- [ ] Documentar todas as transformações
- [ ] Criar codebook para variáveis
- [ ] Versionar dados processados
- [ ] Validar qualidade dos dados
- [ ] Tratar valores ausentes explicitamente

### Análise

- [ ] Definir seed aleatória para reprodutibilidade
- [ ] Salvar resultados intermediários
- [ ] Criar notebooks de análise
- [ ] Gerar plots programaticamente
- [ ] Exportar tabelas em formatos padrão
- [ ] Documentar especificações de modelos

### Antes de Publicar

- [ ] Limpar e organizar todos os scripts
- [ ] Testar pipeline completo do zero
- [ ] Atualizar documentação
- [ ] Criar instruções de replicação
- [ ] Arquivar dados e código (Zenodo/Dataverse)
- [ ] Gerar DOI para citação
- [ ] Verificar compatibilidade de licenças

### Colaboração

- [ ] Usar estilo de código consistente
- [ ] Revisar código com colegas
- [ ] Documentar dependências claramente
- [ ] Criar guia de contribuição
- [ ] Configurar templates de issues
- [ ] Manter changelog

---

## 🚀 Template de Início Rápido

```r
# Criar novo projeto de economia urbana
criar_projeto_urbano <- function(nome_projeto) {
  # Criar projeto
  usethis::create_project(nome_projeto)

  # Configurar git
  usethis::use_git()

  # Inicializar renv
  renv::init()

  # Criar estrutura de pastas
  dirs <- c("data/raw", "data/processed", "data/final",
            "R", "notebooks", "outputs/figures",
            "outputs/tables", "outputs/reports", "docs")
  lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE)

  # Criar README
  usethis::use_readme_md()

  # Criar .gitignore
  usethis::use_git_ignore(c(
    "*.Rdata", "*.Rhistory", ".Rproj.user/",
    "data/raw/*", "!data/raw/README.md"
  ))

  # Instalar pacotes comuns
  install.packages(c(
    "tidyverse", "data.table", "fixest", "modelsummary",
    "sf", "arrow", "janitor", "here", "targets"
  ))

  # Instalar Rcidados
  remotes::install_github("insper-cidades/Rcidados")

  message("Projeto '", nome_projeto, "' criado com sucesso!")
  message("Próximos passos:")
  message("1. Abra o arquivo .Rproj")
  message("2. Comece a programar na pasta R/")
  message("3. Faça commits regulares")
}

# Use assim:
criar_projeto_urbano("analise_habitacao_sp")
```

---

## 💡 Obtendo Ajuda

### Onde Fazer Perguntas

1. **Stack Overflow**: Tag com `[r]` e pacote específico
2. **RStudio Community**: https://community.rstudio.com/
3. **GitHub Issues dos Pacotes**: Para bugs/features
4. **Twitter/X**: hashtag #rstats
5. **Slack do Insper**: canal #r-users

### Como Pedir Ajuda (Exemplos Reproduzíveis)

```r
# Crie um exemplo mínimo reproduzível (reprex)
library(reprex)

reprex({
  # Código mínimo que mostra seu problema
  library(dplyr)

  # Use dados built-in ou crie exemplo simples
  dados <- data.frame(
    x = c(1, 2, NA, 4),
    y = c("A", "B", "B", "C")
  )

  # Mostre o problema
  dados %>%
    group_by(y) %>%
    summarise(media_x = mean(x))  # Isso retorna NA
})
```

---

## 📧 Suporte

Para dúvidas sobre este guia ou ciência de dados urbanos no Insper:

- **Email**: cidades@insper.edu.br
- **Horário de Atendimento**: Agendar em [link]
- **Workshops**: Verifique o calendário para treinamentos em R

---

*Última atualização: 2025-01-10 | Versão 1.0 | [English Version](./RESEARCH_GUIDELINES.md)*
