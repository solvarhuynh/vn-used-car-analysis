# KHUNG SƯỜN BÁO CÁO ĐỒ ÁN
# Môn học: Lập trình R cho phân tích
# Chủ đề: Phân tích thị trường ô tô cũ

Ghi chú sử dụng:
- Tài liệu này là khung sườn chi tiết để triển khai báo cáo học thuật.
- Khi viết báo cáo chính thức, cần thay các phần trong ngoặc vuông [ ... ] bằng kết quả thực tế sau khi chạy lại pipeline dữ liệu, visualization, machine learning và Shiny App.
- Các số liệu gợi ý hiện tại được đọc từ `web_scraping/data/master_data.csv`: 27.357 bản ghi hợp lệ sau lọc cơ bản, giá trung bình khoảng 812,7 triệu VNĐ, giá trung vị khoảng 528 triệu VNĐ, năm sản xuất từ 1990 đến 2026, các hãng xuất hiện nhiều gồm TOYOTA, FORD, VINFAST, HYUNDAI, KIA. Nên cập nhật lại các số này sau mỗi lần chạy `web_scraping/run_realtime.R` hoặc `web_scraping/run_pipeline.R`.

================================================================================
1. TÓM TẮT (ABSTRACT)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Viết một đoạn tóm tắt ngắn, khoảng 150-250 từ, trình bày đầy đủ bối cảnh, mục tiêu, phương pháp và kết quả chính của đồ án. Phần này nên được viết sau cùng, nhưng đặt ở đầu báo cáo.

Cấu trúc gợi ý:
- Câu 1-2: Nêu vấn đề nghiên cứu: thị trường ô tô cũ tại Việt Nam có nhiều biến động về giá, chịu ảnh hưởng bởi thương hiệu, năm sản xuất, số km đã đi, nhiên liệu, hộp số, kiểu dáng, nguồn gốc và khu vực rao bán.
- Câu 3-4: Nêu mục tiêu: xây dựng một quy trình phân tích dữ liệu bằng R nhằm thu thập, làm sạch, mô tả, trực quan hóa, mô hình hóa và hỗ trợ tra cứu/dự báo giá xe cũ.
- Câu 5-6: Nêu phương pháp: cào dữ liệu từ nhiều nguồn web, chuẩn hóa dữ liệu, lưu trữ vào SQLite/CSV, phân tích thống kê mô tả, trực quan hóa bằng ggplot2/plotly, xây dựng mô hình hồi quy, phân cụm và cây quyết định.
- Câu 7-8: Nêu kết quả: hệ thống tạo được bộ dữ liệu master, các biểu đồ thị trường, các chỉ số thống kê, mô hình dự báo/phân loại/phân cụm và giao diện Shiny App phục vụ người dùng cuối.
- Câu cuối: Nhấn mạnh giá trị thực tiễn: hệ thống có thể cập nhật dữ liệu mới theo cơ chế realtime, giúp theo dõi xu hướng giá và hỗ trợ ra quyết định mua bán xe cũ.

Nguồn kết quả cần lấy từ file nào?
- Dữ liệu tổng quan: `web_scraping/data/master_data.csv`, `web_scraping/data/master_data.db`.
- Báo cáo thống kê: `insights/descriptive_analytics/output_probability_statistics/Bao_Cao_Xac_Suat_Thong_Ke.txt`.
- Biểu đồ: `insights/visualization/plots/`.
- Kết quả mô hình: `machine_learning/output_models.RData`.
- Giao diện người dùng: `app.R`.

Đoạn mẫu có thể viết:
"Đồ án này xây dựng một hệ thống phân tích thị trường ô tô cũ tại Việt Nam bằng ngôn ngữ R. Dữ liệu được thu thập từ các trang rao bán xe, sau đó được làm sạch, chuẩn hóa và hợp nhất thành bộ dữ liệu master phục vụ phân tích. Trên cơ sở dữ liệu này, báo cáo triển khai các phân tích thống kê mô tả, trực quan hóa xu hướng giá theo thương hiệu, năm sản xuất, số km đã đi, kiểu dáng và các đặc trưng kỹ thuật; đồng thời xây dựng ba mô hình gồm hồi quy dự đoán giá, phân cụm phân khúc xe và cây quyết định phân loại mức giá. Kết quả cho thấy giá xe cũ chịu tác động rõ bởi tuổi xe, quãng đường đã đi, thương hiệu, hộp số và nguồn gốc xe. Ngoài phân tích tĩnh, đồ án còn phát triển pipeline cập nhật dữ liệu realtime và ứng dụng Shiny App để người dùng tra cứu, lọc dữ liệu và xem dự báo giá xe."

================================================================================
2. GIỚI THIỆU (INTRODUCTION)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Trình bày lý do chọn đề tài "Phân tích thị trường ô tô cũ" và ý nghĩa thực tiễn của việc theo dõi giá xe.

Các ý chính cần có:
- Thị trường ô tô cũ là thị trường có giá trị giao dịch lớn, nhiều người mua/bán cá nhân tham gia, thông tin phân tán trên nhiều website.
- Giá xe cũ không chỉ phụ thuộc vào thương hiệu mà còn phụ thuộc vào tuổi xe, số ODO, nhiên liệu, hộp số, kiểu dáng, nguồn gốc, khu vực và tình trạng thị trường.
- Người mua thường gặp khó khăn khi định giá hợp lý; người bán cần tham khảo mặt bằng giá để đặt giá cạnh tranh.
- Phân tích dữ liệu giúp biến dữ liệu rao bán rời rạc thành thông tin có cấu trúc: xu hướng, phân khúc, mức giá tham chiếu và dự báo.
- Đề tài phù hợp với môn "Lập trình R cho phân tích" vì kết hợp nhiều năng lực: thu thập dữ liệu, xử lý dữ liệu, thống kê mô tả, trực quan hóa, mô hình hóa, tự động hóa pipeline và xây dựng ứng dụng tương tác.

Nguồn kết quả cần lấy từ file nào?
- Mô tả mục tiêu và cấu trúc dự án có thể tham khảo `README.md`.
- Quy trình tổng thể có thể tham khảo `theory-flow.txt` nếu muốn liên kết với luồng lý thuyết/phân tích.
- Các module chính trong dự án:
  - `web_scraping/`: thu thập, làm sạch, lưu trữ và cập nhật dữ liệu.
  - `insights/descriptive_analytics/`: thống kê mô tả và xác suất.
  - `insights/visualization/`: trực quan hóa dữ liệu.
  - `machine_learning/`: mô hình học máy.
  - `app.R`: ứng dụng Shiny.

