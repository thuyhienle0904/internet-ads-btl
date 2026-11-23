# Dữ liệu

- `raw/`: chỉ đặt bản dataset nguyên gốc; không sửa trực tiếp.
- `processed/`: chỉ chứa file do `scripts/01_data_setup.R` sinh ra.
- `reference/ad.names`: file tên cột gốc trong bản tải UCI (`internet+advertisements.zip`); được commit vì không phải dữ liệu, `scripts/term_names.R` dùng file này để đặt tên 1.554 biến term.

Không commit dữ liệu thô, dữ liệu đã xử lý hoặc thông tin đăng nhập/tokens. Tường ghi nguồn, tên file và ngày tải trong `report/sections/01_overview.tex` khi bắt đầu làm nội dung.
