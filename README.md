# Hệ thống Phân tích và Dự đoán Thị trường Ô tô Cũ tại Việt Nam

> Đồ án môn học **Lập trình R cho Phân tích** — Nhóm 19, Khoa Công nghệ Thông tin, HCMUTE (Tháng 7/2026)

An end-to-end data pipeline for scraping, cleaning, analyzing, and predicting used car prices in Vietnam — powered by R and Shiny.

---

## Nhóm thực hiện

| STT | Họ và Tên | MSSV | Nhiệm vụ |
|---|---|---|---|
| 1 | Nguyễn Trung Khang | 24133028 | Phân tích xác suất thống kê, Trực quan hóa dữ liệu, Soạn thảo & Căn chỉnh báo cáo, Thiết kế Slide |
| 2 | Vũ Hoàng Long | 24133035 | Xây dựng giao diện Web UI (Shiny), Huấn luyện mô hình Hồi quy tuyến tính, Soạn thảo nội dung báo cáo |
| 3 | Hoàng Ngọc Huy | 24133023 | Cào dữ liệu (Web Scraping), Huấn luyện mô hình phân cụm K-Means, Soạn thảo báo cáo |
| 4 | Hồ Trọng Sơn | 24133049 | Phân tích xác suất thống kê, Huấn luyện mô hình Cây quyết định, Soạn thảo báo cáo |
| 5 | Huỳnh Trung Nghĩa | 24133903 | Cào dữ liệu (Web Scraping), Làm sạch & chuẩn hóa dữ liệu (ETL), Xây dựng giao diện Web UI |

**Giảng viên hướng dẫn:** ThS. Phan Thị Thể

---

## 📋 Mục lục

