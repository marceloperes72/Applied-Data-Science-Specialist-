# =============================================================================
# Funções de Extração - Pipeline DATASUS
# =============================================================================

# Carregar bibliotecas
suppressPackageStartupMessages({
  library(microdatasus)
  library(dplyr)
  library(logger)
  library(purrr)
  library(stringr)
})

# Carregar utilitários
source("scripts/utils.R")

#' Extrair dados do Sistema de Informações sobre Mortalidade (SIM)
#' @param ano Ano para extração
#' @param uf UF para extração
#' @param cache_dir Diretório de cache
#' @param use_cache Usar cache se disponível
#' @return Data frame com dados do SIM
extract_sim_data <- function(ano, uf, cache_dir = NULL, use_cache = TRUE) {
  
  log_info("Extraindo dados SIM - Ano: {ano}, UF: {uf}")
  
  # Verificar cache
  if (use_cache && !is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, create_filename("SIM", ano, uf, extensao = "rds"))
    
    if (file_is_cached(cache_file)) {
      log_info("Carregando dados SIM do cache: {cache_file}")
      return(readRDS(cache_file))
    }
  }
  
  # Tentar extrair dados
  tryCatch({
    
    # Usar microdatasus para baixar dados
    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      uf = uf,
      information_system = "SIM"
    )
    
    if (is.null(dados) || nrow(dados) == 0) {
      log_warn("Nenhum dado encontrado para SIM {ano}/{uf}")
      return(data.frame())
    }
    
    # Adicionar metadados
    dados$ano_extracao <- ano
    dados$uf_extracao <- uf
    dados$sistema <- "SIM"
    dados$data_extracao <- Sys.time()
    
    # Salvar no cache se configurado
    if (!is.null(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cache_file <- file.path(cache_dir, create_filename("SIM", ano, uf, extensao = "rds"))
      saveRDS(dados, cache_file)
      log_debug("Dados SIM salvos no cache: {cache_file}")
    }
    
    log_info("Dados SIM extraídos com sucesso - {nrow(dados)} registros")
    return(dados)
    
  }, error = function(e) {
    log_error("Erro ao extrair dados SIM {ano}/{uf}: {e$message}")
    return(data.frame())
  })
}

#' Extrair dados do Sistema de Informações Hospitalares (SIH-RD)
#' @param ano Ano para extração
#' @param uf UF para extração
#' @param cache_dir Diretório de cache
#' @param use_cache Usar cache se disponível
#' @return Data frame com dados do SIH
extract_sih_data <- function(ano, uf, cache_dir = NULL, use_cache = TRUE) {
  
  log_info("Extraindo dados SIH - Ano: {ano}, UF: {uf}")
  
  # Verificar cache
  if (use_cache && !is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, create_filename("SIH", ano, uf, extensao = "rds"))
    
    if (file_is_cached(cache_file)) {
      log_info("Carregando dados SIH do cache: {cache_file}")
      return(readRDS(cache_file))
    }
  }
  
  tryCatch({
    
    # Usar microdatasus para baixar dados
    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      uf = uf,
      information_system = "SIH-RD"
    )
    
    if (is.null(dados) || nrow(dados) == 0) {
      log_warn("Nenhum dado encontrado para SIH {ano}/{uf}")
      return(data.frame())
    }
    
    # Adicionar metadados
    dados$ano_extracao <- ano
    dados$uf_extracao <- uf
    dados$sistema <- "SIH"
    dados$data_extracao <- Sys.time()
    
    # Salvar no cache
    if (!is.null(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cache_file <- file.path(cache_dir, create_filename("SIH", ano, uf, extensao = "rds"))
      saveRDS(dados, cache_file)
      log_debug("Dados SIH salvos no cache: {cache_file}")
    }
    
    log_info("Dados SIH extraídos com sucesso - {nrow(dados)} registros")
    return(dados)
    
  }, error = function(e) {
    log_error("Erro ao extrair dados SIH {ano}/{uf}: {e$message}")
    return(data.frame())
  })
}

