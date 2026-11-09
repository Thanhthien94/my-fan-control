# Install the macOS preview

**Apple Silicon (M1 or later), macOS 14 or later.** This preview is ad-hoc signed and is not Apple-notarized. Saved-preset control and return to automatic were measured on an M4 Pro; other models and sleep/wake recovery remain unverified. Monitoring starts without administrator access or changes to fan speed.

1. Download the `MyFanControl-<version>-arm64.dmg` file from the official [GitHub Releases](https://github.com/Thanhthien94/my-fan-control/releases).
2. Open the DMG and drag **MyFanControl.app** to the **Applications** shortcut.
3. Open My Fan Control from Applications. If macOS blocks it because the developer cannot be verified, open **System Settings → Privacy & Security**, find the message for this app and choose **Open Anyway**, then confirm **Open**. macOS may ask for authentication. Only do this for the app you downloaded from the official repository and whose checksum you verified.
4. Verify that fan RPM and temperature readings update. Fan controls remain inactive until you deliberately click **Apply** or **Enable controls…** and complete the separate administrator prompt.

Apple describes the blocked-app flow here: [Safely open apps on your Mac](https://support.apple.com/en-us/102445). On some versions the block appears only after the first open attempt. If macOS reports malware, damage or a failed signature check, stop and report the exact message instead of treating it as the ordinary unidentified-developer case.

The Open Anyway step is a per-app exception; no system-wide security setting needs to be disabled. A future Developer ID signed/notarized release is needed for the usual smoother downloaded-app experience.

## Verify the download

Download `SHA256SUMS.txt` from the same release and compare the DMG checksum:

```sh
shasum -a 256 ~/Downloads/MyFanControl-0.2.1-preview.1-arm64.dmg
```

The value must match the corresponding line in `SHA256SUMS.txt`. Checksums detect a mismatched/corrupted file; they do not replace Apple Developer ID verification. A ZIP with the same app is provided as an alternative to DMG installation.

## Remove or update

Before replacing/removing the app, choose **All automatic**, then quit normally. Drag a new version from its DMG into Applications, replacing the prior app only after quitting it. Presets and future schedule definitions are stored in local preferences; active manual fan ownership is not restored from disk.

## Build from source

Developers can use `./script/build_and_run.sh`; see README.md for toolchain requirements. That path is separate from validation of a downloaded public release.

## Hướng dẫn nhanh bằng tiếng Việt

1. Tải bản `arm64.dmg` tại Releases chính thức, kiểm tra SHA-256 nếu cần.
2. Mở DMG, kéo app vào biểu tượng Applications.
3. Mở app trong Applications. Nếu gặp cảnh báo nhà phát triển chưa được xác minh, vào System Settings → Privacy & Security → Open Anyway, rồi xác nhận Open cho đúng app này. Đây là bản preview chưa được Apple notarize.
4. Kiểm tra số đo quạt/nhiệt độ. Chỉ bấm “Bật điều khiển…” và cấp quyền quản trị khi bạn chủ động muốn thay đổi quạt.

Không cần tắt Gatekeeper hoặc SIP. Nếu thông báo nói app bị hỏng, chứa mã độc hoặc chữ ký không hợp lệ, hãy dừng và gửi báo lỗi thay vì xử lý như cảnh báo nhà phát triển thông thường.
