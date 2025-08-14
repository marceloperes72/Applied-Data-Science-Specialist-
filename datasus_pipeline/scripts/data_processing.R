# =============================================================================
# Funções de Processamento de Dados - Pipeline DATASUS
# =============================================================================

# Carregar bibliotecas
suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(stringr)
  library(logger)
  library(janitor)
  library(purrr)
})

# Carregar utilitários
source("scripts/utils.R")

#' Limpar e padronizar nomes de colunas
#' @param data Data frame com dados
#' @return Data frame com nomes de colunas padronizados
clean_column_names <- function(data) {
  
  if (nrow(data) == 0) {
    return(data)
  }
  
  # Usar janitor para limpar nomes
  data <- janitor::clean_names(data)
  
  # Padronizações específicas comuns no DATASUS
  names(data) <- gsub("^dt_", "data_", names(data))
  names(data) <- gsub("^cd_", "codigo_", names(data))
  names(data) <- gsub("^nr_", "numero_", names(data))
  names(data) <- gsub("^nm_", "nome_", names(data))
  names(data) <- gsub("^vl_", "valor_", names(data))
  names(data) <- gsub("^qt_", "quantidade_", names(data))
  
  return(data)
}

#' Converter datas do formato DATASUS
#' @param data Data frame
#' @param date_columns Vetor com nomes das colunas de data
#' @return Data frame com datas convertidas
convert_datasus_dates <- function(data, date_columns = NULL) {
  
  if (nrow(data) == 0 || is.null(date_columns)) {
    return(data)
  }
  
  # Identificar colunas de data automaticamente se não especificadas
  if (is.null(date_columns)) {
    date_columns <- names(data)[grepl("^data_|^dt_|_data$|_dt$", names(data), ignore.case = TRUE)]
  }
  
  # Filtrar apenas colunas que existem no dataset
  date_columns <- date_columns[date_columns %in% names(data)]
  
  if (length(date_columns) == 0) {
    return(data)
  }
  
  for (col in date_columns) {
    tryCatch({
      
      # Remover valores NA e vazios
      valid_dates <- data[[col]][!is.na(data[[col]]) & data[[col]] != ""]
      
      if (length(valid_dates) == 0) {
        next
      }
      
      # Detectar formato da data
      sample_date <- valid_dates[1]
      
      if (nchar(sample_date) == 8) {
        # Formato DDMMAAAA
        data[[col]] <- as.Date(data[[col]], format = "%d%m%Y")
      } else if (nchar(sample_date) == 10) {
        # Formato DD/MM/AAAA ou AAAA-MM-DD
        if (grepl("/", sample_date)) {
          data[[col]] <- as.Date(data[[col]], format = "%d/%m/%Y")
        } else if (grepl("-", sample_date)) {
          data[[col]] <- as.Date(data[[col]])
        }
      }
      
      log_debug("Coluna de data convertida: {col}")
      
    }, error = function(e) {
      log_warn("Erro ao converter data na coluna {col}: {e$message}")
    })
  }
  
  return(data)
}

#' Padronizar códigos de município
#' @param data Data frame
#' @param municipio_columns Colunas com códigos de município
#' @return Data frame com códigos padronizados
standardize_municipality_codes <- function(data, municipio_columns = NULL) {
  
  if (nrow(data) == 0) {
    return(data)
  }
  
  # Identificar colunas de município automaticamente
  if (is.null(municipio_columns)) {
    municipio_columns <- names(data)[grepl("munic|codigo_ibge|cod_mun", names(data), ignore.case = TRUE)]
  }
  
  municipio_columns <- municipio_columns[municipio_columns %in% names(data)]
  
  for (col in municipio_columns) {
    tryCatch({
      
      # Converter para character e remover espaços
      data[[col]] <- trimws(as.character(data[[col]]))
      
      # Garantir 6 dígitos (código IBGE de município)
      data[[col]] <- ifelse(
        nchar(data[[col]]) == 6,
        data[[col]],
        str_pad(data[[col]], 6, pad = "0")
      )
      
      # Remover códigos inválidos (menos de 6 dígitos após padding)
      data[[col]] <- ifelse(
        nchar(data[[col]]) != 6 | !grepl("^[0-9]+$", data[[col]]),
        NA,
        data[[col]]
      )
      
      log_debug("Códigos de município padronizados na coluna: {col}")
      
    }, error = function(e) {
      log_warn("Erro ao padronizar códigos de município na coluna {col}: {e$message}")
    })
  }
  
  return(data)
}