#' Extrair dados do Sistema de Informações Ambulatoriais (SIA)
#' @param ano Ano para extração
#' @param uf UF para extração
#' @param cache_dir Diretório de cache
#' @param use_cache Usar cache se disponível
#' @return Data frame com dados do SIA
extract_sia_data <- function(ano, uf, cache_dir = NULL, use_cache = TRUE) {
  
  log_info("Extraindo dados SIA - Ano: {ano}, UF: {uf}")
  
  # Verificar cache
  if (use_cache && !is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, create_filename("SIA", ano, uf, extensao = "rds"))
    
    if (file_is_cached(cache_file)) {
      log_info("Carregando dados SIA do cache: {cache_file}")
      return(readRDS(cache_file))
    }
  }
  
  tryCatch({
    
    # Usar microdatasus para baixar dados
    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      uf = uf,
      information_system = "SIA"
    )
    
    if (is.null(dados) || nrow(dados) == 0) {
      log_warn("Nenhum dado encontrado para SIA {ano}/{uf}")
      return(data.frame())
    }
    
    # Adicionar metadados
    dados$ano_extracao <- ano
    dados$uf_extracao <- uf
    dados$sistema <- "SIA"
    dados$data_extracao <- Sys.time()
    
    # Salvar no cache
    if (!is.null(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cache_file <- file.path(cache_dir, create_filename("SIA", ano, uf, extensao = "rds"))
      saveRDS(dados, cache_file)
      log_debug("Dados SIA salvos no cache: {cache_file}")
    }
    
    log_info("Dados SIA extraídos com sucesso - {nrow(dados)} registros")
    return(dados)
    
  }, error = function(e) {
    log_error("Erro ao extrair dados SIA {ano}/{uf}: {e$message}")
    return(data.frame())
  })
}

#' Extrair dados do Sistema de Informações sobre Nascidos Vivos (SINASC)
#' @param ano Ano para extração
#' @param uf UF para extração
#' @param cache_dir Diretório de cache
#' @param use_cache Usar cache se disponível
#' @return Data frame com dados do SINASC
extract_sinasc_data <- function(ano, uf, cache_dir = NULL, use_cache = TRUE) {
  
  log_info("Extraindo dados SINASC - Ano: {ano}, UF: {uf}")
  
  # Verificar cache
  if (use_cache && !is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, create_filename("SINASC", ano, uf, extensao = "rds"))
    
    if (file_is_cached(cache_file)) {
      log_info("Carregando dados SINASC do cache: {cache_file}")
      return(readRDS(cache_file))
    }
  }
  
  tryCatch({
    
    # Usar microdatasus para baixar dados
    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      uf = uf,
      information_system = "SINASC"
    )
    
    if (is.null(dados) || nrow(dados) == 0) {
      log_warn("Nenhum dado encontrado para SINASC {ano}/{uf}")
      return(data.frame())
    }
    
    # Adicionar metadados
    dados$ano_extracao <- ano
    dados$uf_extracao <- uf
    dados$sistema <- "SINASC"
    dados$data_extracao <- Sys.time()
    
    # Salvar no cache
    if (!is.null(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cache_file <- file.path(cache_dir, create_filename("SINASC", ano, uf, extensao = "rds"))
      saveRDS(dados, cache_file)
      log_debug("Dados SINASC salvos no cache: {cache_file}")
    }
    
    log_info("Dados SINASC extraídos com sucesso - {nrow(dados)} registros")
    return(dados)
    
  }, error = function(e) {
    log_error("Erro ao extrair dados SINASC {ano}/{uf}: {e$message}")
    return(data.frame())
  })
}

