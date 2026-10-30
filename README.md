# BTL Xác suất thống kê — Internet Advertisements

Repository này hiện chỉ là **khung làm việc chung** cho nhóm 5 người. Chưa có dữ liệu được commit, kết quả phân tích, công thức đã chốt, hay nội dung report hoàn chỉnh.

## Chuẩn bị trước khi bắt đầu

Mỗi thành viên cần chuẩn bị các công cụ sau trên máy Windows của mình.

| Công cụ | Bắt buộc? | Dùng để làm gì | Kiểm tra sau khi cài |
|---|---|---|---|
| [R](https://cran.r-project.org/bin/windows/base/) | Có với Tường, Bách, Hiền, Tân; Phúc nên cài để kiểm tra lại | Chạy code phân tích `.R` | `Rscript --version` |
| [MiKTeX](https://miktex.org/howto/install-miktex) | Có với Phúc và Tân; các thành viên khác nên cài nếu muốn xem PDF local | Biên dịch report LaTeX | `pdflatex --version` |
| VS Code hoặc RStudio | Không bắt buộc | Soạn code/R và LaTeX thuận tiện hơn | Mở được folder repo |

### 1. Cài và kiểm tra R

1. Tải và cài bản R cho Windows từ [CRAN](https://cran.r-project.org/bin/windows/base/), rồi mở PowerShell mới.
2. Tại thư mục bất kỳ, chạy:

   ```powershell
   Rscript --version
   ```

3. Nếu PowerShell không nhận `Rscript`, đóng toàn bộ VS Code/Terminal rồi mở lại. Nếu vẫn không được, thêm thư mục `bin` của R vào `PATH` theo hướng dẫn cài đặt của máy.

> Trong PowerShell, dùng `Rscript`, không dùng `R`: `R` có thể là alias của PowerShell.

### 2. R packages

Hiện repository **chưa yêu cầu package R ngoài base R**, vì nhóm chưa chốt phương pháp. Khi một script cần package mới, người thêm package phải:

1. Ghi package vào `scripts/00_packages.R`.
2. Ghi phương pháp liên quan trong `METHODS_LOG.md` và báo Phúc.
3. Người khác chạy một lần:

   ```powershell
   Rscript .\scripts\00_packages.R
   ```

Không tự dùng package mới mà không cập nhật hai file trên; như vậy mọi máy sẽ cài cùng dependency.

### 3. Cài và kiểm tra LaTeX

1. Cài [MiKTeX](https://miktex.org/howto/install-miktex) và hoàn tất bước thiết lập ban đầu trong MiKTeX Console.
2. Trong MiKTeX Console, chạy update; nên bật chế độ cho phép cài package còn thiếu khi biên dịch.
3. Mở PowerShell mới, chạy:

   ```powershell
   pdflatex --version
   ```

4. Phúc chỉ biên dịch file chính `report/thesis.tex`; không tạo mỗi người một file report riêng.

Template dùng PDFLaTeX. Nếu MiKTeX hỏi cài thêm package khi compile, chấp nhận cài rồi chạy lệnh compile lại.

## Bắt đầu ở đâu

1. Đọc [phân công, đầu ra và điểm bàn giao](docs/WORKSPACE.md), sau đó xem [outline report](docs/REPORT_OUTLINE.md) trước khi viết.
2. Tường đặt dữ liệu gốc vào `data/raw/` và tạo dữ liệu đã xử lý tại `data/processed/`.
3. Phúc điền thông tin chung trong `report/settings.tex`; `report/thesis.tex` là file LaTeX chính. Mỗi người chỉ viết vào file section mình sở hữu.
4. Mỗi khi dùng phương pháp/chỉ số/công thức mới, cập nhật `METHODS_LOG.md` và báo Phúc để bổ sung kiến thức nền, citation và README nếu cần.

## Cấu trúc

```text
data/
  raw/                 # dữ liệu gốc — không sửa trực tiếp, không commit
  processed/           # dữ liệu sau tiền xử lý — không commit
scripts/
  00_packages.R        # danh sách package R chung; hiện chưa cần cài gì
  01_data_setup.R      # Tường: đọc, kiểm tra, làm sạch, xuất processed data
  02_eda_descriptive.R # Bách: thống kê mô tả và biểu đồ
  03_inference_model.R # Hiền: phương pháp suy diễn/phân loại chính
  04_evaluation.R      # Tân: chia tập, đánh giá, so sánh và tuning
  run_all.R            # chạy theo đúng thứ tự sau khi các script hoàn thiện
output/
  tables/              # bảng sinh từ code — không commit
  figures/             # hình sinh từ code — không commit
report/
  thesis.tex           # file LaTeX chính: render toàn bộ report
  preview.tex          # preview một section; đổi một dòng previewfile
  settings.tex         # Phúc điền thông tin bìa và package dùng chung
  content.tex          # link toàn bộ section theo rubric
  sections/            # mỗi mục report là một file riêng
  refs/references.bib  # Phúc quản lý tài liệu tham khảo
docs/
  WORKSPACE.md         # phân công và quy tắc bàn giao
  WORKFLOW.md          # quy trình chạy và ghép report
METHODS_LOG.md         # nhật ký phương pháp mới
```

## Chạy phân tích

Sau khi Tường, Bách, Hiền và Tân đã điền code vào script của mình, chạy từ thư mục gốc theo thứ tự:

```powershell
Rscript .\scripts\00_packages.R
Rscript .\scripts\01_data_setup.R
Rscript .\scripts\02_eda_descriptive.R
Rscript .\scripts\03_inference_model.R
Rscript .\scripts\04_evaluation.R
```

Hoặc chạy một lần bằng:

```powershell
Rscript .\scripts\run_all.R
```

Các script hiện là khung rỗng có ghi rõ input/output; vì vậy chưa sinh ra kết quả cho đến khi nhóm bổ sung code.

## Preview section và biên dịch report

Template dùng **PDFLaTeX**, không dùng XeLaTeX. Trước khi preview, lưu phần viết của mình vào đúng file trong `report/sections/`.

### Preview phần của mình

1. Mở `report/preview.tex`.
2. Đổi duy nhất dòng `\newcommand{\previewfile}{...}` sang file section muốn xem, ví dụ:

   ```tex
   \newcommand{\previewfile}{sections/04_descriptive}
   ```

3. Từ thư mục `report/`, chạy:

   ```powershell
   pdflatex -interaction=nonstopmode -halt-on-error preview.tex
   ```

PDF preview nằm ở `report/preview.pdf`. File này chỉ render section đã chọn, với đúng font, lề và package của template. Không sửa `content.tex` để preview.

### Render toàn bộ report

Từ thư mục `report/`, chạy:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
pdflatex -interaction=nonstopmode -halt-on-error thesis.tex
```

PDF cuối là `report/thesis.pdf`. Khi report đã có citation thực sự, Phúc chạy thêm `bibtex thesis` giữa hai lần PDFLaTeX. Xem [WORKFLOW.md](docs/WORKFLOW.md) để biết điều kiện bàn giao trước khi ghép PDF.
