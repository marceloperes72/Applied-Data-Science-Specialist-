# =============================================================================
# EXEMPLOS DE USO - PIPELINE DATASUS
# =============================================================================
# 
# Este arquivo contém exemplos práticos de como analisar os dados processados
# pelo pipeline DATASUS. Execute os exemplos após rodar o pipeline.
#
# Autor: Pipeline DATASUS
# Versão: 1.0.0
# =============================================================================

library(dplyr)
library(ggplot2)
library(lubridate)
library(arrow)  # Para arquivos parquet

# =============================================================================
# EXEMPLO 1: ANÁLISE DE MORTALIDADE (SIM)
# =============================================================================

#' Análise básica de mortalidade
exemplo_analise_mortalidade <- function() {
  
  cat("=== ANÁLISE DE MORTALIDADE (SIM) ===\n")
  
  # Verificar se dados existem
  arquivo_sim <- "data/processed/SIM/SIM_2023_SP_processed.parquet"
  if (!file.exists(arquivo_sim)) {
    cat("❌ Dados SIM não encontrados. Execute o pipeline primeiro:\n")
    cat("   Rscript main_pipeline.R --sistemas SIM --test\n")
    return()
  }
  
  # Carregar dados
  sim_data <- read_parquet(arquivo_sim)
  
  cat("📊 Dados carregados:", nrow(sim_data), "óbitos\n")
  
  # Estatísticas básicas
  cat("\n--- Estatísticas Básicas ---\n")
  cat("Período:", min(sim_data$data_obito, na.rm = T), "a", max(sim_data$data_obito, na.rm = T), "\n")
  cat("Distribuição por sexo:\n")
  print(table(sim_data$sexo, useNA = "ifany"))
  
  # Idade média por sexo
  cat("\nIdade média por sexo:\n")
  idade_sexo <- sim_data %>%
    filter(!is.na(sexo), !is.na(idade)) %>%
    group_by(sexo) %>%
    summarise(
      idade_media = round(mean(idade), 1),
      idade_mediana = median(idade),
      n = n()
    )
  print(idade_sexo)
  
  # Top 10 causas de morte (CID)
  cat("\n--- Top 10 Causas de Morte ---\n")
  top_causas <- sim_data %>%
    filter(!is.na(causa_basica_cid)) %>%
    count(causa_basica_cid, sort = TRUE) %>%
    head(10)
  print(top_causas)
  
  # Gráfico: Distribuição de idade
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    p1 <- sim_data %>%
      filter(!is.na(idade), idade <= 100) %>%
      ggplot(aes(x = idade)) +
      geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
      labs(title = "Distribuição da Idade no Óbito",
           x = "Idade", y = "Frequência") +
      theme_minimal()
    
    print(p1)
  }
  
  cat("\n✅ Análise de mortalidade concluída!\n")
}

# =============================================================================
# EXEMPLO 2: ANÁLISE DE NASCIMENTOS (SINASC)
# =============================================================================

