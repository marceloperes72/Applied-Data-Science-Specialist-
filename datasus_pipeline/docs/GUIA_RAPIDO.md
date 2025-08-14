# 🚀 Guia Rápido - Pipeline DATASUS

## Start em 5 Minutos

### 1. Instalar Dependências (2 min)
```r
# No R ou RStudio
source("install_dependencies.R")
```

### 2. Teste Rápido (3 min)
```bash
# No terminal
Rscript main_pipeline.R --test
```

Isso vai:
- Baixar dados de SP para 2023
- Processar todos os sistemas ativos
- Gerar relatórios

### 3. Ver Resultados
```r
# Dados processados em: data/processed/
# Relatórios em: data/final/quality_summary.csv
```

## Casos de Uso Comuns

### 📊 Mortalidade (SIM) - 2020-2023
```bash
Rscript main_pipeline.R --sistemas SIM
```

### 👶 Nascimentos (SINASC) - SP e RJ
```yaml
# Editar config/pipeline_config.yml
sistemas:
  SINASC:
    ativo: true
    uf: ["SP", "RJ"]
```

### 🏥 Dados Hospitalares - Apenas 2023
```yaml
# Editar config/pipeline_config.yml
periodo:
  inicio: 2023
  fim: 2023
  
sistemas:
  SIH:
    ativo: true
```

## Comandos Essenciais

| Comando | Uso |
|---------|-----|
| `--test` | Teste rápido (SP, 2023) |
| `--sistemas SIM,SINASC` | Apenas mortalidade e nascimentos |
| `--force` | Re-baixar tudo (ignorar cache) |
| `--help` | Ver todas as opções |

## Acesso aos Dados

### Carregar dados processados
```r
library(arrow)

# Mortalidade SP 2023
sim_sp <- read_parquet("data/processed/SIM/SIM_2023_SP_processed.parquet")

# Ver estrutura
names(sim_sp)
summary(sim_sp)

# Análise simples
table(sim_sp$sexo)
hist(sim_sp$idade)
```

### Campos principais após processamento

**SIM (Mortalidade):**
- `data_obito`, `idade`, `sexo`
- `causa_basica_cid`, `codigo_municipio`
- `ano_obito`, `idade_calculada`

**SINASC (Nascimentos):**
- `data_nascimento`, `sexo`, `peso`
- `idade_mae`, `codigo_municipio`
- `classificacao_peso`

**SIH (Hospitalizações):**
- `data_internacao`, `data_saida`
- `tempo_permanencia`, `valor_total`
- `diagnostico_principal`

## Troubleshooting Rápido

### ❌ Erro: Pacote não encontrado
```r
# Instalar manualmente
install.packages("nome_do_pacote")
```

### ❌ Erro: Dados não encontrados
- Verifique se UF/ano existe no DATASUS
- Use `--test` primeiro

### ❌ Erro: Falta de memória
- Use modo teste: `--test`
- Processe poucos estados: edite config

### ❌ Erro: Conexão
- Verifique internet
- Tente novamente: `--force`

## Performance

### ⚡ Acelerar processamento
```yaml
# config/pipeline_config.yml
processamento:
  paralelismo: true
  num_cores: 8

cache:
  ativo: true
```

### 💾 Economizar espaço
```yaml
armazenamento:
  formato_saida: "csv"
  compressao: true
  backup: false
```

## Próximos Passos

1. **Leia o README.md completo** - Documentação detalhada
2. **Personalize a configuração** - Edite `config/pipeline_config.yml`
3. **Explore os dados** - Use os scripts de exemplo
4. **Documente sua análise** - Mantenha registros dos processamentos

---

**Dúvidas?** Consulte o README.md ou abra uma issue! 📝