#' Padronizar códigos CID
#' @param data Data frame
#' @param cid_columns Colunas com códigos CID
#' @return Data frame com códigos CID padronizados
standardize_cid_codes <- function(data, cid_columns = NULL) {
  
  if (nrow(data) == 0) {
    return(data)
  }
  
  # Identificar colunas CID automaticamente
  if (is.null(cid_columns)) {
    cid_columns <- names(data)[grepl("cid|causabas|causa_|diagnostico", names(data), ignore.case = TRUE)]
  }
  
  cid_columns <- cid_columns[cid_columns %in% names(data)]
  
  for (col in cid_columns) {
    tryCatch({
      
      # Converter para character e limpar
      data[[col]] <- toupper(trimws(as.character(data[[col]])))
      
      # Remover pontos e hífen
      data[[col]] <- gsub("[.-]", "", data[[col]])
      
      # Verificar se segue padrão CID (letra + números)
      data[[col]] <- ifelse(
        grepl("^[A-Z][0-9]{2,3}$", data[[col]]),
        data[[col]],
        NA
      )
      
      log_debug("Códigos CID padronizados na coluna: {col}")
      
    }, error = function(e) {
      log_warn("Erro ao padronizar códigos CID na coluna {col}: {e$message}")
    })
  }
  
  return(data)
}

#' Limpar e validar campos de idade
#' @param data Data frame
#' @param idade_columns Colunas com idade
#' @return Data frame com idades limpas
clean_age_fields <- function(data, idade_columns = NULL) {
  
  if (nrow(data) == 0) {
    return(data)
  }
  
  # Identificar colunas de idade
  if (is.null(idade_columns)) {
    idade_columns <- names(data)[grepl("idade|age", names(data), ignore.case = TRUE)]
  }
  
  idade_columns <- idade_columns[idade_columns %in% names(data)]
  
  for (col in idade_columns) {
    tryCatch({
      
      # Converter para numérico
      data[[col]] <- as.numeric(data[[col]])
      
      # Remover idades inválidas (menores que 0 ou maiores que 150)
      data[[col]] <- ifelse(
        data[[col]] < 0 | data[[col]] > 150,
        NA,
        data[[col]]
      )
      
      log_debug("Campo de idade limpo: {col}")
      
    }, error = function(e) {
      log_warn("Erro ao limpar campo de idade {col}: {e$message}")
    })
  }
  
  return(data)
}

#' Padronizar campos de sexo
#' @param data Data frame
#' @param sexo_columns Colunas com sexo
#' @return Data frame com sexo padronizado
standardize_sex_fields <- function(data, sexo_columns = NULL) {
  
  if (nrow(data) == 0) {
    return(data)
  }
  
  # Identificar colunas de sexo
  if (is.null(sexo_columns)) {
    sexo_columns <- names(data)[grepl("sexo|sex", names(data), ignore.case = TRUE)]
  }
  
  sexo_columns <- sexo_columns[sexo_columns %in% names(data)]
  
  for (col in sexo_columns) {
    tryCatch({
      
      # Converter para character e maiúsculo
      data[[col]] <- toupper(trimws(as.character(data[[col]])))
      
      # Padronizar valores
      data[[col]] <- case_when(
        data[[col]] %in% c("1", "M", "MASC", "MASCULINO") ~ "M",
        data[[col]] %in% c("2", "F", "FEM", "FEMININO") ~ "F",
        data[[col]] %in% c("3", "I", "IGN", "IGNORADO") ~ "I",
        TRUE ~ NA_character_
      )
      
      log_debug("Campo de sexo padronizado: {col}")
      
    }, error = function(e) {
      log_warn("Erro ao padronizar campo de sexo {col}: {e$message}")
    })
  }
  
  return(data)
}