#' Análise de nascidos vivos
exemplo_analise_nascimentos <- function() {
  
  cat("\n=== ANÁLISE DE NASCIMENTOS (SINASC) ===\n")
  
  # Verificar se dados existem
  arquivo_sinasc <- "data/processed/SINASC/SINASC_2023_SP_processed.parquet"
  if (!file.exists(arquivo_sinasc)) {
    cat("❌ Dados SINASC não encontrados. Execute o pipeline primeiro:\n")
    cat("   Rscript main_pipeline.R --sistemas SINASC --test\n")
    return()
  }
  
  # Carregar dados
  sinasc_data <- read_parquet(arquivo_sinasc)
  
  cat("👶 Dados carregados:", nrow(sinasc_data), "nascimentos\n")
  
  # Estatísticas básicas
  cat("\n--- Estatísticas Básicas ---\n")
  cat("Distribuição por sexo:\n")
  print(table(sinasc_data$sexo, useNA = "ifany"))
  
  # Peso ao nascer
  if ("peso" %in% names(sinasc_data)) {
    cat("\nPeso ao nascer:\n")
    peso_stats <- sinasc_data %>%
      filter(!is.na(peso)) %>%
      summarise(
        peso_medio = round(mean(peso), 0),
        peso_mediano = median(peso),
        peso_min = min(peso),
        peso_max = max(peso),
        baixo_peso = sum(peso < 2500) / n() * 100
      )
    
    cat("Peso médio:", peso_stats$peso_medio, "g\n")
    cat("Peso mediano:", peso_stats$peso_mediano, "g\n")
    cat("Baixo peso (<2500g):", round(peso_stats$baixo_peso, 1), "%\n")
  }
  
  # Classificação de peso
  if ("classificacao_peso" %in% names(sinasc_data)) {
    cat("\nClassificação de peso:\n")
    print(table(sinasc_data$classificacao_peso, useNA = "ifany"))
  }
  
  # Idade materna
  if ("idade_mae" %in% names(sinasc_data)) {
    cat("\nIdade materna:\n")
    idade_mae_stats <- sinasc_data %>%
      filter(!is.na(idade_mae)) %>%
      summarise(
        idade_media = round(mean(idade_mae), 1),
        idade_mediana = median(idade_mae),
        adolescentes = sum(idade_mae < 20) / n() * 100,
        idade_avancada = sum(idade_mae >= 35) / n() * 100
      )
    
    cat("Idade média da mãe:", idade_mae_stats$idade_media, "anos\n")
    cat("Mães adolescentes (<20 anos):", round(idade_mae_stats$adolescentes, 1), "%\n")
    cat("Idade materna avançada (≥35 anos):", round(idade_mae_stats$idade_avancada, 1), "%\n")
  }
  
  cat("\n✅ Análise de nascimentos concluída!\n")
}

# =============================================================================
# EXEMPLO 3: ANÁLISE DE HOSPITALIZAÇÕES (SIH)
# =============================================================================

#' Análise de internações hospitalares
exemplo_analise_hospitalizacoes <- function() {
  
  cat("\n=== ANÁLISE DE HOSPITALIZAÇÕES (SIH) ===\n")
  
  # Verificar se dados existem
  arquivo_sih <- "data/processed/SIH/SIH_2023_SP_processed.parquet"
  if (!file.exists(arquivo_sih)) {
    cat("❌ Dados SIH não encontrados. Execute o pipeline primeiro:\n")
    cat("   Rscript main_pipeline.R --sistemas SIH --test\n")
    return()
  }
  
  # Carregar dados (apenas uma amostra se muito grande)
  if (file.size(arquivo_sih) > 100*1024*1024) {  # Se maior que 100MB
    cat("📊 Arquivo grande detectado, carregando amostra...\n")
    sih_data <- read_parquet(arquivo_sih) %>% 
      slice_sample(n = 50000)  # Amostra de 50k registros
  } else {
    sih_data <- read_parquet(arquivo_sih)
  }
  
  cat("🏥 Dados carregados:", nrow(sih_data), "internações\n")
  
  # Tempo de permanência
  if ("tempo_permanencia" %in% names(sih_data)) {
    cat("\n--- Tempo de Permanência ---\n")
    permanencia_stats <- sih_data %>%
      filter(!is.na(tempo_permanencia), tempo_permanencia > 0, tempo_permanencia <= 365) %>%
      summarise(
        permanencia_media = round(mean(tempo_permanencia), 1),
        permanencia_mediana = median(tempo_permanencia),
        permanencia_max = max(tempo_permanencia),
        internacoes_longas = sum(tempo_permanencia > 30) / n() * 100
      )
    
    cat("Permanência média:", permanencia_stats$permanencia_media, "dias\n")
    cat("Permanência mediana:", permanencia_stats$permanencia_mediana, "dias\n")
    cat("Internações longas (>30 dias):", round(permanencia_stats$internacoes_longas, 1), "%\n")
  }
  
  # Distribuição por sexo e faixa etária
  cat("\n--- Demografia ---\n")
  if ("sexo" %in% names(sih_data)) {
    print(table(sih_data$sexo, useNA = "ifany"))
  }
  
  # Valores (se disponível)
  valor_cols <- names(sih_data)[grepl("valor", names(sih_data))]
  if (length(valor_cols) > 0) {
    cat("\n--- Valores ---\n")
    for (col in valor_cols[1:min(3, length(valor_cols))]) {  # Max 3 colunas
      if (sum(!is.na(sih_data[[col]])) > 0) {
        valor_medio <- mean(sih_data[[col]], na.rm = TRUE)
        cat(col, "- Valor médio: R$", round(valor_medio, 2), "\n")
      }
    }
  }
  
  cat("\n✅ Análise de hospitalizações concluída!\n")
}