Gợi ý cách viết:
- Đoạn 1: Bối cảnh thị trường ô tô cũ.
- Đoạn 2: Vấn đề định giá và ra quyết định.
- Đoạn 3: Vai trò của R và phân tích dữ liệu.
- Đoạn 4: Mục tiêu, phạm vi và đóng góp của đồ án.

================================================================================
3. DỮ LIỆU (DATA)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần này mô tả nguồn dữ liệu, quy trình thu thập, quy trình làm sạch, cấu trúc lưu trữ và cơ chế cập nhật dữ liệu realtime.

3.1. Nguồn dữ liệu

Cần viết:
- Dữ liệu được thu thập từ các website rao bán ô tô cũ như Chợ Tốt, BonBanh và Bán Xe Hơi Cũ.
- Mỗi bản ghi đại diện cho một tin rao bán xe, gồm các trường như: thương hiệu, dòng xe, phiên bản, năm sản xuất, giá, số km đã đi, kiểu dáng, nhiên liệu, hộp số, dung tích động cơ, số chỗ, nguồn gốc, màu sắc, thành phố, ngày đăng, nguồn dữ liệu và URL.
- Dữ liệu ban đầu có tính không đồng nhất vì mỗi website có định dạng HTML, tên trường và cách ghi thông tin khác nhau.

Nguồn file cần trích dẫn:
- Script cào dữ liệu:
  - `web_scraping/script/scrap/scrap_chotot.R`
  - `web_scraping/script/scrap/scrap_bonbanh.R`
  - `web_scraping/script/scrap/scrap_banxehoicu.R`
- Dữ liệu raw:
  - `web_scraping/data/raw/data_chotot_raw.csv`
  - `web_scraping/data/raw/data_bonbanh_raw.csv`
  - `web_scraping/data/raw/data_banxehoicu_raw.csv`
- URL/checkpoint:
  - `web_scraping/data/raw/meta/urls_chotot.txt`
  - `web_scraping/data/raw/meta/urls_bonbanh.txt`
  - `web_scraping/data/raw/meta/urls_banxehoicu.txt`
  - `web_scraping/data/raw/meta/checkpoint_chotot.txt`
  - `web_scraping/data/raw/meta/checkpoint_banxehoicu.txt`

3.2. Quy trình thu thập dữ liệu bằng scraping

Cần viết:
- Pipeline chính được điều phối bởi `web_scraping/run_pipeline.R`.
- Khi chạy đầy đủ, pipeline thực hiện lần lượt:
  1. Cào dữ liệu từ Chợ Tốt.
  2. Cào dữ liệu từ Bán Xe Hơi Cũ.
  3. Cào dữ liệu từ BonBanh.
  4. Làm sạch dữ liệu từng nguồn.
  5. Kiểm định chất lượng dữ liệu sạch.
  6. Khởi tạo cơ sở dữ liệu SQLite theo từng nguồn.
  7. Gộp dữ liệu thành master database và master CSV.
- Pipeline có biến môi trường `RUN_SCRAPE`; khi đặt `RUN_SCRAPE=false`, có thể bỏ qua bước scraping và chỉ chạy lại các bước làm sạch/gộp dữ liệu.

Nguồn file cần trích dẫn:
- Điều phối pipeline: `web_scraping/run_pipeline.R`.
- Hàm tiện ích, schema, ghi log, đọc master data: `web_scraping/script/utils.R`.
- Khởi tạo database từng nguồn: `web_scraping/script/init_database.R`.
- Gộp dữ liệu master: `web_scraping/script/merge_data.R`.
- File log: `web_scraping/log.txt`.

3.3. Quy trình làm sạch dữ liệu

Cần viết:
- Dữ liệu raw thường có lỗi định dạng giá, ODO, năm sản xuất, tên hãng, hộp số, nhiên liệu, thành phố hoặc bản ghi bị thiếu trường.
- Các script clean chuẩn hóa tên cột, kiểu dữ liệu, đơn vị đo, loại bỏ bản ghi không hợp lệ và đưa dữ liệu về schema chung.
- Sau làm sạch, dữ liệu được lưu vào thư mục `web_scraping/data/clean/`.
- Script validate kiểm tra dữ liệu trùng lặp, dữ liệu thiếu, dữ liệu ngoài ngưỡng và xuất báo cáo chất lượng.

Nguồn file cần trích dẫn:
- Clean theo nguồn:
  - `web_scraping/script/clean/clean_chotot.R`
  - `web_scraping/script/clean/clean_bonbanh.R`
  - `web_scraping/script/clean/clean_banxehoicu.R`
- Dữ liệu sạch:
  - `web_scraping/data/clean/data_chotot_clean.csv`
  - `web_scraping/data/clean/data_bonbanh_clean.csv`
  - `web_scraping/data/clean/data_banxehoicu_clean.csv`
- Validate:
  - `web_scraping/script/validate_clean_data.R`
  - `web_scraping/data/quality_report/clean_validation_report.txt`
  - `web_scraping/data/quality_report/clean_validation_summary.csv`
  - `web_scraping/data/quality_report/duplicate_urls_cross_source.csv`

3.4. Lưu trữ dữ liệu

Cần viết:
- Dữ liệu sau gộp được lưu ở hai dạng:
  - SQLite database: phù hợp cho truy vấn, cập nhật và tích hợp Shiny/realtime.
  - CSV: thuận tiện cho phân tích thống kê, trực quan hóa và học máy.
- File chính:
  - `web_scraping/data/master_data.db`
  - `web_scraping/data/master_data.csv`
- Các database trung gian theo nguồn được lưu tại:
  - `web_scraping/data/init_db/data_chotot.db`
  - `web_scraping/data/init_db/data_bonbanh.db`
  - `web_scraping/data/init_db/data_banxehoicu.db`

3.5. Xử lý dữ liệu realtime

Cần viết:
- Ngoài pipeline batch, đồ án có module realtime để lấy dữ liệu trang đầu hoặc dữ liệu mới từ một số nguồn.
- Script `web_scraping/run_realtime.R` kết nối với `master_data.db`, gọi các script realtime theo nguồn, chèn bản ghi mới hợp lệ và rebuild `master_data.csv` khi có dữ liệu mới.
- Trong trạng thái hiện tại, realtime bật cho Chợ Tốt và BonBanh, còn Bán Xe Hơi Cũ đang được cấu hình tắt trong danh sách task.
- Cơ chế realtime giúp báo cáo không chỉ phản ánh dữ liệu quá khứ mà còn có khả năng cập nhật liên tục mặt bằng giá thị trường.

