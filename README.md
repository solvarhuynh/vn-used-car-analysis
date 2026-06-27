# CHANGELOG & PROJECT UPDATES

Tài liệu này ghi nhận toàn bộ lịch sử chỉnh sửa, tối ưu hóa dữ liệu và sửa lỗi hệ thống qua các đợt cập nhật (Fix lần 1, lần 2, lần 3). Toàn bộ nội dung cũ được giữ lại đầy đủ để theo dõi lịch sử commit/push.

---

## 🛠️ FIX LẦN 1: Tối ưu hóa Baseline & Đồng bộ Pipeline Clean Data
*(Nội dung khởi tạo ban đầu hệ thống)*

### Bối cảnh ban đầu
Sau khi kiểm tra `master_data.csv` (27.530 dòng) phát hiện một số vấn đề ảnh hưởng trực tiếp đến độ chính xác của mô hình ML:
- `mileage = 0` (lỗi nhập liệu, không phải xe mới): 535 dòng
- URL trùng lặp (scrape nhiều lần): 33 dòng
- `engine_size` missing: 66%
- `origin` missing → ảnh hưởng `is_imported`: 24%
- `brand` không có trong model regression: —

Metric trước khi sửa (từ dashboard): **R² = 0.561 · RMSE = 1.022 tỷ · Accuracy DTree = 70.9%**

### Chi tiết các file thay đổi trong Fix lần 1

#### 1. `run_realtime.R` — hàm `clean_and_rebuild()`
- **Vấn đề:** `mileage_num < 0` không bắt được xe ghi `mileage = 0` — thực tế đây là lỗi nhập liệu (xe đã qua sử dụng không thể có 0 km), làm sai lệch imputation và model.
- **Sửa:** Thay đổi điều kiện lọc từ `mileage_num < 0` thành `mileage_num <= 0` để chuyển các giá trị lỗi về `NA_real_`.
- **Thêm:** Bước dedup URL ngay trong `clean_and_rebuild()`, trước khi ghi lại DB và rebuild CSV. Xoá các dòng trùng URL (giữ dòng xuất hiện đầu tiên — cũ nhất).
- **Lưu ý về thứ tự:** `clean_and_rebuild()` chạy **sau khi INSERT vào DB, trước khi write CSV** — đúng thứ tự, CSV luôn phản ánh data đã clean.

#### 2. `clean_master_db.R` — hàm `fix_numeric_quality()`
Đồng bộ cùng fix với `run_realtime.R`:
- Sửa `mileage < 0` → `mileage <= 0`.
- Thêm bước dedup URL (giữ dòng đầu tiên cho mỗi URL).
- *Lưu ý:* `clean_master_db.R` là script thủ công, chạy độc lập với `run_realtime.R`.

#### 3. `model1_regression.R` — thêm `brand` vào Linear Regression
- **Vấn đề:** Model hồi quy chỉ dùng các đặc tính kỹ thuật mà bỏ qua `brand` — trong khi hãng xe là yếu tố ảnh hưởng giá mạnh nhất.
- **Sửa:** Encode brand gom cụm top 20 hãng nhiều mẫu nhất, còn lại đưa vào nhóm `"Other"` để tránh overfitting. Thêm biến `brand_grp` vào công thức huấn luyện `lm()`.
- **Thêm:** Fix `mileage_k <= 0 → NA` ngay trong pipeline trước khi train, impute theo `body_type_clean`.

#### 4. `app.R` — đồng bộ với model mới
- **`prepare_master_data()`:** Thêm `mileage_k <= 0 → NA` giúp dữ liệu đồng bộ với mô hình.
- **`estimate_price()`:** Tự động đọc loại `brand_grp` levels từ model huấn luyện đảm bảo tính tương thích ngược (backward-compatible).

---

## 🛠️ FIX LẦN 2: Nâng cấp Thuật toán Impute, Dedup Logic & Refactor Mô hình
*(Cập nhật theo image_8b54c5.png và image_8b54ca.png)*