#' Processar dados do SIM (Sistema de Informações sobre Mortalidade)
#' @param data Data frame com dados do SIM
#' @return Data frame processado
process_sim_data <- function(data) {
  
  if (nrow(data) == 0) {
    log_warn("Dataset SIM vazio")
    return(data)
  }
  
  log_info("Processando dados SIM - {nrow(data)} registros")
  
  # Limpar nomes das colunas
  data <- clean_column_names(data)
  
  # Converter datas
  date_cols <- c("data_obito", "data_nascimento", "data_cadastro")
  data <- convert_datasus_dates(data, date_cols)
  
  # Padronizar códigos
  data <- standardize_municipality_codes(data)
  data <- standardize_cid_codes(data)
  
  # Limpar campos demográficos
  data <- clean_age_fields(data)
  data <- standardize_sex_fields(data)
  
  # Criar campos derivados úteis
  if ("data_obito" %in% names(data) && "data_nascimento" %in% names(data)) {
    data$idade_calculada <- as.numeric(difftime(data$data_obito, data$data_nascimento, units = "days")) / 365.25
  }
  
  # Adicionar ano do óbito
  if ("data_obito" %in% names(data)) {
    data$ano_obito <- year(data$data_obito)
  }
  
  log_info("Processamento SIM concluído")
  
  return(data)
}

#' Processar dados do SIH (Sistema de Informações Hospitalares)
#' @param data Data frame com dados do SIH
#' @return Data frame processado
process_sih_data <- function(data) {
  
  if (nrow(data) == 0) {
    log_warn("Dataset SIH vazio")
    return(data)
  }
  
  log_info("Processando dados SIH - {nrow(data)} registros")
  
  # Limpar nomes das colunas
  data <- clean_column_names(data)
  
  # Converter datas
  date_cols <- c("data_internacao", "data_saida", "data_nascimento")
  data <- convert_datasus_dates(data, date_cols)
  
  # Padronizar códigos
  data <- standardize_municipality_codes(data)
  data <- standardize_cid_codes(data)
  
  # Limpar campos demográficos
  data <- clean_age_fields(data)
  data <- standardize_sex_fields(data)
  
  # Calcular tempo de permanência
  if ("data_internacao" %in% names(data) && "data_saida" %in% names(data)) {
    data$tempo_permanencia <- as.numeric(difftime(data$data_saida, data$data_internacao, units = "days"))
  }
  
  # Validar valores monetários
  valor_cols <- names(data)[grepl("valor_|vl_", names(data))]
  for (col in valor_cols) {
    if (col %in% names(data)) {
      data[[col]] <- as.numeric(data[[col]])
      data[[col]] <- ifelse(data[[col]] < 0, NA, data[[col]])
    }
  }
  
  log_info("Processamento SIH concluído")
  
  return(data)
}

#' Processar dados do SIA (Sistema de Informações Ambulatoriais)
#' @param data Data frame com dados do SIA
#' @return Data frame processado
process_sia_data <- function(data) {
  
  if (nrow(data) == 0) {
    log_warn("Dataset SIA vazio")
    return(data)
  }
  
  log_info("Processando dados SIA - {nrow(data)} registros")
  
  # Limpar nomes das colunas
  data <- clean_column_names(data)
  
  # Converter datas
  date_cols <- c("data_atendimento", "data_nascimento")
  data <- convert_datasus_dates(data, date_cols)
  
  # Padronizar códigos
  data <- standardize_municipality_codes(data)
  data <- standardize_cid_codes(data)
  
  # Limpar campos demográficos
  data <- clean_age_fields(data)
  data <- standardize_sex_fields(data)
  
  # Validar quantidades e valores
  quant_cols <- names(data)[grepl("quantidade_|qt_", names(data))]
  for (col in quant_cols) {
    if (col %in% names(data)) {
      data[[col]] <- as.numeric(data[[col]])
      data[[col]] <- ifelse(data[[col]] < 0, NA, data[[col]])
    }
  }
  
  log_info("Processamento SIA concluído")
  
  return(data)
}