Nguồn file cần trích dẫn:
- Điều phối realtime: `web_scraping/run_realtime.R`.
- Script realtime:
  - `web_scraping/script/realtime/realtime_chotot.R`
  - `web_scraping/script/realtime/realtime_bonbanh.R`
  - `web_scraping/script/realtime/realtime_banxehoicu.R`
- Dữ liệu realtime:
  - `web_scraping/data/realtime/data_chotot_rt.csv`
  - `web_scraping/data/realtime/data_bonbanh_rt.csv`

3.6. Thống kê mô tả dữ liệu đầu vào

Cần viết:
- Nêu số lượng bản ghi sau làm sạch, số lượng nguồn dữ liệu, khoảng năm sản xuất, giá trung bình, giá trung vị và các hãng xe phổ biến.
- Có thể trình bày một bảng nhỏ:
  - Tổng số bản ghi hợp lệ: [điền từ output hoặc master_data.csv].
  - Giá trung bình: [điền].
  - Giá trung vị: [điền].
  - Khoảng năm sản xuất: [điền].
  - Top 5 hãng xe theo số tin: [điền].

Số liệu gợi ý hiện tại:
- Tổng bản ghi hợp lệ sau lọc cơ bản: 27.357.
- Giá trung bình: khoảng 812,7 triệu VNĐ.
- Giá trung vị: khoảng 528 triệu VNĐ.
- Năm sản xuất: 1990-2026.
- Top hãng theo số tin: TOYOTA, FORD, VINFAST, HYUNDAI, KIA.

Nguồn file cần trích dẫn:
- `web_scraping/data/master_data.csv`.
- `insights/descriptive_analytics/Probability_statistics.R`.
- `insights/descriptive_analytics/Cleaning_Data_For statistics.R`.
- `insights/descriptive_analytics/output_probability_statistics/01_tong_quan_du_lieu.csv`.
- `insights/descriptive_analytics/output_probability_statistics/02_thong_ke_mo_ta_tong_quat.csv`.

================================================================================
4. TRỰC QUAN HÓA DỮ LIỆU (DATA VISUALIZATION)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần này trình bày các biểu đồ chính nhằm trả lời: thị trường có cấu trúc ra sao, giá phân bố thế nào, yếu tố nào ảnh hưởng đến giá và nhóm xe nào chiếm ưu thế.

Nguồn file chính:
- Script tạo biểu đồ: `insights/visualization/Visualization.R`.
- Thư mục output: `insights/visualization/plots/`.

Các biểu đồ cần đưa vào báo cáo:

4.1. Tổng quan lượng tin và giá trung vị theo hãng xe

Biểu đồ:
- `insights/visualization/plots/00_OVERVIEW_Bar-Line_top50.png`
- Bản tương tác: `insights/visualization/plots/p0_overview_interactive.rds`

Cần viết:
- Mô tả top 50 hãng xe theo số lượng tin rao bán.
- So sánh giữa số lượng tin và giá trung vị.
- Nhận xét hãng nào phổ biến, hãng nào có giá trung vị cao/thấp.
- Giải thích ý nghĩa: số lượng tin phản ánh mức độ phổ biến/thanh khoản, trong khi giá trung vị phản ánh phân khúc.

4.2. Phân bổ giá theo hãng xe

Biểu đồ:
- `insights/visualization/plots/01_WHAT_boxplot_gia_theo_hang.png`
- Bản tương tác: `insights/visualization/plots/p1_what_interactive.rds`

Cần viết:
- Dùng boxplot để so sánh phân phối giá giữa các hãng.
- Nhận xét độ phân tán giá, giá trị ngoại lai, hãng có dải giá rộng.
- Nêu rằng thang log được dùng để xử lý dữ liệu giá có độ lệch lớn.

4.3. Xu hướng giá theo năm sản xuất

Biểu đồ:
- `insights/visualization/plots/02_WHEN_scatter_trend_khau_hao_nam.png`
- Bản tương tác: `insights/visualization/plots/p2_when_interactive.rds`

Cần viết:
- Phân tích xu hướng khấu hao: xe càng cũ thường có giá thấp hơn.
- Nhận xét các năm sản xuất gần hiện tại thường có giá cao hơn do tuổi xe thấp, công nghệ mới và hao mòn ít.
- Có thể nêu ngoại lệ: xe sang, xe hiếm hoặc xe nhập khẩu có thể giữ giá tốt hơn.

4.4. Mối quan hệ giữa ODO và giá xe

Biểu đồ:
- `insights/visualization/plots/03_WHY_scatter_odo_vs_price.png`
- Bản tương tác: `insights/visualization/plots/p3_why_interactive.rds`

Cần viết:
- Phân tích số km đã đi và giá xe.
- Nhận xét xu hướng: ODO càng cao thường giá càng giảm, nhưng mức ảnh hưởng phụ thuộc vào thương hiệu, năm sản xuất và phân khúc.
- Liên hệ với mô hình hồi quy: biến `mileage_k` được dùng để dự đoán giá.

4.5. Phân phối theo loại nhiên liệu

Biểu đồ:
- `insights/visualization/plots/04_DIST_fuel_type.png`
- Bản tương tác: `insights/visualization/plots/p4_fuel_interactive.rds`

Cần viết:
- Mô tả tỷ trọng xe xăng, dầu, hybrid, điện nếu có.
- Nhận xét xu hướng xe điện/hybrid nếu dữ liệu có xuất hiện.
- Liên hệ với biến nhiên liệu trong phân tích thị trường.

4.6. Phân phối theo kiểu dáng xe

Biểu đồ:
- `insights/visualization/plots/05_DIST_body_type.png`
- Bản tương tác: `insights/visualization/plots/p5_body_interactive.rds`

Cần viết:
- Mô tả các kiểu dáng phổ biến như Sedan, SUV/Crossover, Hatchback, Pickup, Van/Minibus.
- Phân tích sự khác biệt thị hiếu: SUV/Crossover có thể phổ biến do nhu cầu gia đình và đô thị; Sedan có thể vẫn chiếm tỷ trọng đáng kể.

4.7. Phân phối theo thành phố/khu vực

Biểu đồ:
- `insights/visualization/plots/06_DIST_city.png`
- Bản tương tác: `insights/visualization/plots/p6_city_interactive.rds`

Cần viết:
- Mô tả các thành phố có số lượng tin rao bán cao.
- Liên hệ với quy mô thị trường, mật độ dân cư và sức mua.
- Nếu dữ liệu tập trung ở Hà Nội, TP.HCM, Bình Dương, Đồng Nai, Đà Nẵng..., cần giải thích bằng bối cảnh kinh tế - giao thông.