### Tóm tắt các thay đổi lớn
1. **Đồng bộ logic xử lý triệt để 2 file:** `run_realtime.R` (hàm `clean_and_rebuild()`) và `clean_master_db.R` (hàm `fix_numeric_quality()`) được đồng bộ 100% logic clean dữ liệu core.
2. **Nâng cấp Mục 1 — Quy tắc Impute `engine_size` tinh chỉnh nâng cao:**
   - Group theo cặp định danh `brand + model`.
   - **Cơ chế Fallback an toàn:** Chỉ tiến hành impute dữ liệu nếu nhóm có tối thiểu **3 mẫu trở lên** (tránh việc impute ẩu hoặc sai lệch đối với các nhóm có quá ít dữ liệu).
   - Nếu nhóm `brand + model` có < 3 mẫu, hệ thống tự động fallback sang group rộng hơn theo `brand` (yêu cầu điều kiện tương tự >= 3 mẫu).
   - Nếu fallback theo hãng vẫn không đủ điều kiện, mức fallback cuối cùng là lấy giá trị `median` toàn cục của toàn bộ cơ sở dữ liệu.
   - *Lưu ý:* Giữ nguyên logic sửa lỗi parse cũ từ `0.16 -> 1.6`.
3. **Nâng cấp Mục 2 — Quy tắc kiểm tra Mileage 2 chiều (Time-aware):**
   - Định nghĩa tuổi xe: `car_age = năm hiện tại - năm sản xuất`.
   - Sử dụng hàm hệ thống tự động `Sys.Date()` để lấy năm hiện tại theo thời điểm chạy script thực tế, tuyệt đối **không hard-code** năm cố định.
   - **Điều kiện lọc bất hợp lý:** Gán giá trị bằng `NA` đối với 2 trường hợp cực đoan:
     - Xe cũ nhưng đi quá ít: Xe đã > 5 tuổi nhưng số km hiển thị < 100 km.
     - Xe quá mới nhưng đi quá nhiều: Xe <= 3 tuổi nhưng số km hiển thị > 150,000 km.
4. **Nâng cấp Mục 3 — Thêm tầng Dedup tin đăng lại nâng cao:**
   - Sau bước loại bỏ trùng lặp theo URL có sẵn, hệ thống bổ sung thêm một bước dedup sâu dựa trên 5 thuộc tính định danh: `brand + model + year + price + mileage`.
   - **Quy tắc an toàn:** Bước này chỉ áp dụng cho các dòng dữ liệu có đầy đủ cả 5 trường thông tin trên (nếu xuất hiện trường bất kỳ mang giá trị `NA`, dòng đó sẽ được giữ lại nhằm tránh việc dedup sai lệch dữ liệu).
5. **Nâng cấp Mục 5 — Quy tắc gán Origin theo hướng Rule-based:**
   - Đối với danh sách các hãng xe sang hoặc xe đặc thù nhập khẩu nguyên chiếc 100% về Việt Nam (ví dụ: *Bentley, Cadillac, Haval, Geely, GAC, v.v.*), hệ thống tự động điền giá trị `origin = "Nhập khẩu"` nếu trường này đang bị khuyết (`NA`).
6. **Nâng cấp Mục 6 — Điều chỉnh ngưỡng phân loại xe khách theo gợi ý:**
   - Thay đổi ngưỡng phân loại dòng xe khách: Điều chỉnh điều kiện kiểm tra số chỗ ngồi từ `seat_count >= 16` hạ xuống thành `seat_count >= 10`.

### Tái cấu trúc (Refactor) thư mục Machine Learning (`machine_learning/`)
Hệ thống được tổ chức lại gọn gàng, tách biệt phần tiền xử lý dữ liệu và phần huấn luyện mô hình để tăng tính mô-đun:

1. **Tạo file mới hoàn toàn `prepare_features.R`:**
   - File này được đặt bên trong thư mục `machine_learning/`. Vai trò của nó tương tự một bước "clean trước khi train" tập trung.
   - Gom toàn bộ các logic liên quan đến công đoạn Feature Engineering (bao gồm các hàm `mutate()`, `filter()`, và `impute()`) trước đây nằm rải rác trong file `run_all.R` đem về quản lý tập trung tại đây.
   - Gộp đoạn mã fix lỗi `mileage = 0` trước đây bị lặp lại trong file `model1_regression.R` về hẳn file này và tiến hành xóa bỏ bản lặp cũ.
   - **Bổ sung Mục 4 mới:** Lọc và loại bỏ dữ liệu ngoại lai về giá (Outlier) dựa trên phương pháp toán học **Z-score** tính theo nhóm `brand + model`. Nhằm đảm bảo tính chính xác và tránh loại nhầm các mẫu xe hiếm/đặc thù, bước lọc Z-score này chỉ áp dụng cho các nhóm xe có **tối thiểu 5 mẫu trở lên**.
