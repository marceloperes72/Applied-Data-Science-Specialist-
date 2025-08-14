# Pipeline DATASUS - Extração de Microdados de Saúde Pública

![R](https://img.shields.io/badge/R-4.0%2B-blue)
![License](https://img.shields.io/badge/license-GPL--3-green)
![Status](https://img.shields.io/badge/status-stable-brightgreen)

## 📋 Descrição

Este pipeline automatiza a extração, processamento e análise de microdados do DATASUS (Departamento de Informática do Sistema Único de Saúde) utilizando o pacote `microdatasus`. O sistema suporta múltiplos sistemas de informação em saúde cobrindo dados dos últimos 10 anos (2015-2024).

### Sistemas Suportados

- **SIM**: Sistema de Informações sobre Mortalidade
- **SIH-RD**: Sistema de Informações Hospitalares - Dados Reduzidos  
- **SIA**: Sistema de Informações Ambulatoriais
- **SINASC**: Sistema de Informações sobre Nascidos Vivos
- **SINAN**: Sistema de Informação de Agravos de Notificação
- **CNES**: Cadastro Nacional de Estabelecimentos de Saúde

### Características Principais

- ✅ Extração automatizada de múltiplos sistemas DATASUS
- ✅ Processamento e limpeza de dados padronizada
- ✅ Sistema de cache inteligente para otimizar downloads
- ✅ Processamento paralelo para melhor performance
- ✅ Validação e relatórios de qualidade dos dados
- ✅ Configuração flexível via arquivo YAML
- ✅ Logs detalhados de execução
- ✅ Interface de linha de comando

## 🚀 Instalação Rápida

### Pré-requisitos

- R 4.0 ou superior
- Conexão com internet para download dos microdados

### 1. Clonar/Baixar o Pipeline

```bash
# Se usando git
git clone <repositorio>
cd datasus_pipeline

# Ou extrair arquivos baixados
cd datasus_pipeline
```

### 2. Instalar Dependências

```r
# Executar script de instalação
source("install_dependencies.R")
```

Ou manualmente:

```r
# Instalar microdatasus (GitHub)
devtools::install_github("rfsaldanha/microdatasus")

# Instalar outros pacotes
packages <- c("dplyr", "lubridate", "readr", "purrr", "stringr", 
              "logger", "config", "here", "janitor", "data.table")
install.packages(packages)
```

### 3. Executar Teste

```r
# Teste rápido (apenas SP, 2023)
Rscript main_pipeline.R --test
```

## 📁 Estrutura do Projeto

```
datasus_pipeline/
├── main_pipeline.R              # Script principal
├── install_dependencies.R       # Instalação de dependências
├── DESCRIPTION                  # Descrição do pacote R
├── README.md                    # Esta documentação
├── config/
│   └── pipeline_config.yml      # Configurações do pipeline
├── scripts/
│   ├── utils.R                  # Funções utilitárias
│   ├── extraction_functions.R   # Funções de extração
│   └── data_processing.R        # Funções de processamento
├── data/
│   ├── raw/                     # Dados brutos extraídos
│   ├── processed/               # Dados processados
│   ├── final/                   # Dados finais e relatórios
│   ├── cache/                   # Cache de downloads
│   └── temp/                    # Arquivos temporários
└── logs/                        # Logs de execução
```

## ⚙️ Configuração

### Arquivo de Configuração (`config/pipeline_config.yml`)

O pipeline é configurado através de um arquivo YAML que permite personalizar:

- **Período de análise**: Anos de início e fim
- **Sistemas ativos**: Quais sistemas extrair
- **UFs**: Estados para processar (`"all"` ou lista específica)
- **Processamento**: Paralelismo, cache, formatos de saída
- **Agravos SINAN**: Códigos específicos para notificação

#### Exemplo de Configuração Personalizada

```yaml
# Personalizar período
periodo:
  inicio: 2020
  fim: 2023

# Processar apenas alguns estados
sistemas:
  SIM:
    ativo: true
    uf: ["SP", "RJ", "MG"]  # Apenas estes estados
    
  SINASC:
    ativo: true
    uf: "all"  # Todos os estados
    
  # Desativar outros sistemas
  SIH:
    ativo: false
```

## 🖥️ Uso do Pipeline

### Linha de Comando

#### Execução Completa (Padrão)
```bash
# Executar pipeline completo
Rscript main_pipeline.R
```

#### Opções Principais

```bash
# Modo teste (rápido)
Rscript main_pipeline.R --test

# Sistemas específicos
Rscript main_pipeline.R --sistemas SIM,SINASC

# Forçar re-download (ignorar cache)
Rscript main_pipeline.R --force

# Configuração personalizada
Rscript main_pipeline.R --config config/custom.yml

# Ver ajuda
Rscript main_pipeline.R --help
```

### Uso Programático (R)

```r
# Carregar pipeline
source("main_pipeline.R")

# Execução padrão
result <- main_pipeline()

# Modo teste
result <- run_test_pipeline()

# Sistema específico
result <- run_single_system("SIM")

# Configuração personalizada
result <- main_pipeline(
  config_file = "config/custom.yml",
  sistemas_especificos = c("SIM", "SINASC"),
  modo_teste = FALSE
)
```

## 📊 Saídas e Resultados

### Estrutura dos Dados Processados

```
data/processed/
├── SIM/
│   ├── SIM_2023_SP_processed.parquet
│   ├── SIM_2023_RJ_processed.parquet
│   └── quality_reports.rds
├── SINASC/
│   ├── SINASC_2023_SP_processed.parquet
│   └── quality_reports.rds
└── ...
```

### Relatórios Gerados

1. **Relatório de Execução** (`logs/execution_report_TIMESTAMP.rds`)
   - Estatísticas gerais da execução
   - Tempo de processamento
   - Erros encontrados

2. **Relatório de Qualidade** (`data/final/quality_summary.csv`)
   - Completude dos dados por sistema
   - Quantidade de registros
   - Indicadores de qualidade

3. **Logs Detalhados** (`logs/pipeline.log`)
   - Log completo da execução
   - Erros e avisos detalhados

### Acessar Dados Processados

```r
# Carregar dados de mortalidade de SP em 2023
dados_sim_sp <- readRDS("data/processed/SIM/SIM_2023_SP_processed.rds")

# Ou usando parquet (mais eficiente)
library(arrow)
dados_sim_sp <- read_parquet("data/processed/SIM/SIM_2023_SP_processed.parquet")

# Ver estatísticas
summary(dados_sim_sp)

# Campos comuns após processamento
names(dados_sim_sp)
# [1] "data_obito"           "sexo"                "idade" 
# [4] "codigo_municipio"     "causa_basica_cid"    "ano_obito"
# [7] "sistema"              "data_processamento"  ...
```

## 🔧 Processamento de Dados

### Limpeza Automática

O pipeline aplica automaticamente:

- **Padronização de nomes**: Colunas com nomes consistentes
- **Conversão de datas**: Formatos DATASUS → Date objects
- **Códigos padronizados**: 
  - Municípios (6 dígitos IBGE)
  - CID (formato padrão)
  - Sexo (M/F/I)
- **Validações**:
  - Idades (0-150 anos)
  - Pesos ao nascer (500-6000g)
  - Valores monetários (≥ 0)

### Campos Derivados

Campos calculados automaticamente:

- **SIM**: `idade_calculada`, `ano_obito`
- **SIH**: `tempo_permanencia`
- **SINASC**: `classificacao_peso`
- **SINAN**: `dias_sintomas_notificacao`

### Metadados Adicionados

Todos os datasets incluem:
- `sistema`: Nome do sistema de origem
- `ano_extracao`, `uf_extracao`: Parâmetros da extração
- `data_extracao`, `data_processamento`: Timestamps
- `versao_processamento`: Versão do pipeline

## 🚨 Tratamento de Erros

### Estratégias de Recuperação

- **Download**: Múltiplas tentativas com intervalo
- **Cache**: Uso de dados em cache quando disponível
- **Continuidade**: Erros em um sistema não interrompem outros
- **Logs**: Registro detalhado de todos os problemas

### Problemas Comuns

| Problema | Causa | Solução |
|----------|-------|---------|
| Dados não encontrados | UF/Ano indisponível no DATASUS | Verifique disponibilidade no portal |
| Timeout de conexão | Conexão instável | Use `--force` para tentar novamente |
| Erro de formato | Mudança no formato DATASUS | Atualize o pipeline |
| Falta de memória | Dataset muito grande | Use modo teste ou filtre UFs |

## 📈 Performance e Otimizações

### Configurações Recomendadas

**Para processamento rápido:**
```yaml
processamento:
  paralelismo: true
  num_cores: 8  # Ajustar conforme CPU

cache:
  ativo: true
  tempo_expiracao: 30  # dias

armazenamento:
  formato_saida: "parquet"  # Mais eficiente
```

**Para economizar espaço:**
```yaml
armazenamento:
  formato_saida: "csv"
  compressao: true
  backup: false
```

### Estimativas de Tempo/Espaço

| Sistema | Registros/Ano (aprox.) | Tempo (SP) | Espaço |
|---------|------------------------|------------|--------|
| SIM     | 150K                   | 2-5 min    | 50 MB  |
| SIH     | 1M                     | 10-20 min  | 200 MB |
| SINASC  | 600K                   | 5-10 min   | 100 MB |
| SIA     | 50M                    | 60+ min    | 2+ GB  |

> **Nota**: Tempos variam conforme conexão de internet e configuração do sistema.

## 🔒 Considerações de Dados

### Privacidade e Ética

- Os microdados do DATASUS são **públicos** e anonimizados
- Não contêm informações pessoais identificáveis
- Uso deve seguir princípios éticos de pesquisa em saúde
- Considere limitações dos dados administrativos

### Qualidade dos Dados

- **Completude**: Varia por sistema e período
- **Consistência**: Melhorou ao longo dos anos
- **Cobertura**: Pode variar entre regiões
- **Atraso**: Dados mais recentes podem estar incompletos

## 🤝 Contribuições

Para contribuir com melhorias:

1. Reporte bugs via issues
2. Sugira novos recursos
3. Contribua com código seguindo as convenções R
4. Melhore a documentação

### Roadmap

- [ ] Suporte a indicadores de saúde pré-calculados
- [ ] Dashboard interativo para visualização
- [ ] Integração com bases geográficas
- [ ] Análises epidemiológicas automatizadas
- [ ] Suporte a outros sistemas DATASUS

## 📚 Recursos Adicionais

### Documentação DATASUS

- [Portal DATASUS](http://datasus.saude.gov.br/)
- [Dicionários de Dados](http://www2.datasus.gov.br/DATASUS/index.php?area=060801)
- [Tabelas de Códigos](http://www2.datasus.gov.br/DATASUS/index.php?area=060302)

### Pacote microdatasus

- [GitHub](https://github.com/rfsaldanha/microdatasus)
- [Documentação](https://rfsaldanha.github.io/microdatasus/)
- [Artigo científico](https://doi.org/10.1590/0102-311X00032419)

### R para Saúde Pública

- [R Epidemics Consortium](https://www.repidemicsconsortium.org/)
- [Applied Epi Handbook](https://epirhandbook.com/)

## 📄 Licença

GPL-3. Ver arquivo LICENSE para detalhes.

## ✉️ Contato

Para suporte técnico:
- Abra uma issue no repositório
- Consulte a documentação do microdatasus
- Verifique logs detalhados em `logs/`

---

**Desenvolvido para facilitar o acesso e análise de dados de saúde pública brasileiros** 🇧🇷