#!/usr/bin/env Rscript

# =============================================================================
# PIPELINE PRINCIPAL - EXTRAÇÃO E PROCESSAMENTO DATASUS
# =============================================================================
#
# Este script executa o pipeline completo de extração e processamento
# de microdados do DATASUS usando o pacote microdatasus.
#
# Sistemas suportados:
# - SIM: Sistema de Informações sobre Mortalidade
# - SIH: Sistema de Informações Hospitalares
# - SIA: Sistema de Informações Ambulatoriais  
# - SINASC: Sistema de Informações sobre Nascidos Vivos
# - SINAN: Sistema de Informação de Agravos de Notificação
# - CNES: Cadastro Nacional de Estabelecimentos de Saúde
#
# Autor: Pipeline DATASUS
# Versão: 1.0.0
# =============================================================================

# Configurar ambiente
suppressPackageStartupMessages({
  library(here)
  library(logger)
  library(config)
  library(lubridate)
  library(dplyr)
})

# Definir diretório de trabalho
setwd(here::here())

# Carregar scripts do pipeline
source("scripts/utils.R")
source("scripts/extraction_functions.R")
source("scripts/data_processing.R")

#' Função principal do pipeline
#' @param config_file Caminho para arquivo de configuração
#' @param force_download Forçar download mesmo com cache válido
#' @param sistemas_especificos Vetor com sistemas específicos para processar
#' @param modo_teste Executar em modo teste (amostra pequena)
#' @return Lista com resultados do pipeline
main_pipeline <- function(config_file = "config/pipeline_config.yml", 
                         force_download = FALSE,
                         sistemas_especificos = NULL,
                         modo_teste = FALSE) {
  
  # ============================================================================
  # INICIALIZAÇÃO
  # ============================================================================
  
  cat("\n")
  cat("================================================================================\n")
  cat("                    PIPELINE DATASUS - SAÚDE PÚBLICA\n")
  cat("================================================================================\n")
  cat("Iniciando pipeline de extração e processamento de microdados DATASUS\n")
  cat("Data/Hora:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("================================================================================\n\n")
  
  # Registrar início
  inicio_pipeline <- Sys.time()
  
  # ============================================================================
  # CONFIGURAÇÃO
  # ============================================================================
  
  cat("📋 CARREGANDO CONFIGURAÇÕES...\n")
  
  # Carregar configuração
  tryCatch({
    config <- load_pipeline_config(config_file)
    cat("✅ Configuração carregada com sucesso\n")
  }, error = function(e) {
    stop("❌ Erro ao carregar configuração: ", e$message)
  })
  
  # Configurar logging
  setup_logging(
    log_level = config$log$nivel,
    log_file = config$log$arquivo
  )
  
  log_info("=== INICIANDO PIPELINE DATASUS ===")
  log_info("Versão: {config$pipeline$version}")
  log_info("Período: {config$periodo$inicio}-{config$periodo$fim}")
  
  # Criar estrutura de diretórios
  create_directories(config)
  
  # Configurar processamento paralelo
  if (config$processamento$paralelismo) {
    num_cores <- setup_parallel_processing(config$processamento$num_cores)
    cat("🚀 Processamento paralelo configurado:", num_cores, "cores\n")
  }
  
  # Limpar cache antigo se habilitado
  if (config$cache$ativo) {
    clean_old_cache(config$cache$diretorio, config$cache$tempo_expiracao)
    cat("🧹 Cache antigo limpo\n")
  }
  
  # Configurar modo teste
  if (modo_teste) {
    cat("⚠️  MODO TESTE ATIVADO - Processando amostra reduzida\n")
    log_warn("Pipeline executando em modo teste")
    
    # Reduzir período para teste
    config$periodo$inicio <- 2023
    config$periodo$fim <- 2023
    
    # Reduzir UFs para teste (apenas SP)
    for (sistema in names(config$sistemas)) {
      if (config$sistemas[[sistema]]$uf == "all") {
        config$sistemas[[sistema]]$uf <- "SP"
      }
    }
  }
  
  # Filtrar sistemas específicos se solicitado
  if (!is.null(sistemas_especificos)) {
    cat("🎯 Processando apenas sistemas específicos:", paste(sistemas_especificos, collapse = ", "), "\n")
    
    # Desativar sistemas não solicitados
    for (sistema in names(config$sistemas)) {
      if (!sistema %in% sistemas_especificos) {
        config$sistemas[[sistema]]$ativo <- FALSE
      }
    }
  }
  
  # ============================================================================
  # EXTRAÇÃO DE DADOS
  # ============================================================================
  
  cat("\n📊 INICIANDO EXTRAÇÃO DE DADOS...\n")
  
  # Listar sistemas ativos
  sistemas_ativos <- names(config$sistemas)[sapply(config$sistemas, function(x) x$ativo)]
  cat("Sistemas ativos:", paste(sistemas_ativos, collapse = ", "), "\n")
  
  # Extrair dados de todos os sistemas
  if (force_download && config$cache$ativo) {
    log_info("Forçando download - ignorando cache")
    config$cache$ativo <- FALSE
  }
  
  extracted_data <- list()
  extraction_errors <- list()
  
  for (sistema in sistemas_ativos) {
    cat("\n🔄 Extraindo dados do sistema:", sistema, "\n")
    
    tryCatch({
      
      if (sistema == "SINAN") {
        # SINAN tem agravos específicos
        system_data <- extract_system_data(
          sistema = sistema,
          anos = config$sistemas[[sistema]]$anos,
          ufs = config$sistemas[[sistema]]$uf,
          config = config,
          agravos = config$sistemas[[sistema]]$agravos
        )
      } else {
        # Outros sistemas
        system_data <- extract_system_data(
          sistema = sistema,
          anos = config$sistemas[[sistema]]$anos,
          ufs = config$sistemas[[sistema]]$uf,
          config = config
        )
      }
      
      extracted_data[[sistema]] <- system_data
      
      # Estatísticas da extração
      total_datasets <- length(system_data)
      total_registros <- sum(sapply(system_data, nrow))
      
      cat("✅", sistema, "concluído -", total_datasets, "datasets,", total_registros, "registros\n")
      log_info("Sistema {sistema} extraído: {total_datasets} datasets, {total_registros} registros")
      
    }, error = function(e) {
      error_msg <- paste("Erro na extração do sistema", sistema, ":", e$message)
      cat("❌", error_msg, "\n")
      log_error(error_msg)
      extraction_errors[[sistema]] <- e$message
    })
  }
  
  # ============================================================================
  # PROCESSAMENTO DE DADOS
  # ============================================================================
  
  cat("\n🔧 INICIANDO PROCESSAMENTO DE DADOS...\n")
  
  processed_data <- list()
  processing_errors <- list()
  quality_summary <- list()
  
  for (sistema in names(extracted_data)) {
    cat("🔄 Processando dados do sistema:", sistema, "\n")
    
    tryCatch({
      
      # Processar dados do sistema
      result <- process_all_system_data(
        system_data = extracted_data[[sistema]],
        sistema = sistema,
        config = config
      )
      
      processed_data[[sistema]] <- result$data
      quality_summary[[sistema]] <- result$quality
      
      # Estatísticas do processamento
      total_datasets <- length(result$data)
      total_registros <- sum(sapply(result$data, nrow))
      
      cat("✅", sistema, "processado -", total_datasets, "datasets,", total_registros, "registros\n")
      log_info("Sistema {sistema} processado: {total_datasets} datasets, {total_registros} registros")
      
    }, error = function(e) {
      error_msg <- paste("Erro no processamento do sistema", sistema, ":", e$message)
      cat("❌", error_msg, "\n")
      log_error(error_msg)
      processing_errors[[sistema]] <- e$message
    })
  }
  
  # ============================================================================
  # CONSOLIDAÇÃO E RELATÓRIOS
  # ============================================================================
  
  cat("\n📋 GERANDO RELATÓRIOS...\n")
  
  # Calcular estatísticas finais
  fim_pipeline <- Sys.time()
  tempo_execucao <- difftime(fim_pipeline, inicio_pipeline, units = "mins")
  
  # Resumo geral
  total_sistemas_processados <- length(processed_data)
  total_datasets_finais <- sum(sapply(processed_data, length))
  total_registros_finais <- sum(sapply(processed_data, function(x) sum(sapply(x, nrow))))
  
  # Criar relatório de execução
  execution_report <- list(
    pipeline_info = list(
      versao = config$pipeline$version,
      data_execucao = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      tempo_execucao_minutos = round(as.numeric(tempo_execucao), 2),
      modo_teste = modo_teste,
      config_file = config_file
    ),
    estatisticas = list(
      sistemas_configurados = length(sistemas_ativos),
      sistemas_processados = total_sistemas_processados,
      datasets_finais = total_datasets_finais,
      registros_finais = total_registros_finais
    ),
    sistemas_processados = names(processed_data),
    sistemas_com_erro_extracao = names(extraction_errors),
    sistemas_com_erro_processamento = names(processing_errors),
    extraction_errors = extraction_errors,
    processing_errors = processing_errors,
    quality_summary = quality_summary
  )
  
  # Salvar relatório de execução
  report_file <- file.path(config$diretorios$logs, paste0("execution_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds"))
  saveRDS(execution_report, report_file)
  
  # Gerar relatório de qualidade consolidado
  quality_report_file <- file.path(config$diretorios$dados_finais, "quality_summary.csv")
  if (length(quality_summary) > 0) {
    
    quality_df <- data.frame()
    
    for (sistema in names(quality_summary)) {
      for (dataset in names(quality_summary[[sistema]])) {
        quality_info <- quality_summary[[sistema]][[dataset]]
        
        row <- data.frame(
          sistema = sistema,
          dataset = dataset,
          registros = quality_info$total_registros,
          colunas = quality_info$total_colunas,
          completude_geral = quality_info$completude_geral,
          campos_criticos_ok = quality_info$campos_criticos_ok,
          outliers = quality_info$outliers_detectados,
          timestamp = as.character(quality_info$timestamp)
        )
        
        quality_df <- rbind(quality_df, row)
      }
    }
    
    readr::write_csv(quality_df, quality_report_file)
    cat("📊 Relatório de qualidade salvo:", quality_report_file, "\n")
  }
  
  # ============================================================================
  # FINALIZAÇÃO
  # ============================================================================
  
  cat("\n")
  cat("================================================================================\n")
  cat("                           PIPELINE CONCLUÍDO\n")
  cat("================================================================================\n")
  cat("Tempo de execução:", round(as.numeric(tempo_execucao), 2), "minutos\n")
  cat("Sistemas processados:", total_sistemas_processados, "/", length(sistemas_ativos), "\n")
  cat("Datasets finais:", total_datasets_finais, "\n")
  cat("Registros totais:", format(total_registros_finais, big.mark = ","), "\n")
  
  if (length(extraction_errors) > 0) {
    cat("⚠️  Erros de extração:", length(extraction_errors), "sistemas\n")
  }
  
  if (length(processing_errors) > 0) {
    cat("⚠️  Erros de processamento:", length(processing_errors), "sistemas\n")
  }
  
  cat("📁 Dados salvos em:", config$diretorios$dados_processados, "\n")
  cat("📋 Relatório de execução:", report_file, "\n")
  cat("================================================================================\n")
  
  log_info("=== PIPELINE CONCLUÍDO ===")
  log_info("Tempo execução: {round(as.numeric(tempo_execucao), 2)} minutos")
  log_info("Sistemas processados: {total_sistemas_processados}")
  log_info("Registros totais: {total_registros_finais}")
  
  # Retornar resultados
  return(list(
    success = TRUE,
    execution_report = execution_report,
    processed_data = processed_data,
    extraction_errors = extraction_errors,
    processing_errors = processing_errors,
    quality_summary = quality_summary
  ))
}

# ============================================================================
# FUNÇÕES AUXILIARES PARA EXECUÇÃO
# ============================================================================

#' Executar pipeline para um sistema específico
#' @param sistema Nome do sistema
#' @param config_file Arquivo de configuração
#' @return Resultados do sistema
run_single_system <- function(sistema, config_file = "config/pipeline_config.yml") {
  return(main_pipeline(
    config_file = config_file,
    sistemas_especificos = sistema
  ))
}

#' Executar pipeline em modo teste
#' @param config_file Arquivo de configuração
#' @return Resultados do teste
run_test_pipeline <- function(config_file = "config/pipeline_config.yml") {
  return(main_pipeline(
    config_file = config_file,
    modo_teste = TRUE
  ))
}

#' Forçar re-extração de dados (ignorar cache)
#' @param config_file Arquivo de configuração
#' @return Resultados da re-extração
run_forced_extraction <- function(config_file = "config/pipeline_config.yml") {
  return(main_pipeline(
    config_file = config_file,
    force_download = TRUE
  ))
}

# ============================================================================
# INTERFACE DE LINHA DE COMANDO
# ============================================================================

# Verificar se script está sendo executado diretamente
if (length(commandArgs(trailingOnly = TRUE)) > 0 || interactive() == FALSE) {
  
  # Parse argumentos da linha de comando
  args <- commandArgs(trailingOnly = TRUE)
  
  # Configurações padrão
  config_file <- "config/pipeline_config.yml"
  modo_teste <- FALSE
  force_download <- FALSE
  sistemas_especificos <- NULL
  
  # Parse argumentos
  if (length(args) > 0) {
    for (i in seq_along(args)) {
      arg <- args[i]
      
      if (arg == "--config" && i < length(args)) {
        config_file <- args[i + 1]
      } else if (arg == "--test") {
        modo_teste <- TRUE
      } else if (arg == "--force") {
        force_download <- TRUE
      } else if (arg == "--sistemas" && i < length(args)) {
        sistemas_especificos <- strsplit(args[i + 1], ",")[[1]]
      } else if (arg == "--help") {
        cat("\nPipeline DATASUS - Extração de Microdados de Saúde Pública\n\n")
        cat("Uso: Rscript main_pipeline.R [opções]\n\n")
        cat("Opções:\n")
        cat("  --config ARQUIVO    Arquivo de configuração (padrão: config/pipeline_config.yml)\n")
        cat("  --test              Executar em modo teste\n")
        cat("  --force             Forçar download (ignorar cache)\n")
        cat("  --sistemas LISTA    Sistemas específicos (ex: SIM,SIH,SINASC)\n")
        cat("  --help              Mostrar esta ajuda\n\n")
        cat("Exemplos:\n")
        cat("  Rscript main_pipeline.R\n")
        cat("  Rscript main_pipeline.R --test\n")
        cat("  Rscript main_pipeline.R --sistemas SIM,SINASC\n")
        cat("  Rscript main_pipeline.R --config config/custom.yml --force\n\n")
        quit(status = 0)
      }
    }
  }
  
  # Executar pipeline
  tryCatch({
    
    result <- main_pipeline(
      config_file = config_file,
      force_download = force_download,
      sistemas_especificos = sistemas_especificos,
      modo_teste = modo_teste
    )
    
    if (result$success) {
      cat("\n🎉 Pipeline executado com sucesso!\n")
      quit(status = 0)
    } else {
      cat("\n❌ Pipeline finalizado com erros.\n")
      quit(status = 1)
    }
    
  }, error = function(e) {
    cat("\n💥 Erro fatal no pipeline:", e$message, "\n")
    quit(status = 1)
  })
}