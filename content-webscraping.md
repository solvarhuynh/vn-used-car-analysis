KẾ HOẠCH THUYẾT TRÌNH MODULE: WEB SCRAPING & DATA PIPELINE
Đề tài: Phân tích thị trường ô tô cũ tại Việt Nam

--------------------------------------------------------------------------------
PHẦN 1: CHI TIẾT CÁC SLIDE THUYẾT TRÌNH
--------------------------------------------------------------------------------

SLIDE 1: TỔNG QUAN HỆ THỐNG THU THẬP DỮ LIỆU
- Ý chính:
+ Giới thiệu 3 nguồn dữ liệu chính: Bonbanh.com, Chotot.com và Oto.com.vn (hoặc nguồn tương đương).
+ Tại sao lại chọn các nguồn này? (Độ phủ thị trường cao, thông tin chi tiết).
+ Công cụ sử dụng: R (rvest cho HTML tĩnh, chromote/RSelenium cho dữ liệu động).
- Minh họa: Sơ đồ luồng dữ liệu từ Web -> Scraping Scripts -> Raw Data.

SLIDE 2: TỔNG QUAN CÀO DỮ LIỆU TỪ BONBANH.COM VÀ BANXEHOICU (web tĩnh)
- Ý chính:
+ Cấu trúc trang web Bonbanh và cách tiếp cận: Duyệt theo danh mục và phân trang.
+ Kỹ thuật xử lý: Bóc tách các trường thông tin quan trọng (Giá, Năm SX, ODO, Xuất xứ, Kiểu dáng).
+ Thách thức: Xử lý các trường hợp dữ liệu không đồng nhất hoặc bị ẩn số điện thoại/thông tin liên hệ.
- Minh họa: Ảnh chụp màn hình code rvest/chromote và kết quả dữ liệu thô sau khi cào.

SLIDE 3: TỔNG QUAN CÁC NGUỒN CÀO KHÁC & GIẢI PHÁP VƯỢT RÀO CẢN (web động)
- Ý chính:
+ Sự khác biệt về cấu trúc giữa Chotot (chromte).
+ Giải pháp kỹ thuật: Sử dụng `utils.R` để chuẩn hóa các hàm cào chung.
+ Cách xử lý lỗi: Tự động retry khi mất kết nối hoặc bị chặn (Blocking) bởi Cloudflare.
- Minh họa: Bảng so sánh đặc điểm cấu trúc dữ liệu giữa các trang web.

SLIDE 4: QUY TRÌNH LÀM SẠCH VÀ KIỂM ĐỊNH DỮ LIỆU (DATA CLEANING)
- Ý chính:
+ Xử lý dữ liệu rác: Loại bỏ tin trùng, tin ảo, xử lý giá trị khuyết (NA).
+ Vai trò của `validate_clean_data.R`: Kiểm tra tính logic (Ví dụ: Năm SX không thể là 2027, ODO không thể là số âm).
+ Chuẩn hóa đơn vị: Chuyển "750 triệu" -> 750 (numeric) để tính toán.
- Minh họa: Biểu đồ so sánh lượng dữ liệu trước và sau khi Clean.

SLIDE 5: KIẾN TRÚC CƠ SỞ DỮ LIỆU & HỢP NHẤT (MERGE DATA)
- Ý chính:
+ Tại sao dùng SQLite (`master_data.db`)? (Nhẹ, không cần server, truy vấn nhanh bằng SQL trong R).
+ Luồng hoạt động của `merge_data.R`: Hợp nhất dữ liệu từ nhiều nguồn về một chuẩn duy nhất (Master Schema).
+ Khử trùng lặp (Deduplication): Dựa trên URL hoặc ID tin đăng để đảm bảo không tính toán sai lệch.
- Minh họa: Sơ đồ cấu trúc bảng (ERD) đơn giản trong database.

SLIDE 6: HỆ THỐNG TỰ ĐỘNG CẬP NHẬT REALTIME
- Ý chính:
+ Giới thiệu `run_pipeline.R`: "Trái tim" của hệ thống, điều phối toàn bộ từ cào đến lưu trữ.
+ Cơ chế Realtime (`run_realtime.R`): Chạy định kỳ để cập nhật các tin đăng mới nhất trong ngày (Delta Scraping).
+ Lợi ích: Luôn có dữ liệu mới nhất để hiển thị lên Shiny App mà không cần chạy lại toàn bộ DB.
- Minh họa: Ảnh chụp màn hình Log hệ thống (`log.txt`) đang chạy tự động.

--------------------------------------------------------------------------------
PHẦN 2: PHÂN BỔ NHIỆM VỤ THUYẾT TRÌNH (THÀNH VIÊN A & B)
--------------------------------------------------------------------------------

1. THÀNH VIÊN A: NGƯỜI MỞ ĐƯỜNG (Dẫn dắt & Thực tế cào)
- Nhiệm vụ: Phụ trách Slide 1 và Slide 2.
- Cách trình bày:
+ Bắt đầu bằng việc giới thiệu tầm quan trọng của dữ liệu "sạch" và "tươi".
+ Trình bày cực kỳ chi tiết về case-study Bonbanh.com (Show case khả năng bóc tách dữ liệu phức tạp).
+ Đưa ra các khó khăn gặp phải khi cào thực tế và cách bạn đã vượt qua.
- Chuyển giao: "Để xử lý khối lượng dữ liệu khổng lồ từ nhiều nguồn này một cách khoa học, mời bạn A trình bày về hệ thống backend phía sau."

2. THÀNH VIÊN B: KIẾN TRÚC SƯ HỆ THỐNG (Chuyên sâu & Vận hành)
- Nhiệm vụ: Phụ trách Slide 3, 4, 5, 6.
- Cách trình bày:
+ Nói về tính bao quát: Cách quản lý nhiều nguồn cào cùng lúc bằng module `utils.R`.
+ Nhấn mạnh vào tư duy lập trình: Việc làm sạch và kiểm định (`validate_clean_data.R`) là chìa khóa để mô hình ML sau này chính xác.
+ Giải thích về tính bền vững: Database SQLite giúp dự án mở rộng quy mô dễ dàng.
+ Kết thúc ấn tượng: Trình diễn luồng Realtime Pipeline - Đây là điểm cộng rất lớn về mặt kỹ thuật cho đồ án.

--------------------------------------------------------------------------------
LỜI KHUYÊN CHO NHÓM:
- Nên chuẩn bị một đoạn Video ngắn (30s) quay cảnh code đang cào dữ liệu tự động để chèn vào Slide 2 hoặc 6.
- Khi nói về Realtime, hãy nhấn mạnh: "Dữ liệu của chúng em không phải là dữ liệu chết, nó sống và cập nhật liên tục".
- Cần nắm chắc giải thích về `utils.R` vì đây là nơi chứa các "vũ khí" dùng chung cho cả nhóm.