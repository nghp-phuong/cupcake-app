{{flutter_js}}
{{flutter_build_config}}

// CanvasKit lấy từ build/web/canvaskit/ (đã có sẵn trong bản build) thay vì CDN gstatic: bản xem trước chạy được
// khi không có mạng. Font của app đóng gói trong assets/fonts/ (xem pubspec).
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
