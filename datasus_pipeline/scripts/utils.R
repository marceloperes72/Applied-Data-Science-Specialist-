# =============================================================================
# Funções Utilitárias - Pipeline DATASUS
# =============================================================================

# Carregar bibliotecas necessárias
suppressPackageStartupMessages({
  library(dplyr)
  library(here)
  library(config)
  library(logger)
  library(lubridate)
  library(stringr)
  library(purrr)
})

#' Configurar logging
#' @param log_level Nível de log (DEBUG, INFO, WARN, ERROR)
#' @param log_file Arquivo de log
setup_logging <- function(log_level = "INFO", log_file = NULL) {
  
  # Criar diretório de logs se não existir
  if (!is.null(log_file)) {
    log_dir <- dirname(log_file)
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
  }
  
  # Configurar logger
  log_threshold(log_level)
  
  if (!is.null(log_file)) {
    log_appender(appender_file(log_file))
  } else {
    log_appender(appender_console)
  }
  
  log_info("Sistema de logging configurado - Nível: {log_level}")
}

#' Carregar configuração do pipeline
#' @param config_file Caminho para o arquivo de configuração
#' @return Lista com configurações
load_pipeline_config <- function(config_file = "config/pipeline_config.yml") {
  
  if (!file.exists(config_file)) {
    stop("Arquivo de configuração não encontrado: ", config_file)
  }
  
  tryCatch({
    config <- config::get(file = config_file)
    log_info("Configuração carregada com sucesso")
    return(config)
  }, error = function(e) {
    log_error("Erro ao carregar configuração: {e$message}")
    stop(e)
  })
}

#' Criar estrutura de diretórios
#' @param config Configuração do pipeline
create_directories <- function(config) {
  
  dirs <- config$diretorios
  
  # Lista de diretórios para criar
  dir_list <- c(
    dirs$dados_brutos,
    dirs$dados_processados,
    dirs$dados_finais,
    dirs$logs,
    dirs$temporarios,
    file.path(dirs$dados_brutos, "SIM"),
    file.path(dirs$dados_brutos, "SIH"),
    file.path(dirs$dados_brutos, "SIA"),
    file.path(dirs$dados_brutos, "SINASC"),
    file.path(dirs$dados_brutos, "SINAN"),
    file.path(dirs$dados_brutos, "CNES")
  )
  
  # Cache se ativo
  if (config$cache$ativo) {
    dir_list <- c(dir_list, config$cache$diretorio)
  }
  
  # Criar diretórios
  for (dir in dir_list) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      log_debug("Diretório criado: {dir}")
    }
  }
  
  log_info("Estrutura de diretórios verificada/criada")
}

#' Validar período de anos
#' @param anos Vetor de anos
#' @param sistema Nome do sistema
#' @return Vetor de anos válidos
validate_years <- function(anos, sistema = NULL) {
  
  current_year <- as.numeric(format(Sys.Date(), "%Y"))
  valid_years <- anos[anos >= 2008 & anos <= current_year]
  
  invalid_years <- setdiff(anos, valid_years)
  
  if (length(invalid_years) > 0) {
    warning_msg <- paste0("Anos inválidos removidos para ", 
                         ifelse(is.null(sistema), "sistema", sistema), 
                         ": ", paste(invalid_years, collapse = ", "))
    log_warn(warning_msg)
  }
  
  if (length(valid_years) == 0) {
    stop("Nenhum ano válido encontrado")
  }
  
  return(sort(valid_years))
}

#' Validar UFs
#' @param ufs Vetor de UFs ou "all"
#' @return Vetor de UFs válidas
validate_ufs <- function(ufs) {
  
  valid_ufs <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", 
                 "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", 
                 "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO")
  
  if (length(ufs) == 1 && ufs == "all") {
    return(valid_ufs)
  }
  
  # Converter para maiúsculo
  ufs <- toupper(ufs)
  
  # Filtrar UFs válidas
  valid_input_ufs <- ufs[ufs %in% valid_ufs]
  invalid_ufs <- setdiff(ufs, valid_input_ufs)
  
  if (length(invalid_ufs) > 0) {
    log_warn("UFs inválidas removidas: {paste(invalid_ufs, collapse = ', ')}")
  }
  
  if (length(valid_input_ufs) == 0) {
    stop("Nenhuma UF válida encontrada")
  }
  
  return(sort(valid_input_ufs))
}

#' Verificar se arquivo já existe (para cache)
#' @param file_path Caminho do arquivo
#' @param max_age_days Idade máxima em dias
#' @return TRUE se arquivo existe e é recente
file_is_cached <- function(file_path, max_age_days = 7) {
  
  if (!file.exists(file_path)) {
    return(FALSE)
  }
  
  file_age <- difftime(Sys.time(), file.mtime(file_path), units = "days")
  
  return(as.numeric(file_age) <= max_age_days)
}

