# Quyền riêng tư

My Fan Control không có tài khoản, quảng cáo, analytics, tự tải báo cáo lỗi, đồng bộ đám mây hay dịch vụ tự cập nhật nền. App không gửi số đo quạt, nhiệt độ, preset, lịch hoặc thông tin phần cứng lên máy chủ.

Chỉ khi bạn bấm Kiểm tra cập nhật, app gửi yêu cầu HTTPS chỉ đọc đến API Releases công khai của GitHub. GitHub nhận thông tin kết nối thông thường như địa chỉ IP và user agent MyFanControl. Không gửi tài khoản, token, model máy hoặc cấu hình. App không tự tải, thay thế hoặc cài phiên bản mới.

App đọc AppleSMC và tên chip để ánh xạ cảm biến cộng đồng, đồng thời kiểm tra danh sách app chạy trên máy để tránh ghi quạt đồng thời với Macs Fan Control. Những dữ liệu này chỉ dùng trên máy.

Preset, lịch, ngôn ngữ, đơn vị nhiệt độ và tùy chọn menu bar được lưu trong preferences cục bộ của macOS. Lịch sử nhiệt độ, hoạt động lịch gần đây và quyền sở hữu quạt của phiên chỉ ở trong bộ nhớ. Thoát app sẽ yêu cầu trả quạt về tự động. App không tự áp dụng lại điều khiển thủ công sau khi mở lại.

Helper quản trị chỉ chạy cục bộ theo yêu cầu và giao tiếp qua Unix socket giới hạn theo tài khoản người dùng. macOS xử lý hộp thoại xác thực. App không đọc hoặc lưu mật khẩu của bạn.

Tệp sao lưu có tên và cấu hình preset/lịch. Tệp được lưu tại nơi bạn chọn; không tự tải đi. Lịch nhập từ sao lưu được tắt và không tự điều khiển quạt. Báo cáo chẩn đoán có phiên bản app/macOS, chip/model và khả năng SMC chỉ đọc; không có serial, tên tài khoản, preset hay lịch. Bạn nên kiểm tra tệp trước khi tự chia sẻ.

Tùy chọn mở app khi đăng nhập chỉ đăng ký với macOS sau khi bạn bật. Khi đăng nhập, app chỉ theo dõi, không tự áp dụng preset hoặc yêu cầu quyền quản trị.

Mở liên kết trợ giúp, bản phát hành, báo lỗi hoặc nguồn cảm biến sẽ mở GitHub trong trình duyệt của bạn; GitHub và trình duyệt áp dụng chính sách riêng. App không tự gửi issue hoặc đính kèm tệp.

Công cụ tạo hình ảnh dùng trong quá trình phát triển không được tích hợp vào app. App không có API tạo ảnh hoặc khóa của nhà cung cấp.