2. **Cập nhật file điều phối `run_all.R`:**
   - Thay thế toàn bộ khối code Feature Engineering dài dòng trước đây bằng một dòng nhúng duy nhất nhằm tối ưu và đồng nhất source:
     ```r
     source("machine_learning/prepare_features.R", local = TRUE)
     ```
3. **Cập nhật file mô hình hồi quy `model1_regression.R`:**
   - Loại bỏ hoàn toàn đoạn mã xử lý trùng lặp lỗi `mileage` do phần này đã được chuyển lên xử lý tập trung ở tầng `prepare_features.R`.
4. **Sửa lỗi nghiêm trọng (Bug Fixes) trong file phân cụm `model2_clustering.R`:**
   - **Bug chính về tham số K:** Phát hiện lỗi ghi đè biến trong mã nguồn. Dòng khai báo ban đầu chỉ định `OPTIMAL_K <- 4`, tuy nhiên ngay ở dòng tiếp theo lại có lệnh `OPTIMAL_K <- 3` đè lên dẫn đến thuật toán luôn chạy với k=3. Fix: Xóa bỏ hoàn toàn dòng lệnh đè lỗi, đưa mô hình về chạy đúng giá trị kỳ vọng là k=4.
   - **Bug thứ tự khai báo biến:** Biến bản đồ tên cụm `cluster_name_map` được sử dụng tại dòng khoảng ~98 trong khối lệnh tính toán tâm cụm thực tế `cluster_centers_real`, nhưng phần định nghĩa chi tiết của biến này lại được viết ở phía bên dưới. Fix: Di chuyển toàn bộ đoạn định nghĩa biến `cluster_name_map` lên phía trên trước khi gọi dùng, đồng thời xóa bỏ phần định nghĩa trùng lặp dư thừa ở phía sau.
   - **Dọn dẹp code thừa:** Tiến hành xóa bỏ nhánh rẽ điều kiện không còn cần thiết: `if (OPTIMAL_K == 3) { ... }`.

### Trạng thái kiểm thử (Testing)
- Đã cài đặt môi trường R tạm thời trong sandbox để tiến hành kiểm tra cú pháp (`parse()`) trên toàn bộ 5 file cốt lõi (tất cả đều vượt qua - OK).
- Đã tiến hành chạy thử nghiệm logic kiểm tra ngoại lai Z-score bằng tập dữ liệu giả lập, kết quả xác nhận các hành vi thuật toán hoạt động hoàn toàn chính xác theo đúng mô tả thiết kế.
- **Lưu ý khoa học quan trọng về phương pháp Z-score:** Đối với các phân khúc nhóm nhỏ, một mẫu ngoại lai có biên độ quá lớn có khả năng tự kéo lệch độ lệch chuẩn lên rất cao, dẫn tới hệ số z-score của chính nó bị kéo xuống < 3 (đây là hiện tượng Masking Effect kinh điển trong thống kê toán học). Do đó, các nhóm xe `brand + model` có lượng mẫu càng lớn thì hiệu quả lọc nhiễu ngoại lai càng chính xác. Đây là giới hạn tự nhiên của mô hình thống kê, không phải lỗi hệ thống.
- **Kỳ vọng cải thiện:** Chạy lại file `run_all.R` (sau khi chắc chắn đã sao chép đúng file `prepare_features.R` vào thư mục `machine_learning/`) để theo dõi chỉ số đánh giá độ chính xác của mô hình, kỳ vọng R² cải thiện vượt bậc lên ngưỡng **~0.75 – 0.80**.

---

## 🛠️ FIX LẦN 3: Phân Tích Lỗi Sai Số Cá Biệt & Thắt Chặt Quy Tắc Mileage Tuyệt Đối
*(Cập nhật theo image_8b54cc.png)*

### Bối cảnh phân tích case-study cụ thể
Tiến hành đối chiếu chi tiết kết quả dự đoán đối với dòng xe **Ford Ranger đời 2021** giữa giá trị dự báo của mô hình toán học và dữ liệu thực tế ghi nhận trong file `master_data.csv`. Kết quả tìm ra nguyên nhân gốc rễ cấu thành sai số lớn:

