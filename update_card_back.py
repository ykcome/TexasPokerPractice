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

# 这个图片是我们之前用来做 SplashLogo 的原图 (带深色背景的 Logo)
input_path = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Resources/Assets.xcassets/SplashLogo.imageset/SplashLogo@3x.png'
# 新建一个目录存放专门为卡牌背面设计的 Logo
output_dir = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Resources/Assets.xcassets/CardBackLogo.imageset'
output_path = os.path.join(output_dir, 'CardBackLogo@3x.png')

def process_card_back_logo():
    if not os.path.exists(input_path):
        print(f"错误: 找不到文件 {input_path}")
        sys.exit(1)

    print("正在读取原 Splash Logo...")
    img = Image.open(input_path).convert("RGBA")
    
    # 卡牌背面的浅蓝色 RGB (约等于 R=0.4*255=102, G=0.6*255=153, B=0.9*255=229)
    target_bg_r, target_bg_g, target_bg_b = 102, 153, 229
    
    # 取原图左上角像素作为要被替换的 "深色背景" 参考
    ref_bg_color = img.getpixel((0, 0))
    ref_r, ref_g, ref_b = ref_bg_color[:3]
    
    print(f"原背景色: {ref_r},{ref_g},{ref_b} -> 目标背景色: {target_bg_r},{target_bg_g},{target_bg_b}")
    
    # 获取像素数据并替换颜色
    data = img.getdata()
    new_data = []
    
    # 容差范围
    tolerance = 40
    
    for item in data:
        # 如果像素接近原背景色 (深蓝色)，就把它替换为浅蓝色
        if abs(item[0] - ref_r) < tolerance and abs(item[1] - ref_g) < tolerance and abs(item[2] - ref_b) < tolerance:
            new_data.append((target_bg_r, target_bg_g, target_bg_b, item[3]))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    os.makedirs(output_dir, exist_ok=True)
    
    # 保存 3x 尺寸
    img.save(output_path, "PNG")
    print(f"✅ 成功生成 3x 尺寸卡牌背图: {output_path}")
    
    # 缩小并保存 2x (512) 和 1x (256)
    img_2x = img.resize((img.width * 2 // 3, img.height * 2 // 3), Image.Resampling.LANCZOS)
    img_2x.save(os.path.join(output_dir, 'CardBackLogo@2x.png'), "PNG")
    
    img_1x = img.resize((img.width // 3, img.height // 3), Image.Resampling.LANCZOS)
    img_1x.save(os.path.join(output_dir, 'CardBackLogo.png'), "PNG")
    
    # 写入 Contents.json
    import json
    json_path = os.path.join(output_dir, 'Contents.json')
    json_data = {
      "images": [
        {
          "filename": "CardBackLogo.png",
          "idiom": "universal",
          "scale": "1x"
        },
        {
          "filename": "CardBackLogo@2x.png",
          "idiom": "universal",
          "scale": "2x"
        },
        {
          "filename": "CardBackLogo@3x.png",
          "idiom": "universal",
          "scale": "3x"
        }
      ],
      "info": {
        "author": "xcode",
        "version": 1
      }
    }
    with open(json_path, 'w') as f:
        json.dump(json_data, f, indent=2)
    print("✅ JSON 配置生成完毕！")

if __name__ == "__main__":
    process_card_back_logo()
