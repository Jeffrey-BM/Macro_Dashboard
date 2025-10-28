# 필요한 라이브러리 설치 (GitHub Actions가 이 스크립트를 실행할 때 필요)
# install.packages(c("tidyverse", "Quandl", "rvest", "httr", "readr"))

library(tidyverse)
library(lubridate)
library(httr)
library(rvest)
library(Quandl)

message("🚀 Starting CAPE data update process...")

# --- 1. GitHub Secrets에서 API 키 가져오기 ---
# (이 스크립트는 GitHub Actions 환경에서 실행될 것이므로, Sys.getenv()를 사용)
quandl_key <- Sys.getenv("QUANDL_API_KEY")

if (nchar(quandl_key) == 0) {
  warning("⚠️ QUANDL_API_KEY not found in environment variables.", immediate. = TRUE)
  # 로컬 테스트용 임시 키 (GitHub에 커밋하지 마세요!)
  # if (!interactive()) stop("API Key not found.")
  # Quandl.api_key("YOUR_LOCAL_KEY") # 로컬 테스트 시 이 줄의 주석을 해제
} else {
  Quandl.api_key(quandl_key)
  message("✅ Quandl API key loaded from secrets.")
}

# SSL 검증 비활성화 (rvest/httr용)
httr::set_config(httr::config(ssl_verifypeer = 0))

# --- 2. 데이터 가져오기 (API 우선) ---
cape_data <- NULL

tryCatch({
  # 시도 1: Quandl (가장 안정적)
  message("→ Trying Nasdaq Data Link (Quandl)…")
  cape_data <- Quandl("MULTPL/SHILLER_PE_RATIO_MONTH", type = "raw") %>%
    rename(Date = Date, CAPE = Value) %>%
    mutate(Date = as.Date(Date)) %>%
    filter(!is.na(CAPE)) %>%
    arrange(Date)
  message("✅ Loaded from Nasdaq Data Link (Quandl).")
  
}, error = function(e_quandl) {
  warning(paste("⚠️ Quandl failed:", e_quandl$message, "→ MULTPL fallback."), immediate. = TRUE)
  
  tryCatch({
    # 시도 2: MULTPL.com (웹 스크래핑)
    message("→ Trying MULTPL.com (HTML parse with User-Agent)…")
    ua <- httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
    page <- rvest::session("https://www.multpl.com/shiller-pe/table/by-month", ua) %>% 
      rvest::read_html()
    
    tbl <- page %>% html_element("table") %>% html_table()
    cape_data <- tbl %>%
      rename(Date = 1, CAPE = 2) %>%
      mutate(
        Date = as.Date(paste0(Date, "-01")),
        CAPE = as.numeric(str_replace(CAPE, ",", ""))
      ) %>%
      filter(!is.na(CAPE)) %>%
      arrange(Date)
    message("✅ Loaded from MULTPL.com (HTML parse).")
    
  }, error = function(e_multpl) {
    warning(paste("⚠️ MULTPL failed:", e_multpl$message), immediate. = TRUE)
    stop("❌ All CAPE data sources failed. Cannot update file.")
  })
})

# --- 3. CSV 파일로 저장 ---
if (!is.null(cape_data) && nrow(cape_data) > 0) {
  # (중요) 이 파일 이름은 data_fetch.R이 다운로드하려는 파일명과 일치해야 합니다.
  file_path <- "shiller_cape.csv" 
  readr::write_csv(cape_data, file_path)
  message(paste("✅ Successfully fetched", nrow(cape_data), "rows."))
  message(paste("✅ Data saved to", file_path))
} else {
  stop("❌ Fetched data is null or empty. File not updated.")
}