Kết luận phần visualization:
- Tóm tắt các yếu tố ảnh hưởng đến giá: thương hiệu, năm sản xuất/tuổi xe, số ODO, kiểu dáng, nhiên liệu, hộp số, nguồn gốc, khu vực.
- Chuyển tiếp sang phần mô hình hóa: các phát hiện trực quan là cơ sở chọn biến cho mô hình hồi quy, phân cụm và cây quyết định.

================================================================================
5. MÔ HÌNH HÓA DỮ LIỆU (DATA MODELING)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần này trình bày mục tiêu mô hình hóa, dữ liệu đầu vào, biến đặc trưng, phương pháp chia train/test, ba mô hình chính và ý nghĩa đầu ra.

Nguồn file chính:
- Điều phối toàn bộ mô hình: `machine_learning/run_all.R`.
- Output mô hình: `machine_learning/output_models.RData`.

5.1. Chuẩn bị dữ liệu cho mô hình

Cần viết:
- Dữ liệu được đọc từ `web_scraping/data/master_data.csv` thông qua hàm `read_master_data()` trong `web_scraping/script/utils.R`.
- Các biến được ép kiểu và chuẩn hóa: `year`, `price`, `mileage`, `engine_size`, `seat_count`, `transmission`, `origin`.
- Các bản ghi không hợp lệ bị loại bỏ: năm ngoài khoảng 1990-năm hiện tại, giá dưới 50 triệu hoặc trên 15 tỷ, thiếu hãng/dòng xe.
- Các biến phái sinh:
  - `car_age = CURRENT_YEAR - year`
  - `price_billion = price / 1e9`
  - `log_price = log(price)`
  - `mileage_k = mileage / 1000`
  - `is_auto`
  - `is_imported`
  - `price_segment`
  - `body_type_clean`
- Các giá trị thiếu của mileage, engine size và seat count được thay thế bằng median theo nhóm hoặc median tổng.

Nguồn file cần trích dẫn:
- `machine_learning/run_all.R`.

5.2. Model 1: Regression - Dự đoán giá xe

Nguồn file:
- `machine_learning/model1_regression.R`.

Mục tiêu:
- Dự đoán giá xe dựa trên các đặc trưng kỹ thuật và tình trạng sử dụng.
- Biến mục tiêu là `log_price`, giúp ổn định phân phối giá và giảm ảnh hưởng của ngoại lai.

Mô hình:
- Hồi quy tuyến tính:
  `log_price ~ car_age + mileage_k + engine_size + is_auto + is_imported + seat_count`

Cần viết:
- Mô tả cách chia dữ liệu train/test theo tỷ lệ 80/20.
- Giải thích ý nghĩa các biến:
  - `car_age`: tuổi xe, kỳ vọng hệ số âm.
  - `mileage_k`: số km đã đi tính theo nghìn km, kỳ vọng hệ số âm.
  - `engine_size`: dung tích động cơ, có thể liên quan đến phân khúc giá.
  - `is_auto`: xe hộp số tự động.
  - `is_imported`: xe nhập khẩu.
  - `seat_count`: số chỗ ngồi.
- Trình bày bảng hệ số hồi quy từ `coef_df`.
- Trình bày chỉ số đánh giá từ `reg_metrics`: R-squared, Adjusted R-squared, RMSE, MAE, số dòng train/test.
- Nhận xét biến nào có ý nghĩa thống kê dựa trên `p_value` và cột `significant`.

Kết quả cần lấy từ:
- Object trong `machine_learning/output_models.RData`: `model_regression`, `reg_metrics`, `coef_df`, `reg_test_result`.

5.3. Model 2: Clustering - Phân nhóm phân khúc xe cũ

Nguồn file:
- `machine_learning/model2_clustering.R`.

Mục tiêu:
- Phân nhóm xe cũ dựa trên các đặc trưng định lượng để nhận diện các phân khúc thị trường.

Biến sử dụng:
- `price_billion`
- `car_age`
- `mileage_k`
- `engine_size`

Mô hình:
- K-means clustering.
- Dữ liệu được chuẩn hóa bằng `scale()`.
- Số cụm đang đặt là `OPTIMAL_K <- 4`.

Cần viết:
- Giải thích vì sao cần chuẩn hóa dữ liệu trước khi phân cụm.
- Trình bày phương pháp elbow qua `elbow_df` để tham khảo lựa chọn số cụm.
- Trình bày chỉ số silhouette trung bình `avg_silhouette` để đánh giá mức độ tách cụm.
- Mô tả 4 cụm theo `profile_df`, gồm:
  - Số xe trong cụm.
  - Tỷ lệ phần trăm.
  - Giá trung bình/trung vị.
  - Tuổi xe trung bình.
  - Số km trung bình.
  - Dung tích động cơ trung bình.
  - Tên cụm gợi ý: "Xe phổ thông / Dịch vụ", "Xe gia đình đô thị", "Xe gia đình chạy nhiều", "Xe cao cấp / Hạng sang".

Kết quả cần lấy từ:
- Object trong `machine_learning/output_models.RData`: `model_kmeans`, `elbow_df`, `avg_silhouette`, `profile_df`, `cluster_centers_real`, `df_final`.

5.4. Model 3: Decision Tree - Phân loại phân khúc giá

Nguồn file:
- `machine_learning/model3_decision_tree.R`.

Mục tiêu:
- Phân loại xe vào các phân khúc giá: "Phổ thông", "Tầm trung", "Khá", "Cao cấp".

Biến đầu vào:
- `car_age`
- `mileage_k`
- `engine_size`
- `is_auto`
- `is_imported`
- `seat_count`

Mô hình:
- Cây quyết định bằng `rpart`.
- Dữ liệu được chia train/test theo phương pháp stratified sampling để giữ tỷ lệ các phân khúc giá.
- Cây được prune theo `best_cp` để giảm overfitting.

Cần viết:
- Giải thích ưu điểm của cây quyết định: dễ diễn giải, phù hợp để chỉ ra quy tắc phân loại.
- Trình bày chỉ số `tree_accuracy` và `tree_kappa`.
- Trình bày confusion matrix từ `conf_table`.
- Trình bày mức độ quan trọng biến từ `feat_imp`.
- Nhận xét biến nào đóng vai trò lớn nhất trong việc phân loại phân khúc giá.

Kết quả cần lấy từ:
- Object trong `machine_learning/output_models.RData`: `model_tree`, `tree_accuracy`, `tree_kappa`, `conf_table`, `feat_imp`, `class_metrics`.