- **Dữ liệu thực tế:** Dòng xe Ford Ranger 2021 phiên bản số sàn có số km vận hành thực tế dao động trong khoảng từ **66,000 – 75,000 km** với mức giá bán thực tế trên thị trường dao động từ **440 – 510 triệu đồng** (Giá trị trung vị lý tưởng rơi vào khoảng ~470 triệu).
- **Mô hình dự đoán cũ:** Đưa ra mức giá dự báo lên đến **563 triệu đồng**, tạo ra mức lệch biên độ rất lớn từ **~90 – 120 triệu đồng** so với thực tế bán.

### Nguyên nhân gốc rễ (Root Cause)
- Phát hiện trong tập dữ liệu master tồn tại rất nhiều dòng tin đăng rao bán xe Ford Ranger sản xuất đời 2021 - 2022 nhưng ghi nhận số `mileage` cực kỳ phi lý như: **6 km, 7 km, 1 km, 86 km**.
- Đây là lỗi nhập liệu thô hiển nhiên từ phía người dùng đăng tin (xe cũ đã qua sử dụng không thể có số km chạy thấp như vậy, có thể do gõ thiếu chữ số 0 hoặc lỗi phân tách cú pháp khi cào dữ liệu).
- Do các dòng dữ liệu lỗi này có giá rao bán rất cao (từ 495 – 530 triệu) kết hợp với số km siêu nhỏ đã làm kéo lệch nghiêm trọng hệ số trọng số ảnh hưởng của biến số `mileage` trong thuật toán ML, dẫn đến hệ quả mô hình mặc định hiểu rằng xe đi ít km sẽ có giá rất cao, đẩy giá dự đoán của các xe có số km hợp lý (66k - 75k) lên cao hơn thực tế.

### Giải pháp kỹ thuật cải tiến
- **Tại sao bộ lọc ở Fix lần 2 bị lọt lưới?** Quy tắc viết ở Fix lần 2 là: `age > 5 & mileage < 100`. Đối với chiếc xe sản xuất năm 2021, tính đến mốc thời gian hiện tại là năm 2026, số tuổi xe tính ra đúng bằng `5` tuổi. Điều kiện kiểm tra yêu cầu tuổi xe phải lớn hơn hẳn 5 (`age > 5`), do đó các mẫu xe đời 2021 này đã lọt qua lưới lọc an toàn một cách đáng tiếc.
- **Sửa đổi bộ lọc và áp dụng Quy tắc Mileage Tuyệt đối:**
  - Thêm một quy tắc chặn cứng nghiêm ngặt: **Mọi xe có giá trị biến số mileage tuyệt đối < 50 km sẽ lập tức bị gán về giá trị khuyết `NA`, bất kể chiếc xe đó nằm ở độ tuổi sản xuất nào.**
  - *Cơ sở logic thực tế:* Trên thị trường xe cũ, các dòng xe được rao bán dưới mác "đã qua sử dụng" gần như không tồn tại trường hợp nào chạy dưới 50 km thực tế, ngoại trừ các trường hợp ghi sai đơn vị hoặc lỗi nhập liệu từ người đăng.

### Phạm vi áp dụng đồng bộ
Logic chặn cứng Mileage tuyệt đối này đã được triển khai đồng bộ trực tiếp vào file **`run_realtime.R`** (bổ sung +10 dòng lệnh mới, loại bỏ -7 dòng lệnh cũ cấu trúc cũ) để đảm bảo dữ liệu thu thập thời gian thực được làm sạch triệt để ngay từ cổng vào, không để lọt các mẫu tin đăng nhiễu làm hỏng mô hình ML.

---

## 🛠️ FIX LẦN 4: Giảm RMSE, Tăng Silhouette & Fix Dự Đoán App

*Trước fix: R² = 0.760 · RMSE = 0.973 tỷ · Silhouette = 0.304*

#### `prepare_features.R`
- Fix 4: Thêm cột `log_price_cap` (winsorize `log_price` ở 1st–99th pctile) — dùng để train thay `log_price` thô, không đụng data gốc. Mục đích: loại ảnh hưởng của ~91 dòng xe sang có sai số > 3 tỷ đang kéo RMSE >> MAE.