# =============================================================================
# EXEMPLO 4: ANÁLISE COMPARATIVA ENTRE SISTEMAS
# =============================================================================

#' Comparar indicadores entre sistemas
exemplo_analise_comparativa <- function() {
  
  cat("\n=== ANÁLISE COMPARATIVA ===\n")
  
  # Preparar resumo de cada sistema
  sistemas_stats <- list()
  
  # SIM
  arquivo_sim <- "data/processed/SIM/SIM_2023_SP_processed.parquet"
  if (file.exists(arquivo_sim)) {
    sim_data <- read_parquet(arquivo_sim)
    sistemas_stats$SIM <- list(
      sistema = "SIM",
      registros = nrow(sim_data),
      periodo = paste(min(sim_data$data_obito, na.rm = T), "a", max(sim_data$data_obito, na.rm = T)),
      sexo_masculino_pct = round(sum(sim_data$sexo == "M", na.rm = T) / sum(!is.na(sim_data$sexo)) * 100, 1)
    )
  }
  
  # SINASC
  arquivo_sinasc <- "data/processed/SINASC/SINASC_2023_SP_processed.parquet"
  if (file.exists(arquivo_sinasc)) {
    sinasc_data <- read_parquet(arquivo_sinasc)
    sistemas_stats$SINASC <- list(
      sistema = "SINASC",
      registros = nrow(sinasc_data),
      periodo = paste(min(sinasc_data$data_nascimento, na.rm = T), "a", max(sinasc_data$data_nascimento, na.rm = T)),
      sexo_masculino_pct = round(sum(sinasc_data$sexo == "M", na.rm = T) / sum(!is.na(sinasc_data$sexo)) * 100, 1)
    )
  }
  
  # SIH
  arquivo_sih <- "data/processed/SIH/SIH_2023_SP_processed.parquet"
  if (file.exists(arquivo_sih)) {
    sih_data <- read_parquet(arquivo_sih)
    sistemas_stats$SIH <- list(
      sistema = "SIH",
      registros = nrow(sih_data),
      periodo = paste(min(sih_data$data_internacao, na.rm = T), "a", max(sih_data$data_internacao, na.rm = T)),
      sexo_masculino_pct = round(sum(sih_data$sexo == "M", na.rm = T) / sum(!is.na(sih_data$sexo)) * 100, 1)
    )
  }
  
  # Criar tabela comparativa
  if (length(sistemas_stats) > 0) {
    comparativo <- do.call(rbind, lapply(sistemas_stats, data.frame))
    
    cat("📊 Resumo Comparativo:\n")
    print(comparativo)
    
    # Razão masculinidade (aproximada)
    cat("\nRazão de masculinidade (% homens):\n")
    for (i in 1:nrow(comparativo)) {
      cat(sprintf("%s: %s%%\n", comparativo$sistema[i], comparativo$sexo_masculino_pct[i]))
    }
  }
  
  cat("\n✅ Análise comparativa concluída!\n")
}

# =============================================================================
# EXEMPLO 5: RELATÓRIO DE QUALIDADE
# =============================================================================