#' Processar dados do SINASC (Sistema de Informações sobre Nascidos Vivos)
#' @param data Data frame com dados do SINASC
#' @return Data frame processado
process_sinasc_data <- function(data) {
  
  if (nrow(data) == 0) {
    log_warn("Dataset SINASC vazio")
    return(data)
  }
  
  log_info("Processando dados SINASC - {nrow(data)} registros")
  
  # Limpar nomes das colunas
  data <- clean_column_names(data)
  
  # Converter datas
  date_cols <- c("data_nascimento", "data_ultima_menstruacao")
  data <- convert_datasus_dates(data, date_cols)
  
  # Padronizar códigos
  data <- standardize_municipality_codes(data)
  
  # Limpar campos específicos do SINASC
  data <- standardize_sex_fields(data)
  
  # Validar peso ao nascer
  if ("peso" %in% names(data)) {
    data$peso <- as.numeric(data$peso)
    data$peso <- ifelse(data$peso < 500 | data$peso > 6000, NA, data$peso)
  }
  
  # Classificar peso ao nascer
  if ("peso" %in% names(data)) {
    data$classificacao_peso <- case_when(
      data$peso < 1500 ~ "Muito baixo peso",
      data$peso < 2500 ~ "Baixo peso",
      data$peso >= 2500 & data$peso < 4000 ~ "Peso adequado",
      data$peso >= 4000 ~ "Macrossomia",
      TRUE ~ "Não informado"
    )
  }
  
  # Validar idade da mãe
  if ("idade_mae" %in% names(data)) {
    data$idade_mae <- as.numeric(data$idade_mae)
    data$idade_mae <- ifelse(data$idade_mae < 10 | data$idade_mae > 60, NA, data$idade_mae)
  }
  
  log_info("Processamento SINASC concluído")
  
  return(data)
}

#' Processar dados do SINAN (Sistema de Informação de Agravos de Notificação)
#' @param data Data frame com dados do SINAN
#' @return Data frame processado
process_sinan_data <- function(data) {
  
  if (nrow(data) == 0) {
    log_warn("Dataset SINAN vazio")
    return(data)
  }
  
  log_info("Processando dados SINAN - {nrow(data)} registros")
  
  # Limpar nomes das colunas
  data <- clean_column_names(data)
  
  # Converter datas
  date_cols <- c("data_notificacao", "data_primeiros_sintomas", "data_nascimento")
  data <- convert_datasus_dates(data, date_cols)
  
  # Padronizar códigos
  data <- standardize_municipality_codes(data)
  data <- standardize_cid_codes(data)
  
  # Limpar campos demográficos
  data <- clean_age_fields(data)
  data <- standardize_sex_fields(data)
  
  # Calcular tempo entre sintomas e notificação
  if ("data_notificacao" %in% names(data) && "data_primeiros_sintomas" %in% names(data)) {
    data$dias_sintomas_notificacao <- as.numeric(difftime(data$data_notificacao, data$data_primeiros_sintomas, units = "days"))
  }
  
  log_info("Processamento SINAN concluído")
  
  return(data)
}

#' Processar dados do CNES (Cadastro Nacional de Estabelecimentos de Saúde)
#' @param data Data frame com dados do CNES
#' @return Data frame processado
process_cnes_data <- function(data) {
  
  if (nrow(data) == 0) {
    log_warn("Dataset CNES vazio")
    return(data)
  }
  
  log_info("Processando dados CNES - {nrow(data)} registros")
  
  # Limpar nomes das colunas
  data <- clean_column_names(data)
  
  # Padronizar códigos
  data <- standardize_municipality_codes(data)
  
  # Limpar CNES
  if ("codigo_cnes" %in% names(data)) {
    data$codigo_cnes <- str_pad(as.character(data$codigo_cnes), 7, pad = "0")
  }
  
  log_info("Processamento CNES concluído")
  
  return(data)
}

#' Função principal de processamento baseada no sistema
#' @param data Data frame com dados
#' @param sistema Nome do sistema
#' @return Data frame processado
process_system_data <- function(data, sistema) {
  
  if (nrow(data) == 0) {
    return(data)
  }
  
  # Aplicar processamento específico por sistema
  processed_data <- switch(sistema,
                          "SIM" = process_sim_data(data),
                          "SIH" = process_sih_data(data),
                          "SIA" = process_sia_data(data),
                          "SINASC" = process_sinasc_data(data),
                          "SINAN" = process_sinan_data(data),
                          "CNES" = process_cnes_data(data),
                          {
                            log_warn("Sistema não reconhecido: {sistema}")
                            data
                          })
  
  # Adicionar metadados de processamento
  processed_data$data_processamento <- Sys.time()
  processed_data$versao_processamento <- "1.0.0"
  
  return(processed_data)
}

