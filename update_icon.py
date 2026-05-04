import os
import sys
import subprocess

def install_pillow():
    try:
        import PIL
    except ImportError:
        print("正在自动安装图像处理库 Pillow...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
        print("Pillow 安装完成！\n")

install_pillow()

from PIL import Image

input_path = '/Users/zhengliu/Downloads/IMG_3513.jpg'
output_path = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'

def process_icon():
    if not os.path.exists(input_path):
        print(f"错误: 找不到文件 {input_path}")
        sys.exit(1)

    print("正在读取原图...")
    img = Image.open(input_path).convert("RGBA")
    
    # 将内部图案缩小为 1024 的 2/3 (约 682 像素)
    target_inner_size = 682
    
    width, height = img.size
    if width > height:
        new_width = target_inner_size
        new_height = int(target_inner_size * height / width)
    else:
        new_height = target_inner_size
        new_width = int(target_inner_size * width / height)
        
    print(f"正在将原图按比例缩小至 {new_width}x{new_height}...")
    resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # 自动吸取原图左上角的边缘颜色作为底色，保证背景融合自然
    bg_color = img.getpixel((0, 0))
    
    print("正在生成 1024x1024 居中画布...")
    canvas = Image.new("RGB", (1024, 1024), bg_color[:3])
    
    paste_x = (1024 - new_width) // 2
    paste_y = (1024 - new_height) // 2
    
    # 居中粘贴
    canvas.paste(resized_img, (paste_x, paste_y), resized_img)
    
    # 确保目录存在
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    canvas.save(output_path, "PNG")
    print(f"✅ 成功！精致的 App Icon 已生成并替换：{output_path}")

if __name__ == "__main__":
    process_icon()
