# 필요한 라이브러리 설치 (GitHub Actions가 이 스크립트를 실행할 때 필요)
# install.packages(c("tidyverse", "readxl", "lubridate", "readr"))

library(tidyverse)
library(readxl) # 엑셀 파일을 읽기 위해 readxl을 사용합니다.
library(lubridate)
library(readr)

message("🚀 Starting CAPE data update process...")
message("→ Trying Yale University (Prof. Shiller's direct .xls file)…")

# --- 1. Shiller 교수의 원본 엑셀 파일 URL ---
shiller_url <- "http://www.econ.yale.edu/~shiller/data/ie_data.xls"
tmp_xls <- tempfile(fileext = ".xls")

tryCatch({
  # --- 2. 엑셀 파일 다운로드 ---
  # 'wb' (write binary) 모드는 엑셀 파일 다운로드 시 필수입니다.
  download.file(shiller_url, tmp_xls, mode = "wb", quiet = TRUE)
  message("✅ .xls file downloaded from Yale.")

  # --- 3. 데이터 읽기 및 처리 ---
  # Shiller 교수의 엑셀 파일은 7줄의 헤더(설명)가 있습니다. (skip=7)
  # "Data" 시트에 데이터가 있습니다.
  raw_data <- read_excel(tmp_xls, sheet = "Data", skip = 7)

  cape_data <- raw_data %>%
    # 필요한 컬럼만 선택 (Date, CAPE)
    select(Date, CAPE) %>%
    # NA 값 제거 (파일 뒷부분의 빈 행)
    filter(!is.na(CAPE), !is.na(Date)) %>%
    # 날짜 형식 변환
    # Shiller 교수의 날짜는 2024.01 (2024년 1월), 2024.1 (2024년 10월) 같은 숫자입니다.
    mutate(
      Year = floor(Date),
      Month = round((Date - Year) * 100),
      # YYYY-MM-DD 형식으로 날짜 생성 (매월 1일 기준)
      Date = as.Date(paste(Year, Month, "01", sep = "-"), "%Y-%m-%d")
    ) %>%
    select(Date, CAPE) %>%
    arrange(Date)
    
  message(paste("✅ Successfully parsed", nrow(cape_data), "rows of data."))

  # --- 4. CSV 파일로 저장 ---
  file_path <- "shiller_cape.csv" 
  readr::write_csv(cape_data, file_path)
  
  message(paste("✅ Data saved to", file_path))

}, error = function(e) {
  warning(paste("⚠️ Yale .xls download/parse failed:", e$message), immediate. = TRUE)
  stop("❌ Failed to update CAPE data from Yale source.")
})
