# update_finra.R
library(tidyverse)
library(Quandl)
library(readr)

message("🚀 Starting FINRA Margin Debt update process...")
message("→ Trying Quandl API (from GitHub Action)...")

# GitHub Secrets에서 API 키 가져오기
quandl_key <- Sys.getenv("QUANDL_API_KEY")

if (nchar(quandl_key) == 0) {
  stop("❌ QUANDL_API_KEY not found in GitHub Secrets.")
} else {
  Quandl.api_key(quandl_key)
  message("✅ Quandl API key loaded from secrets.")
}

tryCatch({
  # 1. Quandl API 호출
  finra_data <- Quandl("NASDAQ/FINRA_MART", type = "raw") %>%
    select(Date, `Debit Balances`) %>%
    rename(Date = Date, Margin_Debt = `Debit Balances`) %>%
    mutate(Date = as.Date(Date)) %>%
    filter(!is.na(Margin_Debt)) %>%
    arrange(Date)
  
  if (nrow(finra_data) < 100) stop("Quandl data is empty or invalid.")
  
  # 2. CSV 파일로 저장
  file_path <- "finra_margin.csv" 
  readr::write_csv(finra_data, file_path)
  
  message(paste("✅ Successfully parsed and saved", nrow(finra_data), "rows to", file_path))
  
}, error = function(e) {
  warning(paste("⚠️ Quandl API failed:", e$message), immediate. = TRUE)
  stop("❌ Failed to update FINRA data from Quandl.")
})
