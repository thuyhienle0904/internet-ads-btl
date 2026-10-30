# Quy trình từ dữ liệu đến report

## Thứ tự chạy

```text
01_data_setup.R → 02_eda_descriptive.R → 03_inference_model.R → 04_evaluation.R
```

- Không chạy các bước sau trên dữ liệu chưa qua `01_data_setup.R`.
- Mỗi script chỉ đọc input đã nêu trong phần đầu file và chỉ ghi vào `data/processed/` hoặc `output/`.
- Tất cả số liệu/bảng/hình trong report phải truy ngược được về một file trong `output/`.

## Cách ghép report

1. Phúc điền `report/settings.tex` và biên dịch `report/thesis.tex` trước khi nhóm viết nội dung.
2. Mỗi người chỉ sửa file `.tex` mình sở hữu trong `report/sections/`.
3. Người viết một bảng/hình gửi luôn file ở `output/tables/` hoặc `output/figures/`, caption và 2–3 câu diễn giải.
4. Phúc chèn/chuẩn hoá nội dung, Tân kiểm tra số liệu trong PDF khớp với output cuối.
5. Biên dịch PDFLaTeX hai lần trước khi chốt PDF; nếu đã có citation, chạy `bibtex thesis` giữa hai lần đó.

## Preview trước khi bàn giao

Mỗi người chọn file section của mình trong `report/preview.tex` bằng dòng `\newcommand{\previewfile}{...}`, rồi chạy `pdflatex preview.tex` tại thư mục `report/`. `thesis.tex` luôn render toàn bộ report; không dùng `preview.tex` để nộp bài.

## Điều kiện bàn giao một phần

Một phần chỉ được coi là xong khi có đủ: code chạy được, output được đặt tên rõ, nội dung section tương ứng, và một người khác đã đọc chéo.