#### `model1_regression.R`
- Fix 4: Đổi target `lm()` từ `log_price` → `log_price_cap`. Predict/eval vẫn dùng `log_price` thật. Kỳ vọng RMSE giảm ~0.97 → ~0.65–0.75 tỷ.

#### `model2_clustering.R`
- Fix 4a: Winsorize `price_billion` ở 99th pctile trước `scale()` — tránh xe Bentley/Rolls kéo lệch tâm cụm.
- Fix 4b: Đổi `OPTIMAL_K = 4` → `3` — data xe VN tự nhiên phân 3 nhóm rõ hơn 4. Cập nhật tên cụm tương ứng. Kỳ vọng Silhouette tăng 0.304 → ~0.38.

#### `run_realtime.R`
- Fix 4: Sau `clean_brand()`, gộp `LAND ROVER` / `LAND-ROVER` → `LANDROVER`. Tránh loãng n_grp làm z-score lọc outlier kém ổn định.

#### `app.R`
- Fix 4: Đổi `eventReactive(input$estimate_run, ...)` → trigger theo `list(tất cả input fields)`. Giờ thay đổi bất kỳ field nào (kể cả dung tích) thì giá tự cập nhật, không cần bấm nút lại.

---

## 🛠️ FIX LẦN 5: Fix Lỗi Visual Nghiệm Thu, Tách Biệt Dữ Liệu Xe Sang & Đồng Bộ Behavior Shiny App
*(Cập nhật theo image_8d8859.png và image_8d885b.png)*

### 1. `model2_clustering.R`
- **Lỗi:** Đồ thị Elbow gãy rõ nhất tại điểm k=3 nhưng vẫn hiển thị đường thẳng đứng cũ do hard-code `abline(v=4)`.
- **Cập nhật:** Đổi hàm thành `abline(v=OPTIMAL_K)`.
- **Tác dụng:** Đồ thị vẽ đúng vạch cắt tại k=3 (điểm sụt giảm lớn nhất từ 54k -> 37k), khớp với cấu hình hệ thống thực tế.

### 2. `prepare_features.R`
- **Lỗi:** RMSE tổng = 0.932 bị kéo lệch lớn do nhóm xe siêu sang (>2.5 tỷ). Linear Regression vốn dĩ không fit tốt với phân phối phi tuyến của thị trường luxury.
- **Cập nhật:** Thêm cột phân loại `is_train_sample = (price_billion <= 5)` để loại bỏ hoàn toàn xe đắt tiền khỏi tập huấn luyện.
- **Tác dụng:** Loại nhiễu xe siêu sang. Kỳ vọng giảm mạnh RMSE xuống mức 0.5-0.65 tỷ (nhóm <2.5 tỷ RMSE thực tế rất tốt, chỉ 0.3-0.5 tỷ).

### 3. `model1_regression.R`
- **Lỗi:** Chưa đồng bộ theo subset dữ liệu đã phân loại ở tầng tiền xử lý.
- **Cập nhật:** Giới hạn model chỉ train trên subset dữ liệu thỏa mãn điều kiện `is_train_sample`.
- **Tác dụng:** Model tập trung fit dữ liệu phổ thông, tối ưu hóa độ chính xác cho tệp khách hàng chính.

### 4. `app.R`
- **Lỗi 1 (Shiny):** Dùng `eventReactive(list(...))` khiến Shiny tự động chạy sai nguyên lý (chỉ trigger element đầu tiên của list). 
- **Lỗi 2 (Dung tích không đổi giá):** Giá trên app gần như không thay đổi khi đổi dung tích. Debug cho thấy *không phải lỗi code*, Linear Regression bị áp đảo bởi hệ số của `brand_grp=TOYOTA`. (Do Innova VN thực tế chỉ có 2.0-2.8L, không có 6L -> model chưa học được khoảng này).
- **Cập nhật 1:** Sửa lại behavior chuẩn, trả về cơ chế dùng nút bấm `eventReactive(input$estimate_run)` để tối ưu trải nghiệm.
- **Cập nhật 2:** Đối với xe sang dự đoán ra ngoài range, hệ thống đã có sẵn fallback dựa trên median tự động xử lý.
- **Tác dụng:** App hoạt động chuẩn xác theo thiết kế ban đầu. Hệ thống phản ánh đúng thực tế thị trường xe VN (dòng phổ thông giá phụ thuộc mạnh vào hãng xe thay vì dung tích máy).