- [Tổng quan](#tổng-quan)
- [Tính năng](#tính-năng)
- [Cấu trúc dự án](#cấu-trúc-dự-án)
- [Tech Stack](#tech-stack)
- [Hướng dẫn cài đặt](#hướng-dẫn-cài-đặt)
  - [Yêu cầu](#yêu-cầu)
  - [Cài đặt](#cài-đặt)
  - [Chạy pipeline](#chạy-pipeline)
- [Nguồn dữ liệu](#nguồn-dữ-liệu)
- [Mô hình Machine Learning](#mô-hình-machine-learning)
- [Shiny Dashboard](#shiny-dashboard)
- [Schema dữ liệu](#schema-dữ-liệu)
- [Hạn chế](#hạn-chế)
- [Hướng phát triển](#hướng-phát-triển)
- [License](#license)

---

## Tổng quan

Dự án thu thập dữ liệu tin rao xe ô tô cũ từ các sàn giao dịch trực tuyến lớn tại Việt Nam, xử lý qua pipeline làm sạch đa tầng, và huấn luyện các mô hình học máy để phân tích xu hướng định giá và phân khúc thị trường.

Sản phẩm cuối là ứng dụng **R Shiny Dashboard — HCMUTE AutoInsight** — cho phép người dùng khám phá thị trường, so sánh xe, và ước tính giá hợp lý của một xe cũ dựa trên các thuộc tính đầu vào.

---

## Tính năng

- **Cào dữ liệu tự động** từ ba sàn ô tô cũ tại Việt Nam, hỗ trợ headless browser (`chromote`) cho trang render JavaScript
- **Pipeline làm sạch đa tầng** — xử lý missing values, bất thường số km, trùng lặp tin đăng, lọc ngoại lệ Z-score, và deduplication xuyên nguồn
- **SQLite master database** lưu trữ bền vững, deduplicated, tổng hợp từ tất cả nguồn
- **Thu thập dữ liệu gia tăng thời gian thực** — giải thuật Delta-Fetch chỉ thu thập tin mới kể từ lần chạy cuối, không quét lại toàn bộ
- **Xác suất và Thống kê** Tính toán các đại lượng thống kê mô tả, phân tích quy luật phân phối của giá xe và thực hiện kiểm định giả thuyết (T-test, ANOVA) để đánh giá các yếu tố ảnh hưởng.
- **Trực quan hóa dữ liệu** Sử dụng ggplot2 và plotly để xây dựng các biểu đồ tĩnh và biểu đồ tương tác, minh họa trực quan xu hướng mất giá, thị phần các hãng xe và mức độ tương quan giữa các biến số.
- **Dự đoán giá** bằng Linear Regression trên log(price) với feature engineering (nhóm thương hiệu, winsorization, log-price target) — R² = 0.763
- **Phân khúc thị trường** bằng K-Means Clustering (k=3, tối ưu bằng Elbow method + Silhouette ≈ 0.38)
- **Phân loại phân khúc giá** bằng Decision Tree (4 tầng: Phổ thông / Tầm trung / Khá / Cao cấp) — Accuracy = 70.63%, Kappa = 0.5428
- **Interactive Shiny Dashboard** với 8 tab: Tổng quan, Phân tích thị trường, Trực quan hóa, So sánh xe, Dự toán giá, Mô hình ML, Dữ liệu Master, Báo cáo


---

## Cấu trúc dự án

```
vn-used-car-analysis/
│
├── insights/
│   ├── descriptive_analytics/
│   │   ├── output_probability_statistics/   # File CSV đầu ra và báo cáo thống kê
│   │   ├── Cleaning_Data_For_statistics.R   # Chuẩn bị dữ liệu cho phân tích thống kê
│   │   ├── init_XSTK                        # Cấu hình khởi tạo module thống kê
│   │   └── Probability_statistics.R         # Xác suất & thống kê mô tả (Base R thuần)
│   │
│   └── visualization/
│       ├── plots/                           # File đầu ra ggplot2 / plotly (PNG)
│       ├── init_vis                         # Cấu hình khởi tạo module trực quan hóa
│       └── Visualization.R                  # Tạo biểu đồ (ggplot2 + plotly)
│
├── machine_learning/
│   ├── images/                              # Hình ảnh đầu ra của model (PNG)
│   ├── prepare_features.R                   # Feature engineering & lọc ngoại lệ (dùng chung)
│   ├── model1_regression.R                  # Linear Regression — dự đoán log(price)
│   ├── model2_clustering.R                  # K-Means Clustering (k=3) — phân khúc thị trường
│   ├── model3_decision_tree.R               # Decision Tree — phân loại tầng giá (4 tầng)
│   ├── output_models.RData                  # Đối tượng model đã huấn luyện & artifacts
│   └── run_all.R                            # Điều phối: chạy toàn bộ ML pipeline
│
├── web_scraping/
│   ├── data/
│   │   ├── clean/                           # File CSV đã làm sạch theo từng nguồn
│   │   ├── init_db/                         # File SQLite theo từng nguồn
│   │   ├── quality_report/                  # Báo cáo kiểm định chất lượng dữ liệu
│   │   ├── raw/                             # File CSV thô chưa xử lý
│   │   ├── realtime/                        # File đầu ra của scrape gia tăng
│   │   ├── master_data.csv                  # Dataset master tổng hợp (flat file)
│   │   └── master_data.db                   # SQLite master database
│   │
│   ├── rule/
│   │   ├── clean_rule.md                    # Tài liệu quy tắc làm sạch dữ liệu
│   │   ├── files_explain.md                 # Tài liệu cấu trúc file & thư mục
│   │   ├── process_rule.md                  # Quy tắc quy trình pipeline
│   │   ├── realtime_rule.md                 # Quy tắc scrape gia tăng / realtime
│   │   └── scrap_rule.md                    # Định nghĩa trường dữ liệu & schema 18 cột
│   │
│   ├── script/
│   │   ├── clean/
│   │   │   ├── clean_banxehoicu.R           # Làm sạch riêng cho banxehoicu.vn
│   │   │   ├── clean_bonbanh.R              # Làm sạch riêng cho bonbanh.com
│   │   │   └── clean_chotot.R               # Làm sạch riêng cho chotot.com
│   │   │
│   │   ├── realtime/
│   │   │   ├── realtime_banxehoicu.R        # Scraper gia tăng cho banxehoicu.vn
│   │   │   ├── realtime_bonbanh.R           # Scraper gia tăng cho bonbanh.com (delta-fetch)
│   │   │   └── realtime_chotot.R            # Scraper gia tăng cho chotot.com (delta-fetch)
│   │   │
│   │   ├── scrap/
│   │   │   ├── scrap_banxehoicu.R           # Scraper đầy đủ cho banxehoicu.vn (static HTML)
│   │   │   ├── scrap_bonbanh.R              # Scraper đầy đủ cho bonbanh.com (static HTML)
│   │   │   └── scrap_chotot.R               # Scraper đầy đủ cho chotot.com (headless browser)
│   │   │
│   │   ├── init_database.R                  # Khởi tạo schema SQLite theo từng nguồn
│   │   ├── merge_data.R                     # Gộp các DB nguồn vào master_data.db
│   │   ├── utils.R                          # Tiện ích làm sạch dùng chung (standardize_car_data, align_schema, ...)
│   │   └── validate_master_data.R           # Kiểm định tính toàn vẹn schema & dedup sau merge
│   │
│   ├── log.txt                              # Log chạy scraping
│   ├── run_pipeline.R                       # Pipeline batch đầy đủ: scrape → clean → validate → merge
│   └── run_realtime.R                       # Pipeline gia tăng realtime: scrape → clean → insert DB
│
├── app.R                                    # Shiny Dashboard — HCMUTE AutoInsight (UI + Server)
└── README.md
```

---

## Tech Stack

| Tầng | Công cụ |
|---|---|
| Ngôn ngữ | R (>= 4.1.0) |
| Cào dữ liệu (tĩnh) | `rvest`, `httr` |
| Cào dữ liệu (động) | `chromote` (headless Chrome) |
| Xử lý dữ liệu | `dplyr`, `tidyr`, `stringr`, `lubridate` |
| Cơ sở dữ liệu | SQLite qua `RSQLite`, `DBI` |
| Thống kê | Base R (`split`, `lapply`, `t.test`, `chisq.test`, `cor.test`) |
| Machine Learning | Base R `lm()`, `kmeans()`, `rpart` / `rpart.plot` |
| Trực quan hóa | `ggplot2`, `plotly` |
| Dashboard | `shiny`, `DT`, `scales`, `grid` |

---

## Hướng dẫn cài đặt

### Yêu cầu

- R (>= 4.1.0)
- RStudio (khuyến nghị)
- Google Chrome (bắt buộc cho scraping Chợ Tốt qua `chromote`)
- Các package R:

```r
install.packages(c(
  # Dashboard
  "shiny", "DT", "scales",
  # Xử lý dữ liệu
  "dplyr", "tidyr", "stringr", "lubridate",
  # Web scraping
  "rvest", "httr", "chromote",
  # Cơ sở dữ liệu
  "RSQLite", "DBI",
  # Trực quan hóa
  "ggplot2", "plotly",
  # Machine Learning
  "rpart", "rpart.plot", "cluster"
))
```

### Cài đặt

```bash
git clone https://github.com/solvarhuynh/vn-used-car-analysis.git
cd vn-used-car-analysis
```

### Chạy pipeline

**1. Scrape đầy đủ lần đầu:**
```r
source("web_scraping/run_pipeline.R")
```
Chạy toàn bộ scrape → clean → validate → merge qua cả ba nguồn, ghi ra `master_data.csv` và `master_data.db`.

**2. Cập nhật gia tăng (dùng hàng ngày):**
```r
source("web_scraping/run_realtime.R")
```
Dùng giải thuật delta-fetch / stop-on-first-duplicate để chỉ thu thập tin mới kể từ lần chạy cuối, sau đó insert vào `master_data.db` mà không cần quét lại toàn bộ.

**3. Huấn luyện các mô hình ML:**
```r
source("machine_learning/run_all.R")
```
Chạy `prepare_features.R` rồi huấn luyện cả ba mô hình. Lưu đối tượng model và artifacts đánh giá vào `output_models.RData`, hình ảnh vào `images/`.

**4. Làm sạch dữ liệu cho phân tích thống kê:**
```r
source("insights/descriptive_analytics/Cleaning_Data_For_statistics.R")
```
Tiền xử lý và chuẩn hóa dữ liệu từ `master_data.csv` để chuẩn bị cho module thống kê xác suất. Đầu ra được dùng làm đầu vào cho bước tiếp theo.

**5. Chạy phân tích xác suất & thống kê mô tả:**
```r
source("insights/descriptive_analytics/Probability_statistics.R")
```
Tính toán toàn bộ xác suất cơ bản, xác suất có điều kiện, kiểm định Bayes và kiểm định giả thuyết thống kê (Base R thuần). Kết quả được xuất ra `insights/descriptive_analytics/output_probability_statistics/` dưới dạng các file CSV.

**6. Tạo biểu đồ trực quan hóa:**
```r
source("insights/visualization/Visualization.R")
```
Sinh toàn bộ biểu đồ phân tích thị trường (ggplot2 + plotly): phân bố nhiên liệu, kiểu thân xe, top hãng, xu hướng giá theo năm sản xuất, ảnh hưởng của hộp số, ... Kết quả lưu vào `insights/visualization/plots/`.

**7. Huấn luyện các mô hình ML:**
```r
source("machine_learning/run_all.R")
```
Chạy `prepare_features.R` rồi huấn luyện cả ba mô hình. Lưu đối tượng model và artifacts đánh giá vào `output_models.RData`, hình ảnh vào `images/`.

**8. Khởi chạy Shiny Dashboard:**
```r
shiny::runApp("app.R")
```

> Dashboard cũng có thể kích hoạt cập nhật dữ liệu realtime ngay từ giao diện qua nút **"Cập nhật dữ liệu"** trên thanh header.

---

## Nguồn dữ liệu

Dữ liệu được thu thập từ ba sàn ô tô cũ trực tuyến tại Việt Nam:

| Nguồn | URL | Rendering | Phương pháp |
|---|---|---|---|
| Bonbanh | [bonbanh.com](https://bonbanh.com) | Static HTML | `rvest` / `httr` |
| Chợ Tốt | [xe.chotot.com](https://xe.chotot.com) | JavaScript (CSR + lazy-loading) | `chromote` (headless Chrome) |
| Bán Xe Hơi Cũ | [banxehoicu.vn](https://banxehoicu.vn) | Static HTML | `rvest` / `httr` |

**Logic deduplication:** Tin đăng được loại trùng đầu tiên theo URL (trong từng nguồn), sau đó theo fingerprint tổng hợp `brand + model + year + price + mileage` để bắt tin đăng lại xuyên nền tảng. Deduplication được đẩy xuống SQLite qua `INSERT OR IGNORE` trên khóa chính URL.

---

## Phân tích Thống kê & Trực quan hóa

### Phân tích Xác suất & Thống kê mô tả

Module `insights/descriptive_analytics/` thực hiện toàn bộ phân tích định lượng bằng **Base R thuần** (không dùng tidyverse), bao gồm:

- **Thống kê mô tả tổng quan:** Các chỉ số trung tâm (mean, median, mode) và phân tán (variance, std) cho giá bán, số km, tuổi xe
- **Xác suất cơ bản:** Phân phối nhóm thuộc tính (hộp số, nhiên liệu, nhóm tuổi xe)
- **Xác suất có điều kiện:** Phân tích sự dịch chuyển cấu hình hộp số theo nhóm tuổi xe; xác suất giá cao theo hộp số
- **Định lý Bayes:** Ứng dụng tính xác suất xe đời mới là số tự động dựa trên bằng chứng hành vi tìm kiếm
- **Kiểm định giả thuyết thống kê:** T-test, Chi-square test, Correlation test để xác nhận các insight định lượng

Kết quả xuất ra `insights/descriptive_analytics/output_probability_statistics/` dưới dạng các file CSV.

### Trực quan hóa Dữ liệu

Module `insights/visualization/Visualization.R` sinh các nhóm biểu đồ phân tích thị trường bằng `ggplot2` + `plotly`, được tổ chức theo 3 câu hỏi nghiên cứu:

| Nhóm | Câu hỏi | Biểu đồ tiêu biểu |
|---|---|---|
| **DISTRIBUTION** | Cơ cấu thị trường là gì? | Phân bố nhiên liệu, kiểu thân xe, mật độ địa lý |
| **WHAT** | Thương hiệu nào định vị ở phân khúc nào? | Top 50 hãng theo lượng tin & giá trung vị, Boxplot giá theo hãng |
| **WHEN** | Xe cũ mất giá theo thời gian thế nào? | Đường cong khấu hao theo năm sản xuất |
| **WHY** | Yếu tố nào quyết định giá bán? | Scatter plot: ảnh hưởng hộp số, nhiên liệu lên giá |

Hỗ trợ chuyển đổi biểu đồ tĩnh (PNG) sang biểu đồ động tương tác (plotly HTML). Đầu ra lưu vào `insights/visualization/plots/`.

---

## Mô hình Machine Learning

Cả ba mô hình được huấn luyện qua `machine_learning/run_all.R`, nguồn `prepare_features.R` trước để dùng chung feature engineering.

### Model 1 — Dự đoán Giá xe (Linear Regression)

- **File:** `machine_learning/model1_regression.R`
- **Biến mục tiêu:** `log_price_cap` — log(price) đã winsorize ở percentile 1%–99% để giảm ảnh hưởng của xe cao cấp
- **Phạm vi huấn luyện:** Xe có giá ≤ 5 tỷ VND (`is_train_sample = TRUE`)
- **Đặc trưng chính:** `car_age`, `mileage_k`, `engine_non_ev`, `fuel`, `is_auto`, `is_imported`, `seat_count`, `brand_grp` (top-20 hãng + "Other")
- **Hiệu suất:** R² = 0.763 · RMSE = 0.492 tỷ VND · MAE = 0.231 tỷ VND (test set, chia 80/20: 15.050 / 3.763 xe)
- **Hệ số đáng chú ý:** `car_age` −7.9%/năm · `is_auto` +35% · `is_imported` +9% · `fuelElectric` +74%

### Model 2 — Phân khúc Thị trường (K-Means Clustering)

- **File:** `machine_learning/model2_clustering.R`
- **Đặc trưng:** `price_billion` (winsorize 99th pctile), `car_age`, `mileage_k`, `engine_size` — tất cả chuẩn hóa Z-score
- **K tối ưu:** 3 (xác nhận bằng Elbow method — WSS giảm mạnh nhất tại k=3 — + Silhouette ≈ 0.38)
- **Các cụm được xác định:**
  - 🟢 **Xe phổ thông / dịch vụ** — Giá thấp, số km cao, xe cũ
  - 🟡 **Xe gia đình đô thị** — Tầm trung, số km thấp, động cơ nhỏ gọn
  - 🔴 **Xe cao cấp / đa dụng** — Cao cấp hoặc tiện ích số km cao, động cơ lớn

### Model 3 — Phân loại Phân khúc Giá (Decision Tree)

- **File:** `machine_learning/model3_decision_tree.R`
- **Nhiệm vụ:** Phân loại tin đăng vào 4 tầng giá: Phổ thông / Tầm trung / Khá / Cao cấp
- **Thuật toán:** `rpart` với cắt tỉa sau huấn luyện (CP chọn theo cross-validation error tối thiểu)
- **Đặc trưng chính:** `engine_size`, `car_age`, `seat_count`, `mileage_k`, `is_auto`, `is_imported`
- **Hiệu suất:** Accuracy = 70.63% · Kappa = 0.5428 (test set: 3.888 mẫu; gấp 2.83× so với baseline ngẫu nhiên)
- **Tầm quan trọng đặc trưng:** `engine_size` 49.3% · `car_age` 33.9% · `seat_count` 6.6% · `mileage_k` 5.0%
- **Nút phân nhánh gốc:** `engine_size < 2.9L` → tách 86% xe phổ thông khỏi 14% xe cao cấp

---

## Shiny Dashboard

Dashboard `app.R` (**HCMUTE AutoInsight**) gồm 8 tab:

| Tab | Mô tả |
|---|---|
| **Tổng quan** | KPI thị trường, xu hướng giá theo năm, cơ cấu nhiên liệu, top hãng |
| **Phân tích thị trường** | Bộ lọc tương tác: scatter, boxplot, biểu đồ donut với Plotly |
| **Trực quan hóa** | Biểu đồ tĩnh từ module `insights/visualization/` |
| **So sánh xe** | So sánh song song 3 xe kèm biểu đồ radar chấm điểm |
| **Dự toán giá** | Ước tính giá bằng Linear Regression + xác định cụm K-Means |
| **Mô hình ML** | R², RMSE, accuracy, feature importance, confusion matrix, cluster profiles, bộ sưu tập ảnh model |
| **Dữ liệu Master** | Bảng dữ liệu master có thể tìm kiếm và lọc |
| **Báo cáo** | Insight tự động, ghi chú phương pháp, xuất CSV, báo cáo PDF |

> **Lưu ý:** App chạy local. Khởi chạy bằng `shiny::runApp("app.R")` trong RStudio. Nút **"Cập nhật dữ liệu"** trên header sẽ kích hoạt `run_realtime.R` và tự động reload session.

---

## Schema dữ liệu

18 trường lưu trong `master_data.db` và `master_data.csv`, định nghĩa trong `web_scraping/rule/scrap_rule.md` và được thực thi bởi `align_schema()` trong `utils.R`:

| Cột | Kiểu | Mô tả |
|---|---|---|
| `brand` | String | Tên hãng xe (vd: Toyota, Honda, Ford) |
| `model` | String | Tên dòng xe (vd: Innova, Ranger, City) |
| `trim` | String | Phiên bản / trim (vd: 2.0E MT, 1.5G CVT) |
| `year` | Integer | Năm sản xuất |
| `body_type` | String | Kiểu thân xe: Sedan, SUV, Hatchback, Pickup, MPV, ... |
| `fuel_type` | String | Loại nhiên liệu: Xăng / Dầu / Điện / Hybrid |
| `transmission` | String | Hộp số: Số sàn / Tự động / CVT |
| `engine_size` | Float | Dung tích động cơ (lít); 0 cho xe điện |
| `seat_count` | Integer | Số chỗ ngồi |
| `drivetrain` | String | Hệ dẫn động: FWD / RWD / AWD / 4WD |
| `price` | Integer | Giá niêm yết (VND) |
| `mileage` | Integer | Số km đồng hồ |
| `origin` | String | Trong nước / Nhập khẩu |
| `color` | String | Màu ngoại thất |
| `city` | String | Tỉnh / thành phố đăng tin |
| `posted_date` | Date | Ngày đăng tin trên sàn |
| `source` | String | Nền tảng nguồn: `bonbanh` / `chotot` / `banxehoicu` |
| `url` | String | URL tin đăng — khóa định danh duy nhất và deduplication |

> Schema được thực thi bởi `align_schema(df)` trong `utils.R`, đệm cột thiếu bằng `NA` và sắp xếp tất cả cột về đúng cấu trúc 18 cột cố định trước khi ghi vào database.

---

## Hạn chế

- **Chất lượng dữ liệu tin đăng:** Tin đăng có thể chứa lỗi nhập liệu, tin ảo hoặc tin trùng từ nhiều môi giới. Giá và số km do người dùng nhập thủ công và có thể sai lệch.
- **Biến ẩn:** Các mô hình chưa tiếp cận được lịch sử tai nạn, thủy kích, mức độ hao mòn nội thất và lịch sử bảo dưỡng chính hãng — những yếu tố ảnh hưởng đáng kể đến giá trị thực.
- **Lệch địa lý:** Dữ liệu tập trung nhiều ở TP. Hồ Chí Minh và Hà Nội; dự đoán cho tỉnh thành nhỏ kém chính xác hơn.
- **Phạm vi Linear Regression:** Model 1 chỉ huấn luyện trên xe ≤ 5 tỷ VND. Xe cao cấp bị loại khỏi training do phương sai giá lớn và phi tuyến.
- **Z-score masking:** Với nhóm `brand + model` nhỏ (<5 mẫu), một ngoại lệ cực đoan có thể thổi phồng độ lệch chuẩn, khiến z-score của chính nó không vượt ngưỡng lọc.
- **Phụ thuộc Chromote:** Scraping Chợ Tốt yêu cầu Chrome được cài đặt. Scraper có thể cần bảo trì nếu trang cập nhật cấu trúc HTML hoặc cơ chế chống bot.

---

## Hướng phát triển

- [ ] Thay Linear Regression bằng Random Forest hoặc Gradient Boosting để tăng độ chính xác
- [ ] Thêm pipeline NLP để trích xuất đặc trưng từ mô tả tin đăng (vd: "chính chủ", "bảo dưỡng định kỳ")
- [ ] Deploy Shiny app lên shinyapps.io
- [ ] Tự động hóa scraping theo lịch (cron / GitHub Actions)
- [ ] Tích hợp API kiểm định xe để xác minh tình trạng
- [ ] Theo dõi xu hướng giá theo thời gian

---

## License

Dự án được phát triển cho mục đích học thuật trong khuôn khổ đồ án môn học tại **Trường Đại học Công nghệ Kỹ thuật TP. Hồ Chí Minh (HCMUTE)**, Khoa Công nghệ Thông tin, Học kỳ 2 năm học 2025–2026. Vui lòng tôn trọng điều khoản sử dụng của các trang web được scrape khi dùng hoặc mở rộng các script cào dữ liệu.