#' Validar qualidade dos dados processados
#' @param data Data frame processado
#' @param sistema Nome do sistema
#' @return Lista com estatísticas de qualidade
validate_data_quality <- function(data, sistema) {
  
  if (nrow(data) == 0) {
    return(list(
      total_registros = 0,
      campos_obrigatorios_ok = FALSE,
      percentual_completude = 0,
      observacoes = "Dataset vazio"
    ))
  }
  
  # Estatísticas básicas
  total_registros <- nrow(data)
  total_colunas <- ncol(data)
  
  # Calcular completude
  missing_data <- sapply(data, function(x) sum(is.na(x)))
  completude_por_coluna <- (total_registros - missing_data) / total_registros * 100
  completude_geral <- mean(completude_por_coluna)
  
  # Campos críticos por sistema
  campos_criticos <- switch(sistema,
                           "SIM" = c("data_obito", "sexo"),
                           "SIH" = c("data_internacao", "sexo"),
                           "SIA" = c("data_atendimento"),
                           "SINASC" = c("data_nascimento", "sexo"),
                           "SINAN" = c("data_notificacao"),
                           "CNES" = c("codigo_cnes"),
                           character(0))
  
  # Verificar campos críticos
  campos_criticos_presentes <- campos_criticos[campos_criticos %in% names(data)]
  if (length(campos_criticos_presentes) > 0) {
    completude_criticos <- completude_por_coluna[campos_criticos_presentes]
    campos_criticos_ok <- all(completude_criticos >= 80)  # 80% de completude mínima
  } else {
    campos_criticos_ok <- TRUE
  }
  
  # Detectar outliers em campos numéricos
  numeric_cols <- sapply(data, is.numeric)
  outliers_detectados <- 0
  
  if (any(numeric_cols)) {
    for (col in names(data)[numeric_cols]) {
      Q1 <- quantile(data[[col]], 0.25, na.rm = TRUE)
      Q3 <- quantile(data[[col]], 0.75, na.rm = TRUE)
      IQR <- Q3 - Q1
      outliers <- sum(data[[col]] < (Q1 - 1.5 * IQR) | data[[col]] > (Q3 + 1.5 * IQR), na.rm = TRUE)
      outliers_detectados <- outliers_detectados + outliers
    }
  }
  
  # Preparar relatório
  quality_report <- list(
    sistema = sistema,
    total_registros = total_registros,
    total_colunas = total_colunas,
    completude_geral = round(completude_geral, 2),
    campos_criticos_ok = campos_criticos_ok,
    outliers_detectados = outliers_detectados,
    campos_com_baixa_completude = names(completude_por_coluna[completude_por_coluna < 50]),
    timestamp = Sys.time()
  )
  
  return(quality_report)
}

#' Processar todos os datasets de um sistema
#' @param system_data Lista com datasets do sistema
#' @param sistema Nome do sistema
#' @param config Configuração do pipeline
#' @return Lista com dados processados
process_all_system_data <- function(system_data, sistema, config) {
  
  log_info("Iniciando processamento de dados do sistema {sistema}")
  
  # Lista para armazenar dados processados
  processed_data <- list()
  quality_reports <- list()
  
  # Processar cada dataset
  for (dataset_name in names(system_data)) {
    
    log_info("Processando dataset: {dataset_name}")
    
    # Processar dados
    data_processed <- process_system_data(system_data[[dataset_name]], sistema)
    
    # Validar qualidade
    quality_report <- validate_data_quality(data_processed, sistema)
    
    # Armazenar resultados
    processed_data[[dataset_name]] <- data_processed
    quality_reports[[dataset_name]] <- quality_report
    
    # Salvar dados processados
    output_dir <- file.path(config$diretorios$dados_processados, sistema)
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    
    output_file <- file.path(output_dir, paste0(dataset_name, "_processed.", config$armazenamento$formato_saida))
    save_data_with_backup(data_processed, output_file, config$armazenamento$backup)
    
    # Log estatísticas
    log_info("Dataset {dataset_name} processado - {quality_report$total_registros} registros, {quality_report$completude_geral}% completude")
  }
  
  # Salvar relatórios de qualidade
  quality_file <- file.path(config$diretorios$dados_processados, sistema, "quality_reports.rds")
  saveRDS(quality_reports, quality_file)
  
  log_info("Processamento do sistema {sistema} concluído")
  
  return(list(
    data = processed_data,
    quality = quality_reports
  ))
}