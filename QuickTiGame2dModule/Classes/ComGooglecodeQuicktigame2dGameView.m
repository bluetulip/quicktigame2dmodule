// Copyright (c) 2012 quicktigame2d project
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name of the project nor the names of its contributors may be
//   used to endorse or promote products derived from this software without
//   specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 
#import "ComGooglecodeQuicktigame2dGameView.h"

@interface ComGooglecodeQuicktigame2dGameView (PrivateMethods)
- (void)startAnimation;
- (void)stopAnimation;
- (void)setAnimationFrameInterval:(NSInteger)frameInterval;
@end

@implementation ComGooglecodeQuicktigame2dGameView
@synthesize game;
@synthesize framebufferWidth, framebufferHeight;

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

-(CGRect)gamebounds {
    return CGRectMake(0, 0, game.width, game.height); 
}

- (void)attachContext {
    if (context) return;
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    
    eaglLayer.opaque = TRUE;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                    nil];
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    
    if (!context) {
        NSLog(@"Failed to create ES context");
    } else if (![EAGLContext setCurrentContext:context]) {
        NSLog(@"Failed to set ES context current");
    }
    
    displayLinkAnimating = FALSE;
    animationFrameInterval = 1;
    displayLink = nil;
    
    if (game == nil) game = [[QuickTiGame2dEngine alloc] init];
}

- (void)createFramebuffer {
    if (context && !defaultFramebuffer) {
        [EAGLContext setCurrentContext:context];
        
		// detect retina display
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && 
                        UIGraphicsBeginImageContextWithOptions != NULL) {
			self.contentScaleFactor  = RETINA_SCALE_FACTOR;
			self.layer.contentsScale = RETINA_SCALE_FACTOR;
		}
		
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        } else {
            [self startAnimation];
        }
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
        
        clearGLErrors(@"QuickTiGame2dGameView:createFramebuffer");
    }
}

- (void)startAnimation {
    if (!displayLinkAnimating) {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame)];
        [displayLink setFrameInterval:animationFrameInterval];
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        displayLinkAnimating = TRUE;
        
        [game onLoad:framebufferWidth height:framebufferHeight];
    }
}

- (void)stopAnimation {
    if (displayLinkAnimating) {
        [displayLink invalidate];
        displayLinkAnimating = FALSE;
    }
}