================================================================================
6. THỰC NGHIỆM, KẾT QUẢ, VÀ THẢO LUẬN
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần này tổng hợp kết quả phân tích, so sánh hiệu năng mô hình, thảo luận ý nghĩa thực tiễn, nhấn mạnh yếu tố realtime và giới thiệu ứng dụng Shiny.

6.1. Thiết lập thực nghiệm

Cần viết:
- Môi trường phân tích sử dụng ngôn ngữ R.
- Dữ liệu đầu vào là `web_scraping/data/master_data.csv`.
- Các bước thực nghiệm:
  1. Chạy pipeline scraping/clean/merge nếu cần.
  2. Chạy thống kê mô tả và xác suất.
  3. Chạy visualization.
  4. Chạy `machine_learning/run_all.R` để huấn luyện mô hình.
  5. Chạy `app.R` để kiểm tra giao diện Shiny.

Nguồn file cần trích dẫn:
- `web_scraping/run_pipeline.R`
- `insights/descriptive_analytics/Probability_statistics.R`
- `insights/visualization/Visualization.R`
- `machine_learning/run_all.R`
- `app.R`

6.2. Kết quả thống kê mô tả và xác suất

Cần viết:
- Tóm tắt số lượng bản ghi, số nguồn, phân phối giá, phân phối hãng xe, phân phối hộp số, nhiên liệu và nhóm tuổi xe.
- Nếu dùng phân tích xác suất, trình bày:
  - Xác suất cơ bản của các nhóm xe.
  - Xác suất giá cao theo hộp số.
  - Xác suất giá cao theo hãng xe.
  - Xác suất nhiên liệu theo hộp số.
  - Kiểm định thống kê nếu có.

Nguồn file cần trích dẫn:
- `insights/descriptive_analytics/output_probability_statistics/00_tong_quan_lam_sach.csv`
- `insights/descriptive_analytics/output_probability_statistics/01_tong_quan_du_lieu.csv`
- `insights/descriptive_analytics/output_probability_statistics/02_thong_ke_mo_ta_tong_quat.csv`
- `insights/descriptive_analytics/output_probability_statistics/03_thong_ke_gia_theo_hang_xe.csv`
- `insights/descriptive_analytics/output_probability_statistics/04_thong_ke_gia_theo_hop_so.csv`
- `insights/descriptive_analytics/output_probability_statistics/09_xac_suat_co_ban.csv`
- `insights/descriptive_analytics/output_probability_statistics/12_xac_suat_gia_cao_theo_hop_so.csv`
- `insights/descriptive_analytics/output_probability_statistics/13_xac_suat_gia_cao_theo_hang_xe.csv`
- `insights/descriptive_analytics/output_probability_statistics/16_kiem_dinh_thong_ke.csv`
- `insights/descriptive_analytics/output_probability_statistics/Bao_Cao_Xac_Suat_Thong_Ke.txt`

6.3. So sánh hiệu năng mô hình

Cần viết:
- Tạo bảng so sánh ba mô hình:

| Mô hình | Mục tiêu | Chỉ số chính | Giá trị | Ý nghĩa |
|---|---|---|---|---|
| Regression | Dự đoán giá xe | R-squared, Adjusted R-squared, RMSE, MAE | [điền từ `reg_metrics`] | Đánh giá mức độ giải thích và sai số dự đoán giá |
| Clustering | Phân nhóm xe | Avg. silhouette, số cụm, profile cụm | [điền từ `avg_silhouette`, `profile_df`] | Đánh giá mức độ tách cụm và ý nghĩa phân khúc |
| Decision Tree | Phân loại phân khúc giá | Accuracy, Kappa | [điền từ `tree_accuracy`, `tree_kappa`] | Đánh giá khả năng phân loại đúng phân khúc |

Nguồn file cần trích dẫn:
- `machine_learning/output_models.RData`.
- `machine_learning/model1_regression.R`.
- `machine_learning/model2_clustering.R`.
- `machine_learning/model3_decision_tree.R`.

Cách viết nhận xét:
- Regression phù hợp khi cần ước lượng giá trị giá bán liên tục.
- Clustering phù hợp khi cần hiểu cấu trúc phân khúc thị trường mà không cần nhãn có sẵn.
- Decision Tree phù hợp khi cần diễn giải quy tắc phân loại phân khúc giá.
- Không nên chỉ chọn mô hình theo một chỉ số; cần xét mục tiêu sử dụng, khả năng diễn giải và độ ổn định.

6.4. Nhận định cập nhật đến năm 2026

Cần viết một đoạn bắt buộc có ý "Tính đến thời điểm hiện tại (năm 2026)...".

Đoạn gợi ý:
"Tính đến thời điểm hiện tại (năm 2026), dữ liệu master sau lọc cơ bản ghi nhận 27.357 tin rao bán hợp lệ, với giá trung bình khoảng 812,7 triệu VNĐ và giá trung vị khoảng 528 triệu VNĐ. Khoảng năm sản xuất trong dữ liệu trải từ 1990 đến 2026, cho thấy bộ dữ liệu bao quát cả xe đời cũ, xe đã qua sử dụng gần đây và một số mẫu xe rất mới. Các thương hiệu có số lượng tin nổi bật gồm TOYOTA, FORD, VINFAST, HYUNDAI và KIA. Điều này gợi ý rằng thị trường ô tô cũ tập trung mạnh ở các thương hiệu phổ biến, có độ nhận diện cao và nguồn cung lớn. Xu hướng chung cho thấy xe có tuổi đời thấp, số km đã đi ít, hộp số tự động hoặc thuộc nhóm thương hiệu/kiểu dáng được ưa chuộng thường có mặt bằng giá cao hơn."

Lưu ý:
- Trước khi nộp báo cáo, chạy lại `web_scraping/run_realtime.R` hoặc `web_scraping/run_pipeline.R`, sau đó cập nhật lại số liệu trong đoạn này.
- Nếu số liệu thay đổi, dùng số mới từ `web_scraping/data/master_data.csv` và các output thống kê.

6.5. Thảo luận về hệ thống realtime

Cần viết:
- Hệ thống realtime giúp cập nhật dữ liệu mới mà không cần chạy lại toàn bộ scraping batch.
- `run_realtime.R` kết nối tới `master_data.db`, chạy các script realtime, chèn bản ghi mới và rebuild `master_data.csv`.
- Realtime phù hợp với bài toán thị trường vì giá xe, số lượng tin và xu hướng nguồn cung có thể thay đổi theo ngày/tuần.
- Hạn chế: realtime phụ thuộc vào cấu trúc website nguồn; nếu website thay đổi HTML hoặc chặn truy cập, cần cập nhật script.

