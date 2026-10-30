# Chạy và preview LaTeX

Template này dùng **PDFLaTeX** với file chính `thesis.tex`. Đừng compile từng file trong `sections/` trực tiếp: các file đó chỉ là nội dung được nạp vào một document hoàn chỉnh.

## Preview section đang viết

1. Mở `preview.tex`.
2. Đổi dòng sau thành section của mình:

   ```tex
   \newcommand{\previewfile}{sections/01_overview}
   ```

   Các lựa chọn hợp lệ:

   ```text
   sections/01_overview
   sections/02_background
   sections/03_preprocessing
   sections/04_descriptive
   sections/05_inference
   sections/06_discussion
   sections/07_sources
   sections/08_references
   ```

3. Mở PowerShell tại thư mục `report/`, chạy:

   ```powershell
   pdflatex -interaction=nonstopmode -halt-on-error preview.tex
   ```

4. Mở `preview.pdf`. Khi đổi section, chạy lại lệnh này.

## Render toàn bộ report

Tại thư mục `report/`, chạy:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
```

File kết quả là `thesis.pdf`. Nếu report đã có citation trong text và BibTeX entries trong `refs/references.bib`, dùng:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
bibtex thesis
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
```

## File nào sửa ở đâu

- `settings.tex`: Phúc cập nhật bìa, thành viên, giảng viên và package dùng chung.
- `content.tex`: chỉ giữ thứ tự rubric và link section; không viết nội dung ở đây.
- `sections/*.tex`: mọi người viết phần mình tại đây.
- `refs/references.bib`: Phúc thêm tài liệu tham khảo được trích dẫn.