#' Gerar relatório de qualidade dos dados
exemplo_relatorio_qualidade <- function() {
  
  cat("\n=== RELATÓRIO DE QUALIDADE ===\n")
  
  # Verificar relatório de qualidade gerado pelo pipeline
  quality_file <- "data/final/quality_summary.csv"
  if (file.exists(quality_file)) {
    quality_data <- read.csv(quality_file)
    
    cat("📋 Resumo de Qualidade:\n")
    print(quality_data)
    
    # Alertas de qualidade
    cat("\n⚠️  Alertas de Qualidade:\n")
    
    # Completude baixa
    baixa_completude <- quality_data[quality_data$completude_geral < 80, ]
    if (nrow(baixa_completude) > 0) {
      cat("- Datasets com completude <80%:\n")
      for (i in 1:nrow(baixa_completude)) {
        cat(sprintf("  %s/%s: %s%%\n", 
                   baixa_completude$sistema[i], 
                   baixa_completude$dataset[i], 
                   baixa_completude$completude_geral[i]))
      }
    }
    
    # Campos críticos com problema
    problemas_criticos <- quality_data[!quality_data$campos_criticos_ok, ]
    if (nrow(problemas_criticos) > 0) {
      cat("- Datasets com problemas em campos críticos:\n")
      print(problemas_criticos[, c("sistema", "dataset")])
    }
    
    # Muitos outliers
    muitos_outliers <- quality_data[quality_data$outliers > 1000, ]
    if (nrow(muitos_outliers) > 0) {
      cat("- Datasets com muitos outliers (>1000):\n")
      print(muitos_outliers[, c("sistema", "dataset", "outliers")])
    }
    
    if (nrow(baixa_completude) == 0 && nrow(problemas_criticos) == 0 && nrow(muitos_outliers) == 0) {
      cat("✅ Nenhum problema crítico de qualidade detectado!\n")
    }
    
  } else {
    cat("❌ Relatório de qualidade não encontrado. Execute o pipeline primeiro.\n")
  }
  
  cat("\n✅ Relatório de qualidade concluído!\n")
}

# =============================================================================
# FUNÇÃO PRINCIPAL - EXECUTAR TODOS OS EXEMPLOS
# =============================================================================

#' Executar todos os exemplos
executar_todos_exemplos <- function() {
  
  cat("🚀 INICIANDO ANÁLISES DE EXEMPLO\n")
  cat("=====================================\n")
  
  # Verificar se há dados processados
  data_dir <- "data/processed"
  if (!dir.exists(data_dir) || length(list.files(data_dir, recursive = TRUE)) == 0) {
    cat("❌ Nenhum dado processado encontrado!\n")
    cat("Execute primeiro o pipeline:\n")
    cat("  Rscript main_pipeline.R --test\n")
    return()
  }
  
  # Executar exemplos
  tryCatch(exemplo_analise_mortalidade(), error = function(e) cat("Erro na análise de mortalidade:", e$message, "\n"))
  tryCatch(exemplo_analise_nascimentos(), error = function(e) cat("Erro na análise de nascimentos:", e$message, "\n"))
  tryCatch(exemplo_analise_hospitalizacoes(), error = function(e) cat("Erro na análise de hospitalizações:", e$message, "\n"))
  tryCatch(exemplo_analise_comparativa(), error = function(e) cat("Erro na análise comparativa:", e$message, "\n"))
  tryCatch(exemplo_relatorio_qualidade(), error = function(e) cat("Erro no relatório de qualidade:", e$message, "\n"))
  
  cat("\n🎉 ANÁLISES CONCLUÍDAS!\n")
  cat("=====================================\n")
  cat("Use as funções individuais para análises específicas:\n")
  cat("- exemplo_analise_mortalidade()\n")
  cat("- exemplo_analise_nascimentos()\n")
  cat("- exemplo_analise_hospitalizacoes()\n")
  cat("- exemplo_analise_comparativa()\n")
  cat("- exemplo_relatorio_qualidade()\n")
}

# Executar automaticamente se script for chamado diretamente
if (!interactive()) {
  executar_todos_exemplos()
}