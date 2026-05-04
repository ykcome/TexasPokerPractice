import os
import sys
import json
from PIL import Image

app_icon_path = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
splash_logo_dir = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Resources/Assets.xcassets/SplashLogo.imageset'
splash_bg_dir = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Resources/Assets.xcassets/SplashBackground.colorset'

def process_splash():
    if not os.path.exists(app_icon_path):
        print(f"错误: 找不到 App Icon 文件 {app_icon_path}")
        sys.exit(1)

    print("正在读取新生成的 App Icon...")
    img = Image.open(app_icon_path).convert("RGB")
    
    # 获取背景色
    bg_color = img.getpixel((0, 0))
    r, g, b = bg_color
    print(f"提取背景色: R={r}, G={g}, B={b}")
    
    # 更新 SplashBackground.colorset
    bg_json_path = os.path.join(splash_bg_dir, 'Contents.json')
    if os.path.exists(bg_json_path):
        with open(bg_json_path, 'r') as f:
            bg_data = json.load(f)
        
        # 假设标准的 colors 结构
        if 'colors' in bg_data and len(bg_data['colors']) > 0:
            color_components = bg_data['colors'][0]['color']['components']
            color_components['red'] = f"{r/255.0:.3f}"
            color_components['green'] = f"{g/255.0:.3f}"
            color_components['blue'] = f"{b/255.0:.3f}"
            color_components['alpha'] = "1.000"
            
            with open(bg_json_path, 'w') as f:
                json.dump(bg_data, f, indent=2)
            print("✅ 成功更新过场动画背景色")
    else:
        print(f"⚠️ 找不到 {bg_json_path}")

    # 生成 1x, 2x, 3x 启动 Logo
    # 这里我们不用把整个 1024x1024 的背景也算进 logo（否则在屏幕上会显得 logo 很小，或者撑满屏幕）
    # 苹果推荐 splash logo 差不多是 200~300 points。
    # 既然整个 App Icon 包含边距，我们为了让 logo 在屏幕中间好看，可以把整个 AppIcon 缩放到 256x256 作为 1x
    # 因为系统会按照 256x256 点(points)渲染，加上一样的背景色，非常完美居中。
    
    sizes = {
        'SplashLogo.png': 256,
        'SplashLogo@2x.png': 512,
        'SplashLogo@3x.png': 768
    }
    
    os.makedirs(splash_logo_dir, exist_ok=True)
    
    for filename, size in sizes.items():
        out_path = os.path.join(splash_logo_dir, filename)
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"✅ 生成 {filename} ({size}x{size})")
        
    # 更新 SplashLogo.imageset/Contents.json
    logo_json_path = os.path.join(splash_logo_dir, 'Contents.json')
    logo_data = {
      "images": [
        {
          "filename": "SplashLogo.png",
          "idiom": "universal",
          "scale": "1x"
        },
        {
          "filename": "SplashLogo@2x.png",
          "idiom": "universal",
          "scale": "2x"
        },
        {
          "filename": "SplashLogo@3x.png",
          "idiom": "universal",
          "scale": "3x"
        }
      ],
      "info": {
        "author": "xcode",
        "version": 1
      }
    }
    with open(logo_json_path, 'w') as f:
        json.dump(logo_data, f, indent=2)
    print("✅ 成功更新 SplashLogo 的配置 JSON")

if __name__ == "__main__":
    process_splash()