#' Extrair dados do Sistema de Informação de Agravos de Notificação (SINAN)
#' @param ano Ano para extração
#' @param uf UF para extração
#' @param agravo Código do agravo
#' @param cache_dir Diretório de cache
#' @param use_cache Usar cache se disponível
#' @return Data frame com dados do SINAN
extract_sinan_data <- function(ano, uf, agravo, cache_dir = NULL, use_cache = TRUE) {
  
  log_info("Extraindo dados SINAN - Ano: {ano}, UF: {uf}, Agravo: {agravo}")
  
  # Verificar cache
  if (use_cache && !is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, create_filename("SINAN", ano, uf, agravo, extensao = "rds"))
    
    if (file_is_cached(cache_file)) {
      log_info("Carregando dados SINAN do cache: {cache_file}")
      return(readRDS(cache_file))
    }
  }
  
  tryCatch({
    
    # Usar microdatasus para baixar dados
    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      uf = uf,
      information_system = "SINAN",
      vars = agravo
    )
    
    if (is.null(dados) || nrow(dados) == 0) {
      log_warn("Nenhum dado encontrado para SINAN {agravo} {ano}/{uf}")
      return(data.frame())
    }
    
    # Adicionar metadados
    dados$ano_extracao <- ano
    dados$uf_extracao <- uf
    dados$agravo <- agravo
    dados$sistema <- "SINAN"
    dados$data_extracao <- Sys.time()
    
    # Salvar no cache
    if (!is.null(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cache_file <- file.path(cache_dir, create_filename("SINAN", ano, uf, agravo, extensao = "rds"))
      saveRDS(dados, cache_file)
      log_debug("Dados SINAN salvos no cache: {cache_file}")
    }
    
    log_info("Dados SINAN extraídos com sucesso - {nrow(dados)} registros")
    return(dados)
    
  }, error = function(e) {
    log_error("Erro ao extrair dados SINAN {agravo} {ano}/{uf}: {e$message}")
    return(data.frame())
  })
}

#' Extrair dados do Cadastro Nacional de Estabelecimentos de Saúde (CNES)
#' @param ano Ano para extração
#' @param uf UF para extração
#' @param cache_dir Diretório de cache
#' @param use_cache Usar cache se disponível
#' @return Data frame com dados do CNES
extract_cnes_data <- function(ano, uf, cache_dir = NULL, use_cache = TRUE) {
  
  log_info("Extraindo dados CNES - Ano: {ano}, UF: {uf}")
  
  # Verificar cache
  if (use_cache && !is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, create_filename("CNES", ano, uf, extensao = "rds"))
    
    if (file_is_cached(cache_file)) {
      log_info("Carregando dados CNES do cache: {cache_file}")
      return(readRDS(cache_file))
    }
  }
  
  tryCatch({
    
    # Usar microdatasus para baixar dados
    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      uf = uf,
      information_system = "CNES"
    )
    
    if (is.null(dados) || nrow(dados) == 0) {
      log_warn("Nenhum dado encontrado para CNES {ano}/{uf}")
      return(data.frame())
    }
    
    # Adicionar metadados
    dados$ano_extracao <- ano
    dados$uf_extracao <- uf
    dados$sistema <- "CNES"
    dados$data_extracao <- Sys.time()
    
    # Salvar no cache
    if (!is.null(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cache_file <- file.path(cache_dir, create_filename("CNES", ano, uf, extensao = "rds"))
      saveRDS(dados, cache_file)
      log_debug("Dados CNES salvos no cache: {cache_file}")
    }
    
    log_info("Dados CNES extraídos com sucesso - {nrow(dados)} registros")
    return(dados)
    
  }, error = function(e) {
    log_error("Erro ao extrair dados CNES {ano}/{uf}: {e$message}")
    return(data.frame())
  })
}

