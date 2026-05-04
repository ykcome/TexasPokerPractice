import SwiftUI

struct CircularImageCropper: View {
    let image: UIImage
    let onCrop: (UIImage?) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let maskSize = min(geometry.size.width, geometry.size.height) - 40
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Image with gestures
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.5, lastScale * value)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                
                // Dimmed overlay
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                            Circle()
                                .frame(width: maskSize, height: maskSize)
                                .blendMode(.destinationOut)
                        }
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // Circle border
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: maskSize, height: maskSize)
                    .allowsHitTesting(false)
                
                VStack {
                    Spacer()
                    HStack {
                        Button(String(localized: "取消")) {
                            onCancel()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        Button(String(localized: "选取")) {
                            cropImage(geometry: geometry, maskSize: maskSize)
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    @MainActor
    private func cropImage(geometry: GeometryProxy, maskSize: CGFloat) {
        let screenView = ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        
        let renderer = ImageRenderer(content: screenView)
        renderer.scale = 3.0
        
        if let fullImage = renderer.uiImage, let cgImage = fullImage.cgImage {
            let maskRect = CGRect(
                x: (geometry.size.width - maskSize) / 2 * renderer.scale,
                y: (geometry.size.height - maskSize) / 2 * renderer.scale,
                width: maskSize * renderer.scale,
                height: maskSize * renderer.scale
            )
            
            if let croppedCGImage = cgImage.cropping(to: maskRect) {
                let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: renderer.scale, orientation: .up)
                
                // Resize to 256x256
                let finalRenderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
                let finalImage = finalRenderer.image { _ in
                    let rect = CGRect(origin: .zero, size: CGSize(width: 256, height: 256))
                    UIBezierPath(ovalIn: rect).addClip()
                    croppedUIImage.draw(in: rect)
                }
                
                onCrop(finalImage)
                return
            }
        }
        onCrop(nil)
    }
}