- (void)setAnimationFrameInterval:(NSInteger)frameInterval {
    if (frameInterval >= 1) {
        animationFrameInterval = frameInterval;
        
        if (displayLinkAnimating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}

- (void)drawFrame {
    if (!context || game == nil) return;
    
    [game drawFrame];
    
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)deleteFramebuffer {
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
    }
}

- (void)detachContext {
    if ([self debug]) NSLog(@"[DEBUG] GameView detachContext");
    [game onDispose];
    
    [self stopAnimation];
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    [self deleteFramebuffer];    
    RELEASE_TO_NIL(context);
    RELEASE_TO_NIL(game);
}

- (void)layoutSubviews {
    [EAGLContext setCurrentContext:context];
    [self deleteFramebuffer];
    [self createFramebuffer];
}

- (void)dealloc {
    if ([self debug]) NSLog(@"[DEBUG] GameView dealloc");
    [self deleteFramebuffer];    
    RELEASE_TO_NIL(context);
    RELEASE_TO_NIL(game);
    [super dealloc];
}

- (QuickTiGame2dScene*)pushScene:(QuickTiGame2dScene*)scene {
    return [game pushScene:scene];
}

- (QuickTiGame2dScene*)popScene {
    return [game popScene];
}

- (QuickTiGame2dScene*)replaceScene:(QuickTiGame2dScene*)scene {
    return [game replaceScene:scene];
}

- (void)start {
    [game start];
}

- (void)stop {
    [game stop];
}

- (void)pause {
    [game pause];
}

- (NSInteger)gameviewportWidth {
    return game.viewportWidth;
}

- (void)setGameviewportWidth:(NSInteger)value {
    game.viewportWidth = value;
}

- (NSInteger)gameviewportHeight {
    return game.viewportHeight;
}

- (void)setGameviewportHeight:(NSInteger)value {
    game.viewportHeight = value;
}

- (NSInteger)gamewidth {
    return [game width];
}

- (void)setGamewidth:(NSInteger)width {
    [game setWidth:width];
}

- (NSInteger)gameheight {
    return [game height];
}

- (void)setGameheight:(NSInteger)height {
    [game setHeight:height];
}

- (float)fps {
    return 60.0 / animationFrameInterval;
}

- (void)setFps:(float)fps {
    float interval = 60.0 / fps;
    if (interval < 1) interval = 1;
    
    [self setAnimationFrameInterval:interval];
}

- (BOOL)debug {
    return [QuickTiGame2dEngine debug];
}

- (void)setDebug:(BOOL)enable {
    [QuickTiGame2dEngine setDebug:enable];
}

-(void)alpha:(float)alpha {
    [game alpha:alpha];
}

-(void)color:(float)red green:(float)green blue:(float)blue {
    [game color:red green:green blue:blue];
}

-(void)color:(float)red green:(float)green blue:(float)blue alpha:(float)alpha {
    [game color:red green:green blue:blue alpha:alpha];
}

-(CameraInfo)getCamera {
    return [game getCamera];
}

-(void)setCamera:(CameraInfo)camera {
    [game setCamera:camera];
}

-(void)resetCamera {
    [game resetCamera];
}

-(void)moveCamera:(QuickTiGame2dTransform*) transform {
    [game transformCamera:transform];
}

- (BOOL)enableOnDrawFrameEvent {
    return game.enableOnDrawFrameEvent;
}

- (void)setEnableOnDrawFrameEvent:(BOOL)enable {
    game.enableOnDrawFrameEvent = enable;
}

- (BOOL)enableOnFpsEvent {
    return game.enableOnFpsEvent;
}

- (void)setEnableOnFpsEvent:(BOOL)enable {
    game.enableOnFpsEvent = enable;
}

- (NSInteger)onFpsInterval {
    return game.onFpsInterval;
}

- (void)setOnFpsInterval:(NSInteger)onFpsInterval {
    game.onFpsInterval = onFpsInterval;
}

-(void)addHUD:(QuickTiGame2dSprite*)sprite { 
    [game addHUD:sprite];
}

-(void)removeHUD:(QuickTiGame2dSprite*)sprite {
    [game removeHUD:sprite];
}

-(GLint)textureFilter {
    return [QuickTiGame2dEngine textureFilter];
}

-(void)setTextureFilter:(GLint)filter {
    [QuickTiGame2dEngine setTextureFilter:filter];
}

-(GLenum)correctionHint {
    return [QuickTiGame2dEngine correctionHint];
}

-(void)setCorrectionHint:(GLenum)hint {
    [QuickTiGame2dEngine setCorrectionHint:hint];
}

static void freeToImageBuffer(void *info, const void *data, size_t size) {
    free((void*)data);
}

-(UIImage*)toImage {
    NSInteger dataLength = framebufferWidth * framebufferHeight * 4;
    GLubyte *buffer =  (GLubyte *) malloc(dataLength);
    GLubyte *buffer2 = (GLubyte *) malloc(dataLength);
    glReadPixels(0, 0, framebufferWidth, framebufferHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid *)buffer);
    for(int y = 0; y < framebufferHeight; y++) {
        memcpy(&buffer2[((framebufferHeight-1) - y) * framebufferWidth * 4],
               &buffer[y * 4 * framebufferWidth], sizeof(GLubyte) * framebufferWidth * 4);
    }
    free(buffer);
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, dataLength, freeToImageBuffer);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    
    CGImageRef imageRef = CGImageCreate(framebufferWidth, framebufferHeight,
                                        8, 32,
                                        4 * framebufferWidth, colorSpaceRef,
                                        kCGBitmapByteOrderDefault, provider,
                                        NULL, NO,
                                        kCGRenderingIntentDefault);
    UIImage *uiImage = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);
    
    return uiImage;
}

@end