#' Função principal de extração para um sistema específico
#' @param sistema Nome do sistema (SIM, SIH, SIA, SINASC, SINAN, CNES)
#' @param anos Vetor de anos
#' @param ufs Vetor de UFs
#' @param config Configuração do pipeline
#' @param agravos Vetor de agravos (apenas para SINAN)
#' @return Lista com dados extraídos
extract_system_data <- function(sistema, anos, ufs, config, agravos = NULL) {
  
  log_info("Iniciando extração do sistema {sistema}")
  
  # Validar parâmetros
  anos <- validate_years(anos, sistema)
  ufs <- validate_ufs(ufs)
  
  # Configurar cache
  cache_dir <- if (config$cache$ativo) config$cache$diretorio else NULL
  
  # Lista para armazenar resultados
  resultados <- list()
  
  # Função de extração baseada no sistema
  extract_func <- switch(sistema,
                        "SIM" = extract_sim_data,
                        "SIH" = extract_sih_data,
                        "SIA" = extract_sia_data,
                        "SINASC" = extract_sinasc_data,
                        "SINAN" = extract_sinan_data,
                        "CNES" = extract_cnes_data,
                        stop("Sistema não reconhecido: ", sistema))
  
  # Criar combinações de ano/UF
  if (sistema == "SINAN" && !is.null(agravos)) {
    # Para SINAN, incluir agravos
    combinacoes <- expand.grid(
      ano = anos,
      uf = ufs,
      agravo = agravos,
      stringsAsFactors = FALSE
    )
    
    # Extrair dados para cada combinação
    for (i in 1:nrow(combinacoes)) {
      comb <- combinacoes[i, ]
      
      dados <- extract_func(
        ano = comb$ano,
        uf = comb$uf,
        agravo = comb$agravo,
        cache_dir = cache_dir,
        use_cache = config$cache$ativo
      )
      
      if (nrow(dados) > 0) {
        chave <- paste(sistema, comb$agravo, comb$ano, comb$uf, sep = "_")
        resultados[[chave]] <- dados
      }
      
      # Pausa entre requisições para não sobrecarregar o servidor
      Sys.sleep(config$rede$intervalo_tentativas)
    }
    
  } else {
    # Para outros sistemas
    combinacoes <- expand.grid(
      ano = anos,
      uf = ufs,
      stringsAsFactors = FALSE
    )
    
    # Extrair dados para cada combinação
    for (i in 1:nrow(combinacoes)) {
      comb <- combinacoes[i, ]
      
      dados <- extract_func(
        ano = comb$ano,
        uf = comb$uf,
        cache_dir = cache_dir,
        use_cache = config$cache$ativo
      )
      
      if (nrow(dados) > 0) {
        chave <- paste(sistema, comb$ano, comb$uf, sep = "_")
        resultados[[chave]] <- dados
      }
      
      # Pausa entre requisições
      Sys.sleep(config$rede$intervalo_tentativas)
    }
  }
  
  log_info("Extração do sistema {sistema} concluída - {length(resultados)} datasets")
  
  return(resultados)
}

#' Função principal para extrair todos os sistemas configurados
#' @param config Configuração do pipeline
#' @return Lista com todos os dados extraídos
extract_all_systems <- function(config) {
  
  log_info("Iniciando extração de todos os sistemas configurados")
  
  # Lista para armazenar todos os resultados
  all_data <- list()
  
  # Extrair dados de cada sistema ativo
  for (sistema_nome in names(config$sistemas)) {
    sistema_config <- config$sistemas[[sistema_nome]]
    
    if (!sistema_config$ativo) {
      log_info("Sistema {sistema_nome} desativado - pulando")
      next
    }
    
    log_info("Processando sistema: {sistema_nome}")
    
    # Extrair dados do sistema
    if (sistema_nome == "SINAN") {
      dados_sistema <- extract_system_data(
        sistema = sistema_nome,
        anos = sistema_config$anos,
        ufs = sistema_config$uf,
        config = config,
        agravos = sistema_config$agravos
      )
    } else {
      dados_sistema <- extract_system_data(
        sistema = sistema_nome,
        anos = sistema_config$anos,
        ufs = sistema_config$uf,
        config = config
      )
    }
    
    # Adicionar aos resultados
    all_data[[sistema_nome]] <- dados_sistema
  }
  
  log_info("Extração de todos os sistemas concluída")
  
  return(all_data)
}