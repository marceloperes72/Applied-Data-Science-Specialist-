#!/usr/bin/env Rscript

# =============================================================================
# Script de Instalação de Dependências - Pipeline DATASUS
# =============================================================================

cat("Iniciando instalação das dependências do Pipeline DATASUS...\n")

# Lista de pacotes necessários
required_packages <- c(
  "microdatasus",
  "dplyr", 
  "lubridate",
  "readr",
  "purrr",
  "stringr",
  "httr",
  "jsonlite",
  "DBI",
  "RSQLite",
  "data.table",
  "parallel",
  "doParallel",
  "foreach",
  "logger",
  "config",
  "here",
  "janitor",
  "devtools"
)

# Função para instalar pacotes se não estiverem instalados
install_if_missing <- function(package) {
  if (!require(package, character.only = TRUE, quietly = TRUE)) {
    cat(paste("Instalando pacote:", package, "\n"))
    
    # Tratamento especial para microdatasus
    if (package == "microdatasus") {
      if (!require("devtools", quietly = TRUE)) {
        install.packages("devtools")
      }
      devtools::install_github("rfsaldanha/microdatasus")
    } else {
      install.packages(package, dependencies = TRUE)
    }
    
    # Verificar se a instalação foi bem-sucedida
    if (require(package, character.only = TRUE, quietly = TRUE)) {
      cat(paste("✓ Pacote", package, "instalado com sucesso\n"))
    } else {
      cat(paste("✗ Erro ao instalar o pacote", package, "\n"))
    }
  } else {
    cat(paste("✓ Pacote", package, "já está instalado\n"))
  }
}

# Instalar todos os pacotes
cat("\n=== INSTALANDO DEPENDÊNCIAS ===\n")
for (package in required_packages) {
  install_if_missing(package)
}

# Verificação final
cat("\n=== VERIFICAÇÃO FINAL ===\n")
all_loaded <- TRUE
for (package in required_packages) {
  if (require(package, character.only = TRUE, quietly = TRUE)) {
    cat(paste("✓", package, "carregado com sucesso\n"))
  } else {
    cat(paste("✗", package, "falhou ao carregar\n"))
    all_loaded <- FALSE
  }
}

if (all_loaded) {
  cat("\n🎉 Todas as dependências foram instaladas e carregadas com sucesso!\n")
  cat("Você pode agora executar o pipeline DATASUS.\n")
} else {
  cat("\n⚠️  Algumas dependências falharam. Verifique os erros acima.\n")
}

cat("\n=== INFORMAÇÕES DO SISTEMA ===\n")
cat(paste("Versão do R:", R.version.string, "\n"))
cat(paste("Plataforma:", R.version$platform, "\n"))
cat(paste("Data/Hora:", Sys.time(), "\n"))