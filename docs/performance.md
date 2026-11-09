# Hiệu năng đo thực tế / Measured performance

Đo ngày 09/11/2026 trên **Mac16,7 · Apple M4 Pro · 14 CPU logic · RAM 24 GiB**, macOS 27.2 (26B123), cắm nguồn AC. App chạy bản tối ưu `0.3.1-preview.1`, build 47, mã nguồn `ba6765d84cc8be2e367ff2ae4a151bf2182ddecd`.

Mỗi lượt có 10 giây warm-up rồi **90 giây đo**, lấy mẫu mỗi giây. Đọc SMC với mục tiêu 1 giây/lần; hiển thị lịch sử 10 phút; 258–294 kênh nhiệt đọc được trong phiên. Hai lượt dashboard dùng cùng process đã warm và đủ dữ liệu cho khung lịch sử. Lượt lặp được mở lại bằng lệnh native New Window. Helper không chạy, quạt ở Auto; không thay đổi quạt để benchmark.

**CPU 100% = sử dụng trọn một CPU logic**, như cách đọc phần trăm theo lõi trong Activity Monitor; đây không phải phần trăm của toàn bộ CPU 14 lõi. Bộ nhớ tính bằng MiB (1024² byte).

| Tình huống | CPU trung bình | CPU p95 mẫu 1 giây | phys_footprint trung vị / cao nhất (MiB) | RSS trung vị (MiB) |
| --- | ---: | ---: | ---: | ---: |
| Dashboard mở — lượt 1 | 13.95% | 15.12% | 208.5 / 221.9 | 101.2 |
| Chỉ menu bar | 12.32% | 14.79% | 82.7 / 83.0 | 71.8 |
| Dashboard mở — lượt lặp | 12.46% | 14.09% | 213.1 / 217.2 | 69.0 |

Dashboard dùng trung bình **12,46–13,95% của một CPU logic** trong hai lượt; `phys_footprint` trung vị **208–213 MiB**. Đóng dashboard giảm footprint còn khoảng **82,7 MiB** trong lượt đo menu bar. App vẫn đọc SMC mỗi giây khi chỉ còn menu bar; đây không phải trạng thái ngừng theo dõi. Các con số thể hiện chi phí thực tế, không phải cam kết cho mọi máy.

## Hiểu đúng “mượt”

- App dùng SwiftUI, Swift Charts và cầu nối C/IOKit; không nhúng trình duyệt/Electron. Mục tiêu cập nhật dữ liệu là 1 giây. Quan sát accessibility của biểu đồ đã xác nhận các mẫu liên tiếp cách nhau khoảng 1 giây trong phiên thử.
- Các luồng chọn mode, cảm biến, menu và cập nhật giao diện đã được kiểm tra trực tiếp. **Chưa đo FPS, frame time, animation hitch hoặc input latency**, nên không dùng số CPU/RAM này để tuyên bố “60 FPS”, không giật, hoặc nhanh hơn một app khác.
- SMC là giao diện phụ thuộc phần cứng/firmware. Lệnh điều khiển, yêu cầu quyền hoặc I/O chậm có thể ảnh hưởng nhịp đọc; đây không phải cam kết realtime cứng.
- Máy có ứng dụng khác đang chạy. Load average 1 phút dao động khoảng 4,3–10,5 giữa các lượt; số kênh nhiệt thay đổi. Đây là đo sử dụng thực tế trên một máy, không phải thử nghiệm môi trường cô lập hay so sánh nhân quả giữa các cấu hình.
- `phys_footprint` là cách kernel tính lượng bộ nhớ chịu phí cho process; RSS là các trang đang resident và có thể gồm trang dùng chung. Hai đại lượng không cộng với nhau; cache/compression làm RSS thay đổi giữa các lượt.
- Chỉ đo process app: chưa bao gồm chi phí WindowServer/GPU/system daemon, helper khi điều khiển, năng lượng/battery life, cold start hoặc phiên soak dài. Không suy rộng sang các dòng Mac chưa kiểm thử.

## Cách đo và lặp lại

Dùng [script/benchmark_resources.py](../script/benchmark_resources.py), Python 3 có sẵn và `libproc` của macOS; không cần root, thư viện bên ngoài hoặc upload dữ liệu:

```sh
pgrep -x MyFanControl
python3 script/benchmark_resources.py --pid <PID> --scenario dashboard-open \
  --duration 90 --warmup 10 --output-dir docs/evidence/performance-local/dashboard
```

Mở dashboard, để khung lịch sử 10 phút và không thao tác trong lượt đo. Để đo menu bar, đóng cửa sổ bằng Cmd-W, giữ app chạy, rồi dùng thư mục đầu ra mới. Mở lại dashboard qua menu bar hoặc Cmd-N để đo lặp. Không chạy build/test/profiler trong thời gian lấy mẫu. Bộ đo từ chối ghi đè thư mục đã có và dừng nếu process bị thay/restart.

CPU lấy từ chênh lệch user/system CPU counters chia cho thời gian monotonic thực tế. **Phải quy đổi Mach absolute ticks bằng `mach_timebase_info`**; trên máy này tỷ lệ là 125/3 ns mỗi tick. Đã đối chiếu CPU tích lũy với `ps -o time` (xấp xỉ 93,79 giây tại điểm kiểm tra). Không dùng trực tiếp ticks như nanosecond hoặc dựa vào phần trăm smoothed của `ps`.

p95 là phân vị của 90 mẫu CPU theo khoảng 1 giây, không phải phân vị frame latency hay giới hạn cực đại. CSV/raw measurements và profile cục bộ ở thư mục evidence bị ignore. [JSON tổng hợp](performance-0.3.1-summary.json) không chứa PID, đường dẫn người dùng, tên tài khoản, serial, preset hay số đo nhiệt.

## English summary

On this AC-powered M4 Pro (14 logical CPUs, 24 GiB RAM), optimized 1 Hz monitoring used **12.46–13.95% of one logical CPU** with the dashboard open across two 90-second runs; median kernel footprint was **208–213 MiB**. A menu-bar-only run measured **12.32% CPU** and **82.7 MiB median footprint**. See the table/JSON for per-second CPU p95 and RSS. Other desktop applications remained running. These are process resource measurements, not FPS, battery, startup, cross-device or competitor benchmarks.

The release is rebuilt after documentation/CI changes; application `Sources/` code is unchanged from the measured revision. Native fake-hardware tests also run on the hosted Intel CI runner, while the distributable is cross-built and signature/architecture-checked as arm64. Local functional tests run on M4 Pro. This CI arrangement does not claim physical hardware validation on Intel.