#' Criar nome de arquivo padronizado
#' @param sistema Nome do sistema
#' @param ano Ano
#' @param uf UF
#' @param agravo Agravo (opcional, para SINAN)
#' @param extensao Extensão do arquivo
#' @return Nome do arquivo
create_filename <- function(sistema, ano, uf, agravo = NULL, extensao = "rds") {
  
  if (!is.null(agravo)) {
    filename <- paste0(sistema, "_", agravo, "_", ano, "_", uf, ".", extensao)
  } else {
    filename <- paste0(sistema, "_", ano, "_", uf, ".", extensao)
  }
  
  return(filename)
}

#' Salvar dados com backup
#' @param data Dados para salvar
#' @param file_path Caminho do arquivo
#' @param backup Fazer backup do arquivo existente
save_data_with_backup <- function(data, file_path, backup = TRUE) {
  
  # Fazer backup se arquivo existe
  if (backup && file.exists(file_path)) {
    backup_path <- paste0(file_path, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
    file.copy(file_path, backup_path)
    log_debug("Backup criado: {backup_path}")
  }
  
  # Criar diretório se não existir
  dir.create(dirname(file_path), recursive = TRUE, showWarnings = FALSE)
  
  # Salvar dados baseado na extensão
  extensao <- tools::file_ext(file_path)
  
  tryCatch({
    switch(extensao,
           "rds" = saveRDS(data, file_path),
           "csv" = readr::write_csv(data, file_path),
           "parquet" = arrow::write_parquet(data, file_path),
           stop("Formato de arquivo não suportado: ", extensao)
    )
    
    log_info("Dados salvos: {file_path}")
    
  }, error = function(e) {
    log_error("Erro ao salvar dados em {file_path}: {e$message}")
    stop(e)
  })
}

#' Carregar dados baseado na extensão
#' @param file_path Caminho do arquivo
#' @return Dados carregados
load_data <- function(file_path) {
  
  if (!file.exists(file_path)) {
    stop("Arquivo não encontrado: ", file_path)
  }
  
  extensao <- tools::file_ext(file_path)
  
  tryCatch({
    data <- switch(extensao,
                   "rds" = readRDS(file_path),
                   "csv" = readr::read_csv(file_path, show_col_types = FALSE),
                   "parquet" = arrow::read_parquet(file_path),
                   stop("Formato de arquivo não suportado: ", extensao)
    )
    
    log_debug("Dados carregados: {file_path}")
    return(data)
    
  }, error = function(e) {
    log_error("Erro ao carregar dados de {file_path}: {e$message}")
    stop(e)
  })
}

#' Configurar processamento paralelo
#' @param num_cores Número de cores (0 para detectar automaticamente)
setup_parallel_processing <- function(num_cores = 0) {
  
  if (num_cores == 0) {
    num_cores <- parallel::detectCores() - 1
  }
  
  # Garantir que temos pelo menos 1 core
  num_cores <- max(1, num_cores)
  
  # Configurar cluster
  if (num_cores > 1) {
    doParallel::registerDoParallel(cores = num_cores)
    log_info("Processamento paralelo configurado com {num_cores} cores")
  } else {
    log_info("Processamento sequencial (1 core)")
  }
  
  return(num_cores)
}

#' Limpar cache antigo
#' @param cache_dir Diretório do cache
#' @param max_age_days Idade máxima em dias
clean_old_cache <- function(cache_dir, max_age_days = 7) {
  
  if (!dir.exists(cache_dir)) {
    return()
  }
  
  files <- list.files(cache_dir, full.names = TRUE, recursive = TRUE)
  
  if (length(files) == 0) {
    return()
  }
  
  old_files <- files[sapply(files, function(f) {
    age <- difftime(Sys.time(), file.mtime(f), units = "days")
    as.numeric(age) > max_age_days
  })]
  
  if (length(old_files) > 0) {
    file.remove(old_files)
    log_info("Removidos {length(old_files)} arquivos antigos do cache")
  }
}

#' Imprimir estatísticas do dataset
#' @param data Dataset
#' @param nome Nome do dataset
print_dataset_stats <- function(data, nome = "Dataset") {
  
  cat("\n", "="*50, "\n")
  cat("ESTATÍSTICAS -", nome, "\n")
  cat("="*50, "\n")
  cat("Linhas:", nrow(data), "\n")
  cat("Colunas:", ncol(data), "\n")
  cat("Tamanho em memória:", format(object.size(data), units = "MB"), "\n")
  
  if (nrow(data) > 0) {
    # Verificar colunas com dados faltantes
    missing_cols <- sapply(data, function(x) sum(is.na(x)))
    missing_cols <- missing_cols[missing_cols > 0]
    
    if (length(missing_cols) > 0) {
      cat("\nColunas com dados faltantes:\n")
      for (col in names(missing_cols)) {
        pct <- round(missing_cols[col] / nrow(data) * 100, 2)
        cat(sprintf("  %s: %d (%s%%)\n", col, missing_cols[col], pct))
      }
    }
  }
  
  cat("="*50, "\n\n")
}