Nguồn file cần trích dẫn:
- `web_scraping/run_realtime.R`
- `web_scraping/script/realtime/realtime_chotot.R`
- `web_scraping/script/realtime/realtime_bonbanh.R`
- `web_scraping/script/realtime/realtime_banxehoicu.R`
- `web_scraping/log.txt`

6.6. Giới thiệu Shiny App

Cần viết:
- Ứng dụng Shiny trong `app.R` đóng vai trò giao diện tương tác cho người dùng.
- App đọc dữ liệu từ `web_scraping/data/master_data.csv` và mô hình từ `machine_learning/output_models.RData`.
- Người dùng có thể lọc dữ liệu, xem bảng tin, biểu đồ, thống kê và kết quả dự báo/phân loại/phân cụm tùy theo thiết kế giao diện.
- Giá trị thực tiễn: thay vì chỉ đọc báo cáo tĩnh, người dùng có thể tương tác trực tiếp với dữ liệu và mô hình.

Nguồn file cần trích dẫn:
- `app.R`.

================================================================================
7. KẾT LUẬN (CONCLUSIONS)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Viết 3-5 đoạn ngắn tổng kết kết quả đạt được, hạn chế và hướng phát triển.

Các ý cần có:
- Đồ án đã xây dựng được quy trình dữ liệu tương đối hoàn chỉnh cho bài toán phân tích thị trường ô tô cũ: scraping, cleaning, validation, database, master CSV, thống kê, visualization, machine learning, realtime và Shiny App.
- Về phân tích, báo cáo đã chỉ ra các yếu tố quan trọng ảnh hưởng đến giá xe: tuổi xe, số km đã đi, thương hiệu, kiểu dáng, hộp số, nguồn gốc, dung tích động cơ và khu vực.
- Về mô hình hóa, ba mô hình giải quyết ba góc nhìn khác nhau:
  - Regression: dự đoán giá liên tục.
  - Clustering: nhận diện phân khúc xe.
  - Decision Tree: phân loại phân khúc giá và diễn giải quy tắc.
- Về ứng dụng, Shiny App giúp đưa kết quả phân tích đến người dùng cuối dưới dạng tương tác.

Hạn chế cần nêu:
- Dữ liệu phụ thuộc vào chất lượng tin rao và cấu trúc website nguồn.
- Giá rao bán không nhất thiết là giá giao dịch thực tế.
- Một số thuộc tính như tình trạng xe, lịch sử tai nạn, bảo dưỡng, phiên bản chi tiết có thể chưa đầy đủ.
- Mô hình hiện tại chủ yếu dựa trên các biến có cấu trúc, chưa khai thác sâu mô tả văn bản hoặc hình ảnh xe.

Hướng phát triển:
- Tối ưu thuật toán cào dữ liệu, tăng khả năng chống thay đổi cấu trúc website.
- Tự động hóa lịch chạy realtime theo ngày/giờ.
- Bổ sung mô hình nâng cao: Random Forest, XGBoost, LightGBM, mô hình xử lý văn bản mô tả tin đăng.
- Bổ sung dashboard giám sát realtime và cảnh báo biến động giá.
- Tăng cường đánh giá mô hình bằng cross-validation và tập kiểm thử theo thời gian.

Nguồn file cần nhắc lại:
- `web_scraping/run_pipeline.R`
- `web_scraping/run_realtime.R`
- `insights/visualization/Visualization.R`
- `machine_learning/run_all.R`
- `app.R`

================================================================================
8. PHỤ LỤC (APPENDICES)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần phụ lục dùng để đặt các bảng tra cứu, danh sách biến, lệnh chạy, cấu hình pipeline và các đoạn code quan trọng nhưng không nên đưa quá dài vào phần thân báo cáo.

8.1. Bảng mô tả biến dữ liệu

Gợi ý bảng:

| Tên biến | Ý nghĩa | Kiểu dữ liệu | Ghi chú |
|---|---|---|---|
| brand | Thương hiệu xe | character | Ví dụ: TOYOTA, FORD |
| model | Dòng xe | character | Ví dụ: Vios, Ranger |
| year | Năm sản xuất | integer | Dùng để tính tuổi xe |
| price | Giá rao bán | numeric | Đơn vị VNĐ |
| mileage | Số km đã đi | numeric | ODO |
| transmission | Hộp số | character | Tự động, Số sàn, CVT |
| fuel_type | Nhiên liệu | character | Xăng, Dầu, Hybrid, Điện |
| body_type | Kiểu dáng | character | Sedan, SUV, Hatchback... |
| origin | Nguồn gốc | character | Trong nước, Nhập khẩu |
| city | Khu vực | character | Tỉnh/thành phố |
| source | Nguồn website | character | Chợ Tốt, BonBanh... |
| url | Link tin đăng | character | Dùng kiểm tra trùng lặp |

Nguồn tham khảo:
- `web_scraping/script/utils.R`.
- `web_scraping/data/master_data.csv`.

8.2. Lệnh chạy hệ thống

Gợi ý đưa vào phụ lục:

```r
# Chạy toàn bộ pipeline, bao gồm scraping
Sys.setenv(RUN_SCRAPE = "true")
source("web_scraping/run_pipeline.R")

# Chạy pipeline từ dữ liệu đã cào, bỏ qua scraping
Sys.setenv(RUN_SCRAPE = "false")
source("web_scraping/run_pipeline.R")

# Chạy realtime update
source("web_scraping/run_realtime.R")

# Tạo biểu đồ
source("insights/visualization/Visualization.R")

# Huấn luyện toàn bộ mô hình
source("machine_learning/run_all.R")

# Chạy Shiny App
shiny::runApp("app.R")
```

8.3. Bảng output quan trọng

Liệt kê các output để người đọc kiểm tra:
- Master data: `web_scraping/data/master_data.csv`, `web_scraping/data/master_data.db`.
- Quality report: `web_scraping/data/quality_report/clean_validation_report.txt`.
- Probability/statistics report: `insights/descriptive_analytics/output_probability_statistics/`.
- Visualization plots: `insights/visualization/plots/`.
- Machine learning output: `machine_learning/output_models.RData`.

8.4. Code hoặc cấu hình phức tạp

Nên đưa các đoạn sau vào phụ lục nếu cần:
- Luồng task trong `web_scraping/run_pipeline.R`.
- Danh sách realtime scripts trong `web_scraping/run_realtime.R`.
- Công thức hồi quy trong `machine_learning/model1_regression.R`.
- Cách đặt `OPTIMAL_K <- 4` trong `machine_learning/model2_clustering.R`.
- Thiết lập `rpart.control()` và pruning trong `machine_learning/model3_decision_tree.R`.

================================================================================
9. ĐÓNG GÓP (CONTRIBUTIONS)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần này mô tả phân công công việc trong nhóm gồm 5 thành viên. Do đồ án tập trung mạnh vào các khối lượng phân tích cốt lõi (Clean - XSTK, Visual, Model), các thành viên đều tham gia phối hợp chéo vào các phần này để đảm bảo khối lượng học thuật đồng đều.

Gợi ý phân công:

| Thành viên | Vai trò chính | Công việc cụ thể | File/module phụ trách |
|-----------------|-----------------|-----------------|-----------------|
| Thành viên 1 | Data Scraping & Core Clean | - Xây dựng script cào dữ liệu (Chợ Tốt, BonBanh).<br>- Chuẩn hóa cấu trúc thô và tham gia pha **Làm sạch dữ liệu (Clean)**.<br>- Phối hợp xây dựng **Mô hình 2 (Clustering)** để phân nhóm phân khúc xe. | `web_scraping/script/scrap/`, `web_scraping/script/clean/clean_chotot.R`, `machine_learning/model2_clustering.R` |

| Thành viên 2 | Pipeline Automation & Data Quality | - Xây dựng script cào dữ liệu (Bán Xe Hơi Cũ), thiết lập **Realtime update**.<br>- Chủ trì **Validate dữ liệu sạch**, xử lý trùng lặp và outliers.<br>- Phối hợp xây dựng **Mô hình 3 (Decision Tree)** để phân loại mức giá. | `web_scraping/script/scrap/`, `web_scraping/script/validate_clean_data.R`, `web_scraping/run_realtime.R`, `machine_learning/model3_decision_tree.R` |

| Thành viên 3 | Database & Probability Statistics | - Khởi tạo SQLite, gộp master dữ liệu.<br>- Chủ trì module **Xác suất Thống kê (XSTK)** và thực hiện kiểm định.<br>- Phối hợp xử lý dữ liệu đầu vào cho **Mô hình 1 (Regression)**. | `web_scraping/script/init_database.R`, `web_scraping/script/merge_data.R`, `insights/descriptive_analytics/`, `machine_learning/model1_regression.R` |

| Thành viên 4 | Data Visualization & Predictive Modeling | - Chủ trì thiết kế hệ thống **Trực quan hóa (Visual)** bằng ggplot2/plotly.<br>- Phân tích xu hướng thị trường trên biểu đồ.<br>- Chủ trì huấn luyện và tối ưu **Mô hình 1 (Regression)** dự đoán giá xe. | `insights/visualization/Visualization.R`, `insights/visualization/plots/`, `machine_learning/model1_regression.R` |

| Thành viên 5 | Shiny Application & Advanced Modeling | - Xây dựng cấu trúc tương tác và giao diện **Shiny App**.<br>- Tích hợp dữ liệu và hệ thống biểu đồ lên Web.<br>- Chủ trì huấn luyện **Mô hình 2 (Clustering)** và **Mô hình 3 (Decision Tree)**. | `app.R`, `machine_learning/model2_clustering.R`, `machine_learning/model3_decision_tree.R` |

Cách viết học thuật:
- Báo cáo nhấn mạnh mô hình làm việc cộng tác: Pha xử lý dữ liệu (Clean) gắn liền với cấu trúc cào (Thành viên 1, 2); Pha Phân tích dữ liệu (Visual - XSTK) bổ trợ trực tiếp cho chọn biến; Khối lượng học máy (Model) được chia nhỏ theo thuật toán và tích hợp trực tiếp lên sản phẩm Shiny App (Thành viên 4, 5).

================================================================================
10. THAM KHẢO (REFERENCES)
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Phần này liệt kê tài liệu tham khảo, thư viện R sử dụng và nguồn website cào dữ liệu. Nên dùng một phong cách trích dẫn thống nhất, ví dụ APA đơn giản.

10.1. Thư viện R nên trích dẫn

Gợi ý:
- R Core Team. R: A Language and Environment for Statistical Computing.
- Wickham et al. `tidyverse` hoặc các package trong hệ sinh thái tidyverse.
- Wickham. `ggplot2`: Elegant Graphics for Data Analysis.
- Sievert. `plotly` for R.
- Chang et al. `shiny`.
- Xie, Cheng, Tan. `DT`.
- Therneau, Atkinson. `rpart`.
- Hahsler hoặc các tác giả liên quan nếu dùng clustering package; trong dự án có dùng `cluster`.
- RSQLite/DBI cho kết nối SQLite.
- rvest nếu dùng trong script scraping.

Các package xuất hiện trong dự án:
- `dplyr`
- `readr`
- `stringr`
- `ggplot2`
- `plotly`
- `scales`
- `shiny`
- `DT`
- `DBI`
- `RSQLite`
- `rpart`
- `cluster`

10.2. Nguồn website dữ liệu

Cần ghi rõ dữ liệu được thu thập phục vụ mục đích học tập/nghiên cứu từ các website rao bán ô tô cũ, ví dụ:
- Chợ Tốt Xe.
- BonBanh.
- Bán Xe Hơi Cũ.

Lưu ý khi viết:
- Không khẳng định dữ liệu là đại diện tuyệt đối cho toàn bộ thị trường Việt Nam.
- Ghi rõ dữ liệu phản ánh các tin rao bán quan sát được trong phạm vi các nguồn và thời điểm thu thập.
- Nếu báo cáo chính thức yêu cầu URL cụ thể, lấy URL nguồn từ các file:
  - `web_scraping/data/raw/meta/urls_chotot.txt`
  - `web_scraping/data/raw/meta/urls_bonbanh.txt`
  - `web_scraping/data/raw/meta/urls_banxehoicu.txt`

10.3. Mẫu danh mục tham khảo

Gợi ý mẫu:
- R Core Team. (2026). R: A language and environment for statistical computing. R Foundation for Statistical Computing.
- Wickham, H. (2016). ggplot2: Elegant graphics for data analysis. Springer.
- Chang, W., Cheng, J., Allaire, J., Xie, Y., & McPherson, J. shiny: Web Application Framework for R.
- Therneau, T., & Atkinson, B. rpart: Recursive Partitioning and Regression Trees.
- RStudio/Posit and package authors. DBI, RSQLite, dplyr, readr, stringr, plotly, DT, cluster package documentation.
- Chợ Tốt Xe. Dữ liệu tin rao ô tô cũ được thu thập phục vụ học tập.
- BonBanh. Dữ liệu tin rao ô tô cũ được thu thập phục vụ học tập.
- Bán Xe Hơi Cũ. Dữ liệu tin rao ô tô cũ được thu thập phục vụ học tập.

