# Nhân vật 3D (V3): quy trình và prompt

Chủ dự án chốt ngày 03/11/2026: nhân vật thành **model 3D có xương (đi + đứng)**, tạo bằng **Tripo** từ ảnh Gemini
có sẵn, giữ đúng đặc điểm từng nhân vật. Không dựng nhân vật bằng code (quy tắc 29/10).

## Quy trình mỗi nhân vật
1. **Gemini — ảnh tư thế chữ A.** Tải lên `assets/characters/<id>_neutral.webp`, gửi prompt sửa bên dưới → lưu
   `docs/design/art-preview/v3/apose/<id>_apose.png`.
2. **Tripo — Image to 3D** từ ảnh chữ A (có texture) → **Auto Rig** (khung người) → gắn động tác `idle`, `walk`
   → xuất **GLB** (có xương + animation) → `docs/design/art-preview/v3/tripo/<id>.glb` (bản gốc, không đưa vào app).
3. **Tối ưu** (`gltf-transform`): giảm còn ~3–5k tam giác, texture 512–1024 px WebP/KTX2 →
   `assets/models/characters/<id>.glb`.
4. **Thermion**: `loadGltf`, phát `idle` khi đứng, `walk` khi đi; cao ~1,6 m người lớn.

Làm thử 3 nhân vật trước: `mai`, `linh`, `staff_nora`. Chủ dự án duyệt hình trong tiệm rồi mới làm hết 31.

## Prompt sửa ảnh (Gemini, gửi kèm ảnh neutral)
```
Redraw this exact same character as a clean character reference sheet for 3D modeling. Keep the face, hairstyle,
hair color, outfit, colors, patterns and accessories exactly the same. Front view, facing straight at the viewer,
standing upright in a relaxed A-pose: arms straight and held slightly away from the body at about 30 degrees, palms
facing the legs, empty hands (remove anything she is holding), legs straight and slightly apart, feet flat on the
ground. Neutral calm face with eyes open. Whole body from head to shoes visible with a small margin, centered.
Same soft hand-painted look, flat even lighting, no cast shadow. Plain solid pure white background, no floor, no
text, no watermark. Exactly one character. Portrait 3:4 image.
```
