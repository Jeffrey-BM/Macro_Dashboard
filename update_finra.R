# update_finra.R
library(tidyverse)
library(rvest)
library(httr)
library(readxl)
library(readr)

message("🚀 Starting FINRA Margin Debt update process...")
message("→ Trying FINRA scrape page (from GitHub Action)...")

tryCatch({
  # 1. 스크래핑할 페이지 주소
  finra_page_url <- "https://www.finra.org/investors/learn-to-invest/advanced-investing/margin-statistics"
  ua <- httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
  
  finra_page <- rvest::session(finra_page_url, ua) %>% 
    rvest::read_html()
  
  # 2. 'margin-stats-....xlsx' 패턴의 링크 찾기
  finra_link <- finra_page %>%
    html_elements("a") %>%
    html_attr("href") %>%
    str_subset("margin-stats-.*\\.xlsx$") %>% 
    .[1]
  
  if (is.na(finra_link)) {
    stop("FINRA scrape failed: 'margin-stats-....xlsx' 링크를 페이지에서 찾을 수 없습니다.")
  }
  
  # 3. 절대 경로로 변환
  if (!startsWith(finra_link, "http")) {
    finra_url <- paste0("https://www.finra.org", finra_link)
  } else {
    finra_url <- finra_link
  }
  
  message(paste("... Found link:", finra_url))
  
  # 4. 엑셀 파일 다운로드 및 파싱
  tmp <- tempfile(fileext = ".xlsx")
  download.file(finra_url, tmp, mode = "wb", quiet = TRUE)
  
  finra_data <- read_excel(tmp, skip = 1) %>%
    rename(Date = 1, Margin_Debt = 2) %>%
    mutate(Date = as.Date(Date)) %>%
    select(Date, Margin_Debt) %>%
    filter(!is.na(Date), !is.na(Margin_Debt)) %>%
    arrange(Date)
  
  # 5. CSV 파일로 저장 (data_fetch.R이 이 파일을 읽음)
  file_path <- "finra_margin.csv" 
  readr::write_csv(finra_data, file_path)
  
  message(paste("✅ Successfully parsed and saved", nrow(finra_data), "rows to", file_path))
  
}, error = function(e) {
  warning(paste("⚠️ FINRA scrape failed:", e$message), immediate. = TRUE)
  stop("❌ Failed to update FINRA data.")
})