================================================================================
11. PEER ASSESSMENT
================================================================================

Nội dung cần triển khai/viết gì ở đây?

Thiết kế bảng đánh giá chéo mức độ đóng góp của từng thành viên. Bảng được mở rộng cấu trúc cho nhóm 5 người, đảm bảo tính minh bạch và ghi nhận đúng vai trò phối hợp module.

11.1. Bảng đánh giá tổng quan

| Thành viên | Tỷ lệ đóng góp (%) | Công việc chính | Ưu điểm | Hạn chế/cần cải thiện | Xác nhận |
|---------------|---------------|---------------|---------------|---------------|---------------|
| Thành viên 1 | 20% | Scraping, Clean & Clustering Model | Thu thập dữ liệu ổn định, làm sạch kỹ, đóng góp tốt vào logic phân cụm xe. | Cần chú thích code rõ ràng hơn ở module scraping. | Đồng ý/Chưa đồng ý |

| Thành viên 2 | 20% | Realtime, Quality Validation & Tree Model | Cấu hình realtime nhạy bén, kiểm định chất lượng nghiêm ngặt, đóng góp tốt vào phân loại cây quyết định. | Tốc độ xử lý đồng bộ realtime cần được tối ưu thêm. | Đồng ý/Chưa đồng ý |

| Thành viên 3 | 20% | Database, XSTK & Regression Model | Thiết kế DB tối ưu, tính toán xác suất và kiểm định chính xác, hỗ trợ tốt phần xử lý biến hồi quy. | Cần phân tích sâu hơn ý nghĩa kinh tế của các kết quả kiểm định. | Đồng ý/Chưa đồng ý |

| Thành viên 4 | 20% | Visualization & Regression Model | Biểu đồ trực quan và đẹp mắt, xây dựng mô hình hồi quy dự đoán giá xe có độ chính xác cao. | Cần điều chỉnh giảm bớt các điểm ngoại lai trên boxplot để dễ quan sát hơn. | Đồng ý/Chưa đồng ý |

| Thành viên 5 | 20% | Shiny App, Clustering & Tree Model | Giao diện Web tương tác mượt mà, tối ưu tốt thuật toán phân cụm và cây quyết định trên hệ thống. | Cần bổ sung thêm tài liệu hướng dẫn sử dụng nhanh cho các tính năng trên App. | Đồng ý/Chưa đồng ý |

11.2. Bảng tiêu chí chi tiết

| Tiêu chí | Mô tả | Thang điểm |
|---|---|---:|
| Hoàn thành nhiệm vụ | Mức độ hoàn thành phần được giao đúng hạn | 0-10 |
| Chất lượng kỹ thuật | Code chạy được, rõ ràng, có cấu trúc, ít lỗi | 0-10 |
| Chất lượng phân tích | Nhận xét có cơ sở dữ liệu, lập luận hợp lý (Clean/XSTK/Visual/Model) | 0-10 |
| Phối hợp nhóm | Chủ động trao đổi, hỗ trợ các thành viên phối hợp module chéo | 0-10 |
| Đóng góp báo cáo | Tham gia viết, chỉnh sửa, kiểm tra nội dung | 0-10 |

11.3. Mẫu nhận xét từng thành viên

Thành viên 1:
- Mức độ hoàn thành: 100%.
- Ưu điểm: Chủ động giải quyết xung đột cấu trúc dữ liệu thô, phối hợp tốt với Thành viên 5 để giải thích kết quả phân cụm K-means.
- Hạn chế: Cần bổ sung thêm các đoạn log lỗi cho script clean ban đầu.

Thành viên 2:
- Mức độ hoàn thành: 100%.
- Ưu điểm: Xây dựng bộ quy tắc validate chặt chẽ giúp master data sạch hoàn toàn, hỗ trợ Thành viên 5 cấu hình hiệu quả thuật toán cây quyết định.
- Hạn chế: Cần tối ưu thời gian phản hồi khi script realtime chạy tác vụ gộp dữ liệu.

Thành viên 3:
- Mức độ hoàn thành: 100%.
- Ưu điểm: Đóng gói dữ liệu SQLite rất khoa học, triển khai các công thức xác suất thực tế, chuẩn bị tốt ma trận biến cho mô hình hồi quy tuyến tính.
- Hạn chế: Phần viết báo cáo chương XSTK cần diễn giải gãy gọn hơn ở các đoạn kiểm định phức tạp.

Thành viên 4:
- Mức độ hoàn thành: 100%.
- Ưu điểm: Làm chủ các thư viện đồ họa mạnh (ggplot2, plotly), làm nổi bật xu hướng giá thị trường và làm mịn tốt sai số của mô hình hồi quy (RMSE, MAE).
- Hạn chế: Cần đồng bộ màu sắc đồng nhất giữa các biểu đồ tĩnh và biểu đồ tương tác.

Thành viên 5:
- Mức độ hoàn thành: 100%.
- Ưu điểm: Thiết kế cấu trúc UI/UX của Shiny App logic, đóng gói thành công các thuật toán phân tích nâng cao (K-means, rpart) lên môi trường web tương tác.
- Hạn chế: Cần tối ưu hóa phần hiển thị bảng tin (DT) khi lượng bản ghi master data tăng lên.

11.4. Gợi ý tổng tỷ lệ đóng góp

Vì khối lượng công việc cốt lõi (Clean, XSTK, Visual, Model) đã được xé nhỏ và phân bổ đan xen đồng đều cho cả 5 người, tỷ lệ đóng góp của các thành viên được thống nhất chia đều:
- Thành viên 1: 20%.
- Thành viên 2: 20%.
- Thành viên 3: 20%.
- Thành viên 4: 20%.
- Thành viên 5: 20%.

================================================================================
KẾT THÚC KHUNG SƯỜN
================================================================================

Checklist trước khi nộp báo cáo:
- [ ] Chạy lại `web_scraping/run_pipeline.R` hoặc `web_scraping/run_realtime.R` nếu cần cập nhật dữ liệu.
- [ ] Chạy lại `insights/descriptive_analytics/Probability_statistics.R`.
- [ ] Chạy lại `insights/visualization/Visualization.R`.
- [ ] Chạy lại `machine_learning/run_all.R`.
- [ ] Kiểm tra `machine_learning/output_models.RData` có đủ kết quả.
- [ ] Mở `app.R` để chụp màn hình Shiny App nếu báo cáo cần minh họa.
- [ ] Cập nhật các số liệu trong phần 3 và phần 6 theo dữ liệu mới nhất.
- [ ] Đảm bảo đủ 11 phần đúng yêu cầu giảng viên